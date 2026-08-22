extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][ManagerValidation]"
const EPSILON := 0.000001
const ABS_TOLERANCE := 0.01
const REL_TOLERANCE := 0.02
const MAX_BOUND_WINDOWS_TO_LOG := 6
const MAX_PROJECTIONS_TO_LOG := 12

var _resource_sample_index := 0
var _last_manager_signature := ""
var _last_projection_signature := ""


func consume_resource_sample(sample: Dictionary) -> void:
    _resource_sample_index += 1

    var containers: Dictionary = sample.get("containers", {})
    var managers: Array[Dictionary] = []

    for raw_id in containers.keys():
        var container_id := str(raw_id)
        var sample_record = containers[raw_id]
        if not sample_record is Dictionary:
            continue

        var record: Dictionary = sample_record
        var kind := _manager_kind(
            str(record.get("window_name", "")),
            str(record.get("resource", ""))
        )
        if kind.is_empty():
            continue

        managers.append(_build_manager_record(kind, container_id, record))

    managers.sort_custom(_sort_manager_records)
    _report_manager_sample(managers)


func consume_scored_candidates(scored_by_target: Dictionary, sample_index: int) -> void:
    var projections: Array[Dictionary] = []
    var target_ids := scored_by_target.keys()
    target_ids.sort()

    for raw_target_id in target_ids:
        var raw_candidates = scored_by_target[raw_target_id]
        if not raw_candidates is Array:
            continue

        for raw_candidate in raw_candidates:
            if not raw_candidate is Dictionary:
                continue

            var candidate: Dictionary = raw_candidate
            var kind := _manager_kind(
                str(candidate.get("source_window", "")),
                str(candidate.get("resource", ""))
            )
            if kind.is_empty():
                continue

            projections.append(_build_candidate_projection(kind, candidate))

    projections.sort_custom(_sort_projection_records)
    _report_projection_sample(projections, sample_index)


func _build_manager_record(kind: String, source_id: String, sample_record: Dictionary) -> Dictionary:
    var result := {
        "kind": kind,
        "source_id": source_id,
        "source_window": str(sample_record.get("window_name", "")),
        "resource": str(sample_record.get("resource", "")),
        "count": null,
        "demand": null,
        "current_ratio": null,
        "bound_windows": 0,
        "binding_demand_sum": null,
        "mirror_demand_sum": null,
        "binding_match": "unavailable",
        "mirror_match": "unavailable",
        "bindings": []
    }

    var source = _live_resource(source_id)
    if not is_instance_valid(source):
        return result

    var count = _read_numeric_property(source, "count")
    var demand = _read_numeric_property(source, "demand")
    result["count"] = count
    result["demand"] = demand
    if _is_number(count) and _is_number(demand) and float(demand) > EPSILON:
        result["current_ratio"] = float(count) / float(demand)

    if not "window_binds" in source:
        return result

    var raw_binds = source.get("window_binds")
    if not raw_binds is Dictionary:
        return result

    var binds: Dictionary = raw_binds
    result["bound_windows"] = binds.size()

    var binding_sum := 0.0
    var mirror_sum := 0.0
    var binding_sum_available := true
    var mirror_sum_available := true
    var details: Array[Dictionary] = []

    for raw_binding in binds.values():
        if not is_instance_valid(raw_binding):
            binding_sum_available = false
            mirror_sum_available = false
            continue

        var binding: Object = raw_binding
        var window = binding.get("window") if "window" in binding else null
        var own_sources = binding.get("own_sources") if "own_sources" in binding else []
        var binding_demand = null
        if binding.has_method("get_demand"):
            var raw_demand = binding.call("get_demand")
            if _is_number(raw_demand):
                binding_demand = float(raw_demand)
                binding_sum += float(raw_demand)
            else:
                binding_sum_available = false
        else:
            binding_sum_available = false

        var mirror: Dictionary = _mirror_window_demand(window, own_sources)
        if bool(mirror.get("available", false)):
            mirror_sum += float(mirror.get("demand", 0.0))
        else:
            mirror_sum_available = false

        details.append({
            "window": str(window.name) if is_instance_valid(window) else "",
            "binding_demand": binding_demand,
            "mirror_demand": mirror.get("demand", null),
            "goal": mirror.get("goal", null),
            "min_input_ratio": mirror.get("min_input_ratio", null),
            "input_count": int(mirror.get("input_count", 0)),
            "own_source_count": _array_size(own_sources)
        })

    details.sort_custom(_sort_binding_records)
    result["bindings"] = details

    if binding_sum_available:
        result["binding_demand_sum"] = binding_sum
    if mirror_sum_available:
        result["mirror_demand_sum"] = mirror_sum

    if _is_number(demand) and binding_sum_available:
        result["binding_match"] = "match" if _approximately_equal(float(demand), binding_sum) else "mismatch"
    if _is_number(demand) and mirror_sum_available:
        result["mirror_match"] = "match" if _approximately_equal(float(demand), mirror_sum) else "mismatch"

    return result


func _build_candidate_projection(kind: String, candidate: Dictionary) -> Dictionary:
    var result := {
        "kind": kind,
        "source_id": str(candidate.get("source_id", "")),
        "source_window": str(candidate.get("source_window", "")),
        "target_id": str(candidate.get("target_id", "")),
        "target_window": str(candidate.get("target_window", "")),
        "target_name": str(candidate.get("target_name", "")),
        "resource": str(candidate.get("resource", "")),
        "current_count": null,
        "current_demand": null,
        "current_ratio": null,
        "projected_target_demand": null,
        "projected_total_demand": null,
        "projected_ratio": null,
        "already_bound_window": false,
        "target_goal": null,
        "target_min_input_ratio": null,
        "target_input_count": 0,
        "mode": "diagnostic_only_no_score_effect"
    }

    var source = _live_resource(str(result["source_id"]))
    var target = _live_resource(str(result["target_id"]))
    if not is_instance_valid(source) or not is_instance_valid(target):
        return result

    var count = _read_numeric_property(source, "count")
    var demand = _read_numeric_property(source, "demand")
    result["current_count"] = count
    result["current_demand"] = demand
    if _is_number(count) and _is_number(demand) and float(demand) > EPSILON:
        result["current_ratio"] = float(count) / float(demand)

    var target_window = _parent_window(target)
    if not is_instance_valid(target_window):
        return result

    var mirror: Dictionary = _mirror_window_demand(target_window, [target])
    result["target_goal"] = mirror.get("goal", null)
    result["target_min_input_ratio"] = mirror.get("min_input_ratio", null)
    result["target_input_count"] = int(mirror.get("input_count", 0))
    if not bool(mirror.get("available", false)):
        return result

    var target_demand := float(mirror.get("demand", 0.0))
    result["projected_target_demand"] = target_demand

    var already_bound := _manager_has_window(source, target_window)
    result["already_bound_window"] = already_bound

    if _is_number(demand):
        var incremental_demand := 0.0 if already_bound else target_demand
        var projected_total := float(demand) + incremental_demand
        result["projected_total_demand"] = projected_total
        if _is_number(count) and projected_total > EPSILON:
            result["projected_ratio"] = float(count) / projected_total

    return result


func _mirror_window_demand(window, own_sources_value) -> Dictionary:
    var result := {
        "available": false,
        "demand": null,
        "goal": null,
        "min_input_ratio": null,
        "input_count": 0
    }

    if not is_instance_valid(window):
        return result

    var own_sources: Array = []
    if own_sources_value is Array:
        own_sources = own_sources_value

    var goal := 0.0
    if "goal" in window:
        var raw_goal = window.get("goal")
        if _is_number(raw_goal):
            goal = float(raw_goal)
    result["goal"] = goal

    # Upstream SmartResourceContainer returns zero demand when it has no source
    # connector bound into this window.
    if own_sources.is_empty():
        result["available"] = true
        result["demand"] = 0.0
        result["min_input_ratio"] = 0.0
        return result

    if not "containers" in window:
        return result

    var raw_containers = window.get("containers")
    if not raw_containers is Array:
        return result

    var input_ratios: Array[float] = []
    for raw_container in raw_containers:
        if not is_instance_valid(raw_container):
            continue

        var container: Object = raw_container
        if not container.is_in_group("input"):
            continue
        if own_sources.has(container):
            continue

        var production = _read_numeric_property(container, "production")
        var required = _read_numeric_property(container, "required")
        if not _is_number(production) or not _is_number(required):
            return result

        var divisor := float(required)
        if is_zero_approx(divisor):
            divisor = 1.0
        input_ratios.append(float(production) / divisor)

    result["input_count"] = input_ratios.size()

    var min_ratio := 0.0
    if not input_ratios.is_empty():
        min_ratio = input_ratios[0]
        for ratio in input_ratios:
            min_ratio = minf(min_ratio, ratio)

    result["available"] = true
    result["min_input_ratio"] = min_ratio
    result["demand"] = min_ratio * goal
    return result


func _manager_has_window(source: Object, target_window: Object) -> bool:
    if not is_instance_valid(source) or not is_instance_valid(target_window):
        return false
    if not "window_binds" in source:
        return false

    var raw_binds = source.get("window_binds")
    if not raw_binds is Dictionary:
        return false

    var binds: Dictionary = raw_binds
    return binds.has(target_window)


func _parent_window(node: Object):
    if not is_instance_valid(node) or not node is Node:
        return null

    var current: Node = node
    var depth := 0
    while is_instance_valid(current) and depth < 16:
        if current.is_in_group("window"):
            return current
        current = current.get_parent()
        depth += 1
    return null


func _live_resource(container_id: String):
    if container_id.is_empty() or not is_instance_valid(Globals.desktop):
        return null
    if not Globals.desktop.has_method("get_resource"):
        return null
    return Globals.desktop.call("get_resource", container_id)


func _report_manager_sample(managers: Array[Dictionary]) -> void:
    var signature_parts: Array[String] = []
    for manager in managers:
        signature_parts.append("%s:%s:%s:%s:%s:%s" % [
            manager.get("source_id", ""),
            str(manager.get("count", null)),
            str(manager.get("demand", null)),
            str(manager.get("mirror_demand_sum", null)),
            manager.get("binding_match", "unavailable"),
            manager.get("mirror_match", "unavailable")
        ])
    var signature := "|".join(signature_parts)

    print("%s ManagerSample index=%d managers=%d changed=%s" % [
        LOG_PREFIX,
        _resource_sample_index,
        managers.size(),
        str(signature != _last_manager_signature)
    ])

    if signature == _last_manager_signature and _resource_sample_index > 1:
        return
    _last_manager_signature = signature

    for manager in managers:
        print("%s   Manager kind='%s' window='%s' source='%s' resource='%s' count=%s demand=%s current_ratio=%s bound_windows=%d binding_sum=%s mirror_sum=%s binding_match='%s' mirror_match='%s' scoring='disabled_pending_projected_validation'" % [
            LOG_PREFIX,
            manager.get("kind", ""),
            manager.get("source_window", ""),
            manager.get("source_id", ""),
            manager.get("resource", ""),
            str(manager.get("count", null)),
            str(manager.get("demand", null)),
            str(manager.get("current_ratio", null)),
            int(manager.get("bound_windows", 0)),
            str(manager.get("binding_demand_sum", null)),
            str(manager.get("mirror_demand_sum", null)),
            manager.get("binding_match", "unavailable"),
            manager.get("mirror_match", "unavailable")
        ])

        var logged := 0
        for raw_binding in manager.get("bindings", []):
            if logged >= MAX_BOUND_WINDOWS_TO_LOG:
                break
            if not raw_binding is Dictionary:
                continue

            var binding: Dictionary = raw_binding
            print("%s     Bound window='%s' binding_demand=%s mirror_demand=%s goal=%s min_production_required=%s other_inputs=%d own_sources=%d" % [
                LOG_PREFIX,
                binding.get("window", ""),
                str(binding.get("binding_demand", null)),
                str(binding.get("mirror_demand", null)),
                str(binding.get("goal", null)),
                str(binding.get("min_input_ratio", null)),
                int(binding.get("input_count", 0)),
                int(binding.get("own_source_count", 0))
            ])
            logged += 1


func _report_projection_sample(projections: Array[Dictionary], sample_index: int) -> void:
    var signature_parts: Array[String] = []
    for projection in projections:
        signature_parts.append("%s:%s:%s:%s:%s" % [
            projection.get("source_id", ""),
            projection.get("target_id", ""),
            str(projection.get("current_demand", null)),
            str(projection.get("projected_target_demand", null)),
            str(projection.get("projected_ratio", null))
        ])
    var signature := "|".join(signature_parts)

    print("%s ProjectionSample index=%d manager_candidates=%d changed=%s score_effect=0" % [
        LOG_PREFIX,
        sample_index,
        projections.size(),
        str(signature != _last_projection_signature)
    ])

    if signature == _last_projection_signature and sample_index > 1:
        return
    _last_projection_signature = signature

    var logged := 0
    for projection in projections:
        if logged >= MAX_PROJECTIONS_TO_LOG:
            break

        print("%s   Project kind='%s' source='%s/%s' target='%s/%s' resource='%s' count=%s current_demand=%s current_ratio=%s target_demand=%s projected_total=%s projected_ratio=%s target_goal=%s target_min_production_required=%s target_other_inputs=%d already_bound_window=%s scoring='diagnostic_only'" % [
            LOG_PREFIX,
            projection.get("kind", ""),
            projection.get("source_window", ""),
            projection.get("source_id", ""),
            projection.get("target_window", ""),
            projection.get("target_name", ""),
            projection.get("resource", ""),
            str(projection.get("current_count", null)),
            str(projection.get("current_demand", null)),
            str(projection.get("current_ratio", null)),
            str(projection.get("projected_target_demand", null)),
            str(projection.get("projected_total_demand", null)),
            str(projection.get("projected_ratio", null)),
            str(projection.get("target_goal", null)),
            str(projection.get("target_min_input_ratio", null)),
            int(projection.get("target_input_count", 0)),
            str(projection.get("already_bound_window", false))
        ])
        logged += 1


func _read_numeric_property(object: Object, property_name: String):
    if not is_instance_valid(object) or not property_name in object:
        return null

    var value = object.get(property_name)
    if value is int or value is float:
        return float(value)
    return null


func _manager_kind(window_name: String, resource: String) -> String:
    var window_value := window_name.to_lower()
    var resource_value := resource.to_lower()

    if window_value.begins_with("smart_thread_manager") and resource_value == "clock_speed":
        return "smart_thread_manager"
    if window_value.begins_with("smart_gpu_manager") and resource_value == "gpu_speed":
        return "smart_gpu_manager"
    return ""


func _approximately_equal(left: float, right: float) -> bool:
    var difference := absf(left - right)
    if difference <= ABS_TOLERANCE:
        return true
    var scale := maxf(absf(left), absf(right))
    if scale <= EPSILON:
        return true
    return difference / scale <= REL_TOLERANCE


func _array_size(value) -> int:
    if value is Array or value is PackedStringArray:
        return value.size()
    return 0


func _is_number(value) -> bool:
    return value is int or value is float


func _sort_manager_records(left: Dictionary, right: Dictionary) -> bool:
    var left_kind := str(left.get("kind", ""))
    var right_kind := str(right.get("kind", ""))
    if left_kind != right_kind:
        return left_kind < right_kind
    return str(left.get("source_id", "")) < str(right.get("source_id", ""))


func _sort_binding_records(left: Dictionary, right: Dictionary) -> bool:
    return str(left.get("window", "")) < str(right.get("window", ""))


func _sort_projection_records(left: Dictionary, right: Dictionary) -> bool:
    var left_target := "%s|%s|%s" % [
        left.get("target_window", ""),
        left.get("target_name", ""),
        left.get("source_id", "")
    ]
    var right_target := "%s|%s|%s" % [
        right.get("target_window", ""),
        right.get("target_name", ""),
        right.get("source_id", "")
    ]
    return left_target < right_target
