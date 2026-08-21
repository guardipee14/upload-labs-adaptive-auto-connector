extends Node

signal detailed_snapshot_ready(snapshot: Dictionary)
signal lightweight_state_changed(state: Dictionary)
signal resource_state_sampled(sample: Dictionary)

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Topology]"
const SCAN_INTERVAL_SECONDS := 5.0
const READY_RETRY_SECONDS := 0.5
const MAX_READY_ATTEMPTS := 60
const RESOURCE_SAMPLE_EVERY_SCANS := 2

const WINDOW_DISCOVERY_PROPERTIES := [
    "id",
    "key",
    "type",
    "window_type",
    "category",
    "sub_category",
    "action"
]

const CONTAINER_DISCOVERY_PROPERTIES := [
    "resource",
    "resource_type",
    "type",
    "production",
    "required",
    "demand",
    "ratio",
    "goal"
]

var _scan_timer: Timer = null
var _last_topology_state: Dictionary = {}
var _scan_count := 0


func start_observing() -> void:
    print("%s Waiting for desktop topology..." % LOG_PREFIX)
    _wait_for_desktop()


func _wait_for_desktop() -> void:
    var attempt := 0

    while attempt < MAX_READY_ATTEMPTS:
        if is_instance_valid(Globals.desktop):
            var windows_node := Globals.desktop.get_node_or_null("Windows")
            if is_instance_valid(windows_node):
                _begin_observing(windows_node)
                return

        attempt += 1
        await get_tree().create_timer(READY_RETRY_SECONDS).timeout

    push_warning("%s Desktop/Windows was not ready after %d attempts; observer remains inactive." % [LOG_PREFIX, MAX_READY_ATTEMPTS])


func _begin_observing(windows_node: Node) -> void:
    # One detailed snapshot is useful for reverse-engineering the live data model.
    # Periodic polling below intentionally does NOT rebuild this expensive structure.
    var snapshot := _build_detailed_snapshot(windows_node)
    _report_snapshot("initial", snapshot)
    detailed_snapshot_ready.emit(snapshot)

    _last_topology_state = _build_lightweight_state(windows_node)
    resource_state_sampled.emit(_build_resource_sample(_last_topology_state))

    _scan_timer = Timer.new()
    _scan_timer.name = "TopologyScanTimer"
    _scan_timer.wait_time = SCAN_INTERVAL_SECONDS
    _scan_timer.one_shot = false
    _scan_timer.autostart = true
    _scan_timer.timeout.connect(_on_scan_timer_timeout)
    add_child(_scan_timer)

    print("%s Observer active; lightweight read-only scan interval %.1fs." % [LOG_PREFIX, SCAN_INTERVAL_SECONDS])


func _on_scan_timer_timeout() -> void:
    if not is_instance_valid(Globals.desktop):
        return

    var windows_node := Globals.desktop.get_node_or_null("Windows")
    if not is_instance_valid(windows_node):
        return

    var current_state := _build_lightweight_state(windows_node)
    var topology_changed := current_state.get("signature", "") != _last_topology_state.get("signature", "")

    if topology_changed:
        _report_delta(_last_topology_state, current_state)
        lightweight_state_changed.emit(current_state)
        _last_topology_state = current_state

    _scan_count += 1
    if _scan_count % RESOURCE_SAMPLE_EVERY_SCANS == 0:
        resource_state_sampled.emit(_build_resource_sample(current_state))


func _build_lightweight_state(windows_node: Node) -> Dictionary:
    var windows := {}
    var containers := {}
    var signature_parts: Array[String] = []
    var connection_count := 0

    for child in windows_node.get_children():
        if not is_instance_valid(child) or not child is WindowBase:
            continue

        var scene_path := _get_scene_path(child)
        var window_key := "%s|%s" % [str(child.name), scene_path]
        windows[window_key] = {
            "name": str(child.name),
            "scene": scene_path,
            "node": child
        }
        signature_parts.append("W:%s" % window_key)

        if not "containers" in child:
            continue

        var raw_containers = child.get("containers")
        if raw_containers == null:
            continue

        for container in raw_containers:
            if not is_instance_valid(container):
                continue

            var container_id := ""
            if "id" in container:
                container_id = str(container.get("id"))
            if container_id.is_empty():
                container_id = "instance:%d" % container.get_instance_id()

            var input_id := ""
            if "input_id" in container:
                var raw_input = container.get("input_id")
                if raw_input != null:
                    input_id = str(raw_input)

            var outputs: Array[String] = []
            if "outputs_id" in container:
                var raw_outputs = container.get("outputs_id")
                if raw_outputs is Array or raw_outputs is PackedStringArray:
                    for output_id in raw_outputs:
                        outputs.append(str(output_id))
            outputs.sort()
            connection_count += outputs.size()

            containers[container_id] = {
                "id": container_id,
                "name": str(container.name),
                "window_key": window_key,
                "window_name": str(child.name),
                "input": input_id,
                "outputs": outputs,
                "node": container
            }

            signature_parts.append("C:%s:%s:%s" % [
                container_id,
                input_id,
                ",".join(outputs)
            ])

    signature_parts.sort()

    return {
        "windows": windows,
        "containers": containers,
        "window_count": windows.size(),
        "container_count": containers.size(),
        "connection_count": connection_count,
        "signature": "\n".join(signature_parts)
    }


func _build_resource_sample(state: Dictionary) -> Dictionary:
    var samples := {}
    var sampled_count := 0

    for raw_id in state.get("containers", {}).keys():
        var state_record: Dictionary = state["containers"][raw_id]
        var node = state_record.get("node")
        if not is_instance_valid(node):
            continue

        var resource := ""
        if "resource" in node:
            var raw_resource = node.get("resource")
            if raw_resource != null:
                resource = str(raw_resource)

        var production = _read_numeric_property(node, "production")
        var required = _read_numeric_property(node, "required")
        var demand = _read_numeric_property(node, "demand")

        samples[str(raw_id)] = {
            "id": str(raw_id),
            "window_name": str(state_record.get("window_name", "")),
            "name": str(state_record.get("name", "")),
            "resource": resource,
            "input": str(state_record.get("input", "")),
            "outputs": state_record.get("outputs", []).duplicate(),
            "production": production,
            "required": required,
            "demand": demand
        }
        sampled_count += 1

    return {
        "containers": samples,
        "container_count": sampled_count
    }


func _read_numeric_property(object: Object, property_name: String):
    if not is_instance_valid(object) or not property_name in object:
        return null

    var value = object.get(property_name)
    if value is int or value is float:
        return float(value)

    return null


func _report_delta(previous: Dictionary, current: Dictionary) -> void:
    var old_windows: Dictionary = previous.get("windows", {})
    var new_windows: Dictionary = current.get("windows", {})
    var old_containers: Dictionary = previous.get("containers", {})
    var new_containers: Dictionary = current.get("containers", {})

    var added_windows: Array[String] = []
    var removed_windows: Array[String] = []
    var added_containers: Array[String] = []
    var removed_containers: Array[String] = []
    var rewired_containers: Array[String] = []

    for key in new_windows.keys():
        if not old_windows.has(key):
            added_windows.append(str(key))
    for key in old_windows.keys():
        if not new_windows.has(key):
            removed_windows.append(str(key))

    for key in new_containers.keys():
        if not old_containers.has(key):
            added_containers.append(str(key))
            continue

        var old_record: Dictionary = old_containers[key]
        var new_record: Dictionary = new_containers[key]
        if old_record.get("input", "") != new_record.get("input", "") or old_record.get("outputs", []) != new_record.get("outputs", []):
            rewired_containers.append(str(key))

    for key in old_containers.keys():
        if not new_containers.has(key):
            removed_containers.append(str(key))

    added_windows.sort()
    removed_windows.sort()
    added_containers.sort()
    removed_containers.sort()
    rewired_containers.sort()

    print("%s Delta windows=%d containers=%d connections=%d added_windows=%d removed_windows=%d added_containers=%d removed_containers=%d rewired=%d" % [
        LOG_PREFIX,
        int(current.get("window_count", 0)),
        int(current.get("container_count", 0)),
        int(current.get("connection_count", 0)),
        added_windows.size(),
        removed_windows.size(),
        added_containers.size(),
        removed_containers.size(),
        rewired_containers.size()
    ])

    for window_key in added_windows:
        var record: Dictionary = new_windows[window_key]
        print("%s   Added window name='%s' scene='%s'" % [LOG_PREFIX, record.get("name", ""), record.get("scene", "")])
        var node = record.get("node")
        if is_instance_valid(node):
            _report_window(_describe_window(node), "added")

    for window_key in removed_windows:
        var record: Dictionary = old_windows[window_key]
        print("%s   Removed window name='%s' scene='%s'" % [LOG_PREFIX, record.get("name", ""), record.get("scene", "")])

    for container_id in added_containers:
        var record: Dictionary = new_containers[container_id]
        if added_windows.has(str(record.get("window_key", ""))):
            continue
        var node = record.get("node")
        if is_instance_valid(node):
            _report_container(_describe_container(node), "added", str(record.get("window_name", "")))

    for container_id in removed_containers:
        var record: Dictionary = old_containers[container_id]
        print("%s   Removed container window='%s' name='%s' id='%s' input='%s' outputs=%s" % [
            LOG_PREFIX,
            record.get("window_name", ""),
            record.get("name", ""),
            container_id,
            record.get("input", ""),
            JSON.stringify(record.get("outputs", []))
        ])

    for container_id in rewired_containers:
        var old_record: Dictionary = old_containers[container_id]
        var new_record: Dictionary = new_containers[container_id]
        print("%s   Rewired window='%s' container='%s' id='%s' input '%s' -> '%s' outputs %s -> %s" % [
            LOG_PREFIX,
            new_record.get("window_name", ""),
            new_record.get("name", ""),
            container_id,
            old_record.get("input", ""),
            new_record.get("input", ""),
            JSON.stringify(old_record.get("outputs", [])),
            JSON.stringify(new_record.get("outputs", []))
        ])


func _build_detailed_snapshot(windows_node: Node) -> Dictionary:
    var window_records: Array = []
    var container_count := 0
    var connection_count := 0

    for child in windows_node.get_children():
        if not is_instance_valid(child) or not child is WindowBase:
            continue

        var window_record := _describe_window(child)
        var containers: Array = window_record.get("containers", [])
        container_count += containers.size()

        for container_record in containers:
            var outputs: Array = container_record.get("outputs", [])
            connection_count += outputs.size()

        window_records.append(window_record)

    window_records.sort_custom(_sort_records_by_key)

    return {
        "windows": window_records,
        "window_count": window_records.size(),
        "container_count": container_count,
        "connection_count": connection_count
    }


func _describe_window(window: Node) -> Dictionary:
    var scene_path := _get_scene_path(window)
    var script_path := _get_script_path(window)
    var discovery := _collect_discovery_properties(window, WINDOW_DISCOVERY_PROPERTIES)
    var containers: Array = []

    if "containers" in window:
        var raw_containers = window.get("containers")
        if raw_containers != null:
            for container in raw_containers:
                if is_instance_valid(container):
                    containers.append(_describe_container(container))

    containers.sort_custom(_sort_records_by_key)

    var sort_key := "%s|%s|%s" % [str(window.name), scene_path, script_path]

    return {
        "sort_key": sort_key,
        "name": str(window.name),
        "class": window.get_class(),
        "scene": scene_path,
        "script": script_path,
        "domain_hint": _infer_domain_hint(str(window.name), scene_path, script_path, discovery),
        "discovery": discovery,
        "containers": containers
    }


func _describe_container(container: Node) -> Dictionary:
    var container_id := _property_as_string(container, "id")
    var input_id := _property_as_string(container, "input_id")
    var outputs := _property_as_string_array(container, "outputs_id")
    outputs.sort()

    var input_connector := container.get_node_or_null("InputConnector")
    var output_connector := container.get_node_or_null("OutputConnector")

    var connector_color := ""
    if container.has_method("get_connector_color"):
        connector_color = str(container.call("get_connector_color"))

    var script_path := _get_script_path(container)
    var discovery := _collect_discovery_properties(container, CONTAINER_DISCOVERY_PROPERTIES)
    var sort_key := "%s|%s|%s" % [container_id, str(container.name), script_path]

    return {
        "sort_key": sort_key,
        "name": str(container.name),
        "id": container_id,
        "class": container.get_class(),
        "script": script_path,
        "has_input_connector": is_instance_valid(input_connector),
        "has_output_connector": is_instance_valid(output_connector),
        "connector_color": connector_color,
        "input": input_id,
        "outputs": outputs,
        "discovery": discovery
    }


func _report_snapshot(reason: String, snapshot: Dictionary) -> void:
    print("%s Snapshot reason=%s windows=%d containers=%d connections=%d" % [
        LOG_PREFIX,
        reason,
        int(snapshot.get("window_count", 0)),
        int(snapshot.get("container_count", 0)),
        int(snapshot.get("connection_count", 0))
    ])

    for window_record in snapshot.get("windows", []):
        _report_window(window_record, reason)


func _report_window(window_record: Dictionary, reason: String) -> void:
    print("%s Window reason='%s' name='%s' class='%s' domain_hint='%s' scene='%s' script='%s' discovery=%s" % [
        LOG_PREFIX,
        reason,
        window_record.get("name", ""),
        window_record.get("class", ""),
        window_record.get("domain_hint", "system_or_unknown"),
        window_record.get("scene", ""),
        window_record.get("script", ""),
        JSON.stringify(window_record.get("discovery", {}))
    ])

    for container_record in window_record.get("containers", []):
        _report_container(container_record, reason, str(window_record.get("name", "")))


func _report_container(container_record: Dictionary, reason: String, window_name: String) -> void:
    print("%s   Container reason='%s' window='%s' name='%s' id='%s' class='%s' in_connector=%s out_connector=%s color='%s' input='%s' outputs=%s script='%s' discovery=%s" % [
        LOG_PREFIX,
        reason,
        window_name,
        container_record.get("name", ""),
        container_record.get("id", ""),
        container_record.get("class", ""),
        str(container_record.get("has_input_connector", false)),
        str(container_record.get("has_output_connector", false)),
        container_record.get("connector_color", ""),
        container_record.get("input", ""),
        JSON.stringify(container_record.get("outputs", [])),
        container_record.get("script", ""),
        JSON.stringify(container_record.get("discovery", {}))
    ])


func _infer_domain_hint(window_name: String, scene_path: String, script_path: String, discovery: Dictionary) -> String:
    var name := window_name.to_lower()
    var scene := scene_path.to_lower()
    var script := script_path.to_lower()
    var discovery_text := JSON.stringify(discovery).to_lower()

    if name.begins_with("breach_") or name.begins_with("hacker") or name.begins_with("payload_") or name.begins_with("critical_payload") or name.begins_with("infect_payload") or _contains_any(scene, ["window_breach_", "window_hacker", "window_payload_", "window_critical_payload", "window_infect_payload"]):
        return "hacking_candidate"

    if name.begins_with("code_") or name.begins_with("coder") or name.begins_with("commit") or name.begins_with("comment_code") or name.begins_with("translate_code") or _contains_any(scene, ["window_code_", "window_coder", "window_commit", "window_comment_code", "window_translate_code"]):
        return "coding_candidate"

    if script.contains("window_machine_") or name.begins_with("copper_miner") or name.begins_with("silicon_miner") or name.begins_with("excavator") or name.begins_with("oil_pump") or name.begins_with("rare_earth_refinery") or name.begins_with("superconductor") or discovery_text.contains("\"resource\":\"work_speed\""):
        return "factory_candidate"

    return "system_or_unknown"


func _contains_any(value: String, needles: Array) -> bool:
    for needle in needles:
        if value.contains(str(needle)):
            return true
    return false


func _collect_discovery_properties(object: Object, property_names: Array) -> Dictionary:
    var result := {}

    for property_name in property_names:
        if not _has_property(object, str(property_name)):
            continue

        var value = object.get(str(property_name))
        var safe_value = _to_log_safe_value(value)
        if safe_value != null:
            result[str(property_name)] = safe_value

    return result


func _has_property(object: Object, property_name: String) -> bool:
    for property_info in object.get_property_list():
        if str(property_info.get("name", "")) == property_name:
            return true
    return false


func _property_as_string(object: Object, property_name: String) -> String:
    if not _has_property(object, property_name):
        return ""

    var value = object.get(property_name)
    if value == null:
        return ""

    return str(value)


func _property_as_string_array(object: Object, property_name: String) -> Array[String]:
    var result: Array[String] = []

    if not _has_property(object, property_name):
        return result

    var value = object.get(property_name)
    if value == null:
        return result

    if value is Array or value is PackedStringArray:
        for item in value:
            result.append(str(item))

    return result


func _to_log_safe_value(value):
    if value == null:
        return null
    if value is bool or value is int or value is float or value is String:
        return value
    if value is StringName:
        return str(value)
    if value is Vector2 or value is Vector2i:
        return str(value)
    if value is Array or value is PackedStringArray:
        var result: Array = []
        for item in value:
            if item is bool or item is int or item is float or item is String:
                result.append(item)
            elif item is StringName:
                result.append(str(item))
        return result
    return null


func _get_scene_path(object: Object) -> String:
    if "scene_file_path" in object:
        return str(object.get("scene_file_path"))
    return ""


func _get_script_path(object: Object) -> String:
    var script = object.get_script()
    if script is Script:
        return str(script.resource_path)
    return ""


func _sort_records_by_key(left: Dictionary, right: Dictionary) -> bool:
    return str(left.get("sort_key", "")) < str(right.get("sort_key", ""))
