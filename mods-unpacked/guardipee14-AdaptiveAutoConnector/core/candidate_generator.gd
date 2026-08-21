extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Candidates]"
const EPSILON := 0.000001
const MAX_TARGETS_TO_LOG := 8
const MAX_CANDIDATES_PER_TARGET_TO_LOG := 3

var _metadata: Dictionary = {}
var _candidates_by_target: Dictionary = {}
var _sample_index := 0
var _last_candidate_signature := ""


func consume_detailed_snapshot(snapshot: Dictionary) -> void:
    _metadata.clear()

    for raw_window in snapshot.get("windows", []):
        if not raw_window is Dictionary:
            continue

        var window: Dictionary = raw_window
        var window_name := str(window.get("name", ""))
        var domain_hint := str(window.get("domain_hint", "system_or_unknown"))

        for raw_container in window.get("containers", []):
            if not raw_container is Dictionary:
                continue

            var container: Dictionary = raw_container
            var container_id := str(container.get("id", ""))
            if container_id.is_empty():
                continue

            var discovery: Dictionary = container.get("discovery", {})
            _metadata[container_id] = {
                "id": container_id,
                "window_name": window_name,
                "name": str(container.get("name", "")),
                "domain_hint": domain_hint,
                "resource": str(discovery.get("resource", "")),
                "has_input_connector": bool(container.get("has_input_connector", false)),
                "has_output_connector": bool(container.get("has_output_connector", false)),
                "connector_color": str(container.get("connector_color", ""))
            }


func consume_lightweight_state(state: Dictionary) -> void:
    var state_containers: Dictionary = state.get("containers", {})

    for existing_id in _metadata.keys():
        if not state_containers.has(existing_id):
            _metadata.erase(existing_id)

    for raw_id in state_containers.keys():
        var container_id := str(raw_id)
        var state_record: Dictionary = state_containers[raw_id]

        if _metadata.has(container_id):
            var existing: Dictionary = _metadata[container_id]
            existing["window_name"] = str(state_record.get("window_name", existing.get("window_name", "")))
            existing["name"] = str(state_record.get("name", existing.get("name", "")))
            continue

        _metadata[container_id] = _metadata_from_live_state(state_record)


func consume_resource_sample(sample: Dictionary) -> void:
    _sample_index += 1

    var samples: Dictionary = sample.get("containers", {})
    var targets: Array[Dictionary] = []

    for raw_id in samples.keys():
        var container_id := str(raw_id)
        if not _metadata.has(container_id):
            continue

        var sample_record: Dictionary = samples[raw_id]
        var metadata: Dictionary = _metadata[container_id]
        var resource := str(sample_record.get("resource", metadata.get("resource", "")))
        metadata["resource"] = resource

        if resource.is_empty():
            continue

        if not bool(metadata.get("has_input_connector", false)):
            continue

        if str(metadata.get("connector_color", "")).to_lower() == "black":
            continue

        if not str(sample_record.get("input", "")).is_empty():
            continue

        var required = sample_record.get("required", null)
        if not _is_positive(required):
            continue

        targets.append({
            "id": container_id,
            "window_name": str(sample_record.get("window_name", metadata.get("window_name", ""))),
            "name": str(sample_record.get("name", metadata.get("name", ""))),
            "resource": resource,
            "required": float(required)
        })

    targets.sort_custom(_sort_targets)

    var next_candidates: Dictionary = {}
    var targets_with_candidates := 0
    var total_candidates := 0
    var rejected_same_resource := 0
    var rejected_unverified := 0

    for target in targets:
        var target_id := str(target.get("id", ""))
        var target_resource := str(target.get("resource", ""))
        var candidates: Array[Dictionary] = []

        for raw_source_id in samples.keys():
            var source_id := str(raw_source_id)
            if source_id == target_id or not _metadata.has(source_id):
                continue

            var source_sample: Dictionary = samples[raw_source_id]
            var source_metadata: Dictionary = _metadata[source_id]
            var source_resource := str(source_sample.get("resource", source_metadata.get("resource", "")))
            source_metadata["resource"] = source_resource

            if source_resource != target_resource:
                continue

            if not _passes_structural_filters(source_id, source_sample, source_metadata, target_id):
                rejected_same_resource += 1
                continue

            if not _verify_live_compatibility(source_id, target_id):
                rejected_unverified += 1
                continue

            candidates.append(_candidate_record(source_id, source_sample, source_metadata, target))

        candidates.sort_custom(_sort_candidates)
        next_candidates[target_id] = candidates
        total_candidates += candidates.size()
        if not candidates.is_empty():
            targets_with_candidates += 1

    _candidates_by_target = next_candidates
    _report_candidates(targets, targets_with_candidates, total_candidates, rejected_same_resource, rejected_unverified)


func get_candidates() -> Dictionary:
    return _candidates_by_target.duplicate(true)


func _passes_structural_filters(
    source_id: String,
    source_sample: Dictionary,
    source_metadata: Dictionary,
    target_id: String
) -> bool:
    if not bool(source_metadata.get("has_output_connector", false)):
        return false

    if str(source_metadata.get("connector_color", "")).to_lower() == "black":
        return false

    var outputs := _string_array(source_sample.get("outputs", []))
    if outputs.has(target_id):
        return false

    if source_id.is_empty() or target_id.is_empty():
        return false

    return true


func _verify_live_compatibility(source_id: String, target_id: String) -> bool:
    if not is_instance_valid(Globals.desktop):
        return false

    if not Globals.desktop.has_method("get_resource"):
        return false

    var source = Globals.desktop.call("get_resource", source_id)
    var target = Globals.desktop.call("get_resource", target_id)

    if not is_instance_valid(source) or not is_instance_valid(target):
        return false

    if source.has_method("can_connect"):
        var source_result = source.call("can_connect", target)
        if source_result is bool and bool(source_result):
            return true

    if target.has_method("can_connect"):
        var target_result = target.call("can_connect", source)
        if target_result is bool and bool(target_result):
            return true

    return false


func _candidate_record(
    source_id: String,
    source_sample: Dictionary,
    source_metadata: Dictionary,
    target: Dictionary
) -> Dictionary:
    return {
        "source_id": source_id,
        "source_window": str(source_sample.get("window_name", source_metadata.get("window_name", ""))),
        "source_name": str(source_sample.get("name", source_metadata.get("name", ""))),
        "target_id": str(target.get("id", "")),
        "target_window": str(target.get("window_name", "")),
        "target_name": str(target.get("name", "")),
        "resource": str(target.get("resource", "")),
        "source_outputs": _string_array(source_sample.get("outputs", [])).size(),
        "source_production": source_sample.get("production", null),
        "target_required": target.get("required", null),
        "compatibility": "verified_can_connect"
    }


func _metadata_from_live_state(state_record: Dictionary) -> Dictionary:
    var node = state_record.get("node")
    var resource := ""
    var has_input := false
    var has_output := false
    var connector_color := ""

    if is_instance_valid(node):
        if "resource" in node:
            var raw_resource = node.get("resource")
            if raw_resource != null:
                resource = str(raw_resource)

        has_input = is_instance_valid(node.get_node_or_null("InputConnector"))
        has_output = is_instance_valid(node.get_node_or_null("OutputConnector"))

        if node.has_method("get_connector_color"):
            connector_color = str(node.call("get_connector_color"))

    return {
        "id": str(state_record.get("id", "")),
        "window_name": str(state_record.get("window_name", "")),
        "name": str(state_record.get("name", "")),
        "domain_hint": "system_or_unknown",
        "resource": resource,
        "has_input_connector": has_input,
        "has_output_connector": has_output,
        "connector_color": connector_color
    }


func _report_candidates(
    targets: Array[Dictionary],
    targets_with_candidates: int,
    total_candidates: int,
    rejected_same_resource: int,
    rejected_unverified: int
) -> void:
    print("%s Sample index=%d unserved_targets=%d targets_with_candidates=%d verified_candidates=%d rejected_structural=%d rejected_unverified=%d" % [
        LOG_PREFIX,
        _sample_index,
        targets.size(),
        targets_with_candidates,
        total_candidates,
        rejected_same_resource,
        rejected_unverified
    ])

    var signature_parts: Array[String] = []
    for target in targets:
        var target_id := str(target.get("id", ""))
        var candidates: Array = _candidates_by_target.get(target_id, [])
        var source_ids: Array[String] = []
        for raw_candidate in candidates:
            if raw_candidate is Dictionary:
                source_ids.append(str(raw_candidate.get("source_id", "")))
        source_ids.sort()
        signature_parts.append("%s:%s" % [target_id, ",".join(source_ids)])
    signature_parts.sort()
    var signature := "|".join(signature_parts)

    if _sample_index > 1 and signature == _last_candidate_signature:
        return

    _last_candidate_signature = signature

    var logged_targets := 0
    for target in targets:
        if logged_targets >= MAX_TARGETS_TO_LOG:
            break

        var target_id := str(target.get("id", ""))
        var candidates: Array = _candidates_by_target.get(target_id, [])
        print("%s   Target window='%s' container='%s' id='%s' resource='%s' required=%s candidates=%d" % [
            LOG_PREFIX,
            target.get("window_name", ""),
            target.get("name", ""),
            target_id,
            target.get("resource", ""),
            str(target.get("required", null)),
            candidates.size()
        ])

        var logged_candidates := 0
        for raw_candidate in candidates:
            if logged_candidates >= MAX_CANDIDATES_PER_TARGET_TO_LOG:
                break
            if not raw_candidate is Dictionary:
                continue

            var candidate: Dictionary = raw_candidate
            print("%s     Candidate source_window='%s' source_container='%s' source_id='%s' resource='%s' outputs=%d production=%s compatibility='%s'" % [
                LOG_PREFIX,
                candidate.get("source_window", ""),
                candidate.get("source_name", ""),
                candidate.get("source_id", ""),
                candidate.get("resource", ""),
                int(candidate.get("source_outputs", 0)),
                str(candidate.get("source_production", null)),
                candidate.get("compatibility", "")
            ])
            logged_candidates += 1

        logged_targets += 1


func _is_number(value) -> bool:
    return value is int or value is float


func _is_positive(value) -> bool:
    return _is_number(value) and float(value) > EPSILON


func _string_array(value) -> Array[String]:
    var result: Array[String] = []
    if value is Array or value is PackedStringArray:
        for item in value:
            result.append(str(item))
    result.sort()
    return result


func _sort_targets(left: Dictionary, right: Dictionary) -> bool:
    var left_required := float(left.get("required", 0.0))
    var right_required := float(right.get("required", 0.0))
    if left_required == right_required:
        return str(left.get("id", "")) < str(right.get("id", ""))
    return left_required > right_required


func _sort_candidates(left: Dictionary, right: Dictionary) -> bool:
    var left_window := str(left.get("source_window", ""))
    var right_window := str(right.get("source_window", ""))
    if left_window == right_window:
        return str(left.get("source_id", "")) < str(right.get("source_id", ""))
    return left_window < right_window
