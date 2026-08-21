extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Resources]"
const EPSILON := 0.000001
const MAX_STRUCTURAL_TO_LOG := 12

const DATA_TYPE_RESOURCES := [
    "array_bigint",
    "array_string",
    "bigint",
    "bitflag",
    "bool",
    "char",
    "decimal",
    "float",
    "hashmap_decimal",
    "hashmap_vector",
    "int",
    "string",
    "vector"
]

const HACKING_RESOURCES := [
    "corporation_data",
    "dos_damage",
    "government_data",
    "hack_experience",
    "hack_power",
    "impersonation",
    "infected_computer",
    "infection_damage",
    "payload_damage",
    "vulnerability"
]

const FACTORY_RESOURCES := [
    "heat",
    "overclock",
    "pcb",
    "router",
    "work_speed"
]

var _containers: Dictionary = {}
var _sample_index := 0
var _last_structural_signature := ""


func consume_detailed_snapshot(snapshot: Dictionary) -> void:
    _containers.clear()

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
            var resource := str(discovery.get("resource", ""))
            _containers[container_id] = {
                "id": container_id,
                "window_name": window_name,
                "name": str(container.get("name", "")),
                "domain_hint": domain_hint,
                "resource": resource,
                "family": _classify_resource(resource),
                "has_input_connector": bool(container.get("has_input_connector", false)),
                "has_output_connector": bool(container.get("has_output_connector", false)),
                "input": str(container.get("input", "")),
                "outputs": _string_array(container.get("outputs", [])),
                "production": _numeric_or_null(discovery.get("production", null)),
                "required": _numeric_or_null(discovery.get("required", null)),
                "demand": _numeric_or_null(discovery.get("demand", null))
            }

    _report_catalog()


func consume_lightweight_state(state: Dictionary) -> void:
    var state_containers: Dictionary = state.get("containers", {})

    for existing_id in _containers.keys():
        if not state_containers.has(existing_id):
            _containers.erase(existing_id)

    for raw_id in state_containers.keys():
        var container_id := str(raw_id)
        var state_record: Dictionary = state_containers[raw_id]

        if _containers.has(container_id):
            var existing: Dictionary = _containers[container_id]
            existing["input"] = str(state_record.get("input", ""))
            existing["outputs"] = _string_array(state_record.get("outputs", []))
            existing["window_name"] = str(state_record.get("window_name", existing.get("window_name", "")))
            continue

        _containers[container_id] = _new_record_from_lightweight_state(state_record)


func consume_resource_sample(sample: Dictionary) -> void:
    _sample_index += 1

    for raw_id in sample.get("containers", {}).keys():
        var container_id := str(raw_id)
        var sample_record: Dictionary = sample["containers"][raw_id]

        if not _containers.has(container_id):
            _containers[container_id] = {
                "id": container_id,
                "window_name": str(sample_record.get("window_name", "")),
                "name": str(sample_record.get("name", "")),
                "domain_hint": "system_or_unknown",
                "resource": str(sample_record.get("resource", "")),
                "family": _classify_resource(str(sample_record.get("resource", ""))),
                "has_input_connector": false,
                "has_output_connector": false,
                "input": str(sample_record.get("input", "")),
                "outputs": _string_array(sample_record.get("outputs", [])),
                "production": null,
                "required": null,
                "demand": null
            }

        var existing: Dictionary = _containers[container_id]
        var sampled_resource := str(sample_record.get("resource", existing.get("resource", "")))
        existing["resource"] = sampled_resource
        existing["family"] = _classify_resource(sampled_resource)
        existing["window_name"] = str(sample_record.get("window_name", existing.get("window_name", "")))
        existing["name"] = str(sample_record.get("name", existing.get("name", "")))
        existing["input"] = str(sample_record.get("input", existing.get("input", "")))
        existing["outputs"] = _string_array(sample_record.get("outputs", existing.get("outputs", [])))
        existing["production"] = _numeric_or_null(sample_record.get("production", null))
        existing["required"] = _numeric_or_null(sample_record.get("required", null))
        existing["demand"] = _numeric_or_null(sample_record.get("demand", null))

    _analyze_sample("initial" if _sample_index == 1 else "runtime")


func get_resource_model() -> Dictionary:
    return _containers.duplicate(true)


func _new_record_from_lightweight_state(state_record: Dictionary) -> Dictionary:
    var node = state_record.get("node")
    var resource := ""
    var has_input := false
    var has_output := false

    if is_instance_valid(node):
        if "resource" in node:
            var raw_resource = node.get("resource")
            if raw_resource != null:
                resource = str(raw_resource)
        has_input = is_instance_valid(node.get_node_or_null("InputConnector"))
        has_output = is_instance_valid(node.get_node_or_null("OutputConnector"))

    return {
        "id": str(state_record.get("id", "")),
        "window_name": str(state_record.get("window_name", "")),
        "name": str(state_record.get("name", "")),
        "domain_hint": "system_or_unknown",
        "resource": resource,
        "family": _classify_resource(resource),
        "has_input_connector": has_input,
        "has_output_connector": has_output,
        "input": str(state_record.get("input", "")),
        "outputs": _string_array(state_record.get("outputs", [])),
        "production": null,
        "required": null,
        "demand": null
    }


func _report_catalog() -> void:
    var distinct_resources := {}
    var family_resources := {}
    var unknown_resources := {}

    for raw_container in _containers.values():
        if not raw_container is Dictionary:
            continue

        var container: Dictionary = raw_container
        var resource := str(container.get("resource", ""))
        if resource.is_empty():
            continue

        var family := str(container.get("family", "unknown"))
        distinct_resources[resource] = true

        if not family_resources.has(family):
            family_resources[family] = {}
        family_resources[family][resource] = true

        if family == "unknown":
            unknown_resources[resource] = true

    var family_parts: Array[String] = []
    var family_keys := family_resources.keys()
    family_keys.sort()
    for family_key in family_keys:
        family_parts.append("%s=%d" % [str(family_key), family_resources[family_key].size()])

    print("%s Catalog containers=%d distinct_resources=%d unknown_resources=%d families %s" % [
        LOG_PREFIX,
        _containers.size(),
        distinct_resources.size(),
        unknown_resources.size(),
        " ".join(family_parts)
    ])

    if not unknown_resources.is_empty():
        var unknown_names := unknown_resources.keys()
        unknown_names.sort()
        print("%s Unknown resources: %s" % [LOG_PREFIX, ",".join(unknown_names)])


func _analyze_sample(reason: String) -> void:
    var unserved_inputs: Array = []
    var idle_producers: Array = []
    var experimental_connected_gaps := 0
    var sampled_numeric := 0

    for raw_container in _containers.values():
        if not raw_container is Dictionary:
            continue

        var container: Dictionary = raw_container
        var resource := str(container.get("resource", ""))
        if resource.is_empty():
            continue

        var production = container.get("production", null)
        var required = container.get("required", null)

        if production is float or production is int or required is float or required is int:
            sampled_numeric += 1

        if bool(container.get("has_input_connector", false)) and str(container.get("input", "")).is_empty() and _is_positive(required):
            unserved_inputs.append(_structural_record("unserved_required_input", container))

        if bool(container.get("has_output_connector", false)) and _string_array(container.get("outputs", [])).is_empty() and _is_positive(production):
            idle_producers.append(_structural_record("idle_active_producer", container))

        # Do not treat this as a confirmed bottleneck yet. Runtime tests showed that
        # production/required semantics need more validation for connected inputs.
        if bool(container.get("has_input_connector", false)) and not str(container.get("input", "")).is_empty() and _is_positive(required) and _is_number(production) and float(production) + EPSILON < float(required):
            experimental_connected_gaps += 1

    unserved_inputs.sort_custom(_sort_structural_records)
    idle_producers.sort_custom(_sort_structural_records)

    print("%s Sample reason=%s index=%d containers=%d numeric=%d unserved_required_inputs=%d idle_active_producers=%d experimental_connected_gaps=%d" % [
        LOG_PREFIX,
        reason,
        _sample_index,
        _containers.size(),
        sampled_numeric,
        unserved_inputs.size(),
        idle_producers.size(),
        experimental_connected_gaps
    ])

    var structural: Array = []
    structural.append_array(unserved_inputs)
    structural.append_array(idle_producers)
    structural.sort_custom(_sort_structural_records)

    var signature_parts: Array[String] = []
    for raw_record in structural:
        if raw_record is Dictionary:
            signature_parts.append("%s:%s" % [raw_record.get("kind", ""), raw_record.get("id", "")])
    signature_parts.sort()
    var signature := "|".join(signature_parts)

    if reason != "initial" and signature == _last_structural_signature:
        return

    _last_structural_signature = signature
    var logged := 0
    for raw_record in structural:
        if logged >= MAX_STRUCTURAL_TO_LOG:
            break
        if not raw_record is Dictionary:
            continue

        var record: Dictionary = raw_record
        print("%s   Structural kind='%s' window='%s' container='%s' id='%s' resource='%s' family='%s' required=%s production=%s" % [
            LOG_PREFIX,
            record.get("kind", ""),
            record.get("window_name", ""),
            record.get("name", ""),
            record.get("id", ""),
            record.get("resource", ""),
            record.get("family", "unknown"),
            str(record.get("required", null)),
            str(record.get("production", null))
        ])
        logged += 1


func _structural_record(kind: String, container: Dictionary) -> Dictionary:
    return {
        "kind": kind,
        "id": str(container.get("id", "")),
        "window_name": str(container.get("window_name", "")),
        "name": str(container.get("name", "")),
        "resource": str(container.get("resource", "")),
        "family": str(container.get("family", "unknown")),
        "required": container.get("required", null),
        "production": container.get("production", null)
    }


func _classify_resource(resource: String) -> String:
    var value := resource.to_lower()
    if value.is_empty():
        return "unknown"

    if value in ["clock_speed", "cpu_core", "gpu", "gpu_speed"]:
        return "compute"

    if value in ["download_speed", "upload_speed"]:
        return "network"

    if value in FACTORY_RESOURCES:
        return "factory"

    if value.begins_with("code_") or value == "contribution":
        return "coding"

    if value in HACKING_RESOURCES:
        return "hacking"

    if value.begins_with("neuron_") or value in ["quantum_solver", "quantum_solver_gpu", "qubit"]:
        return "ai"

    if value in DATA_TYPE_RESOURCES:
        return "data_type"

    if value in ["money", "ethereum", "litecoin"]:
        return "economy"

    if value in ["research", "research_power"]:
        return "progression"

    if value in ["game", "image", "program", "sound", "text", "video"] or value.begins_with("torrent_") or value.begins_with("zip_"):
        return "media"

    return "unknown"


func _numeric_or_null(value):
    if value is int or value is float:
        return float(value)
    return null


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


func _sort_structural_records(left: Dictionary, right: Dictionary) -> bool:
    var left_required := float(left.get("required", 0.0)) if _is_number(left.get("required", null)) else 0.0
    var right_required := float(right.get("required", 0.0)) if _is_number(right.get("required", null)) else 0.0
    if left_required == right_required:
        return str(left.get("id", "")) < str(right.get("id", ""))
    return left_required > right_required
