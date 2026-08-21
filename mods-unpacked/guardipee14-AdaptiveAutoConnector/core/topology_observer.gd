extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Topology]"
const SCAN_INTERVAL_SECONDS := 2.0
const READY_RETRY_SECONDS := 0.5
const MAX_READY_ATTEMPTS := 60

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
var _last_topology_signature := ""


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
    var snapshot := _build_snapshot(windows_node)
    _last_topology_signature = _build_topology_signature(snapshot)
    _report_snapshot("initial", snapshot)

    _scan_timer = Timer.new()
    _scan_timer.name = "TopologyScanTimer"
    _scan_timer.wait_time = SCAN_INTERVAL_SECONDS
    _scan_timer.one_shot = false
    _scan_timer.autostart = true
    _scan_timer.timeout.connect(_on_scan_timer_timeout)
    add_child(_scan_timer)

    print("%s Observer active; read-only scan interval %.1fs." % [LOG_PREFIX, SCAN_INTERVAL_SECONDS])


func _on_scan_timer_timeout() -> void:
    if not is_instance_valid(Globals.desktop):
        return

    var windows_node := Globals.desktop.get_node_or_null("Windows")
    if not is_instance_valid(windows_node):
        return

    var snapshot := _build_snapshot(windows_node)
    var signature := _build_topology_signature(snapshot)

    if signature == _last_topology_signature:
        return

    _last_topology_signature = signature
    _report_snapshot("topology_changed", snapshot)


func _build_snapshot(windows_node: Node) -> Dictionary:
    var window_records: Array = []
    var container_count := 0
    var connection_count := 0

    for child in windows_node.get_children():
        if not is_instance_valid(child):
            continue
        if not child is WindowBase:
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
    var scene_path := ""
    if "scene_file_path" in window:
        scene_path = str(window.get("scene_file_path"))

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


func _build_topology_signature(snapshot: Dictionary) -> String:
    var parts: Array[String] = []

    for window_record in snapshot.get("windows", []):
        parts.append("W:%s:%s:%s" % [
            window_record.get("name", ""),
            window_record.get("scene", ""),
            window_record.get("script", "")
        ])

        for container_record in window_record.get("containers", []):
            parts.append("C:%s:%s:%s:%s:%s:%s" % [
                container_record.get("id", ""),
                container_record.get("input", ""),
                JSON.stringify(container_record.get("outputs", [])),
                str(container_record.get("has_input_connector", false)),
                str(container_record.get("has_output_connector", false)),
                container_record.get("connector_color", "")
            ])

    return JSON.stringify(parts)


func _report_snapshot(reason: String, snapshot: Dictionary) -> void:
    print("%s Snapshot reason=%s windows=%d containers=%d connections=%d" % [
        LOG_PREFIX,
        reason,
        int(snapshot.get("window_count", 0)),
        int(snapshot.get("container_count", 0)),
        int(snapshot.get("connection_count", 0))
    ])

    for window_record in snapshot.get("windows", []):
        print("%s Window name='%s' class='%s' domain_hint='%s' scene='%s' script='%s' discovery=%s" % [
            LOG_PREFIX,
            window_record.get("name", ""),
            window_record.get("class", ""),
            window_record.get("domain_hint", "system_or_unknown"),
            window_record.get("scene", ""),
            window_record.get("script", ""),
            JSON.stringify(window_record.get("discovery", {}))
        ])

        for container_record in window_record.get("containers", []):
            print("%s   Container name='%s' id='%s' class='%s' in_connector=%s out_connector=%s color='%s' input='%s' outputs=%s script='%s' discovery=%s" % [
                LOG_PREFIX,
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
    var haystack := "%s %s %s %s" % [window_name, scene_path, script_path, JSON.stringify(discovery)]
    haystack = haystack.to_lower()

    if _contains_any(haystack, ["hack", "breach", "firewall", "payload", "spoof", "ddos", "trojan"]):
        return "hacking_candidate"
    if _contains_any(haystack, ["coding", "code", "commit", "compiler", "driver", "optimization"]):
        return "coding_candidate"
    if _contains_any(haystack, ["factory", "assembler", "miner", "refinery", "machinery", "smelter"]):
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


func _get_script_path(object: Object) -> String:
    var script = object.get_script()
    if script is Script:
        return str(script.resource_path)
    return ""


func _sort_records_by_key(left: Dictionary, right: Dictionary) -> bool:
    return str(left.get("sort_key", "")) < str(right.get("sort_key", ""))
