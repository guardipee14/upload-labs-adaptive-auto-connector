extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Graph]"
const GRAPH_SCHEMA_VERSION := 1
const MAX_ISSUES_TO_LOG := 12

var _graph: Dictionary = {}
var _revision := 0


func consume_detailed_snapshot(snapshot: Dictionary) -> void:
    _revision += 1
    _graph = _normalize_detailed_snapshot(snapshot)
    _graph["revision"] = _revision
    _report_graph("initial")


func consume_lightweight_state(state: Dictionary) -> void:
    if _graph.is_empty():
        return

    _synchronize_from_lightweight_state(state)
    _revision += 1
    _graph["revision"] = _revision
    _report_graph("topology_changed")


func get_graph() -> Dictionary:
    return _graph.duplicate(true)


func _normalize_detailed_snapshot(snapshot: Dictionary) -> Dictionary:
    var windows := {}
    var containers := {}
    var unidentified_containers := 0

    for raw_window in snapshot.get("windows", []):
        if not raw_window is Dictionary:
            continue

        var window_record: Dictionary = raw_window
        var window_name := str(window_record.get("name", ""))
        var scene_path := str(window_record.get("scene", ""))
        var window_key := _window_key(window_name, scene_path)
        var normalized_window := {
            "key": window_key,
            "name": window_name,
            "class": str(window_record.get("class", "")),
            "scene": scene_path,
            "script": str(window_record.get("script", "")),
            "domain_hint": str(window_record.get("domain_hint", "system_or_unknown")),
            "containers": []
        }
        windows[window_key] = normalized_window

        for raw_container in window_record.get("containers", []):
            if not raw_container is Dictionary:
                continue

            var container_record: Dictionary = raw_container
            var container_id := str(container_record.get("id", ""))
            if container_id.is_empty():
                unidentified_containers += 1
                continue

            var normalized_container := _normalize_detailed_container(container_record, normalized_window)
            containers[container_id] = normalized_container
            normalized_window["containers"].append(container_id)

    _sort_window_container_ids(windows)

    var graph := {
        "schema_version": GRAPH_SCHEMA_VERSION,
        "revision": 0,
        "windows": windows,
        "containers": containers,
        "edges": [],
        "domains": {},
        "resources": {},
        "stats": {
            "unidentified_containers": unidentified_containers
        }
    }

    _rebuild_derived_indexes(graph)
    return graph


func _normalize_detailed_container(container_record: Dictionary, window_record: Dictionary) -> Dictionary:
    var discovery: Dictionary = container_record.get("discovery", {})
    var has_input := bool(container_record.get("has_input_connector", false))
    var has_output := bool(container_record.get("has_output_connector", false))

    return {
        "id": str(container_record.get("id", "")),
        "name": str(container_record.get("name", "")),
        "class": str(container_record.get("class", "")),
        "window_key": str(window_record.get("key", "")),
        "window_name": str(window_record.get("name", "")),
        "domain_hint": str(window_record.get("domain_hint", "system_or_unknown")),
        "script": str(container_record.get("script", "")),
        "resource": str(discovery.get("resource", "")),
        "resource_type": str(discovery.get("resource_type", discovery.get("type", ""))),
        "role": _connector_role(has_input, has_output),
        "has_input_connector": has_input,
        "has_output_connector": has_output,
        "connector_color": str(container_record.get("connector_color", "")),
        "input": str(container_record.get("input", "")),
        "outputs": _string_array(container_record.get("outputs", [])),
        "production": discovery.get("production", null),
        "required": discovery.get("required", null),
        "demand": discovery.get("demand", null),
        "ratio": discovery.get("ratio", null),
        "goal": discovery.get("goal", null)
    }


func _synchronize_from_lightweight_state(state: Dictionary) -> void:
    var graph_windows: Dictionary = _graph.get("windows", {})
    var graph_containers: Dictionary = _graph.get("containers", {})
    var state_windows: Dictionary = state.get("windows", {})
    var state_containers: Dictionary = state.get("containers", {})

    for existing_key in graph_windows.keys():
        if not state_windows.has(existing_key):
            graph_windows.erase(existing_key)

    for raw_key in state_windows.keys():
        var window_key := str(raw_key)
        var state_window: Dictionary = state_windows[raw_key]
        if graph_windows.has(window_key):
            continue

        graph_windows[window_key] = {
            "key": window_key,
            "name": str(state_window.get("name", "")),
            "class": "",
            "scene": str(state_window.get("scene", "")),
            "script": "",
            "domain_hint": "system_or_unknown",
            "containers": []
        }

    for existing_id in graph_containers.keys():
        if not state_containers.has(existing_id):
            graph_containers.erase(existing_id)

    for raw_id in state_containers.keys():
        var container_id := str(raw_id)
        var state_container: Dictionary = state_containers[raw_id]

        if graph_containers.has(container_id):
            var existing: Dictionary = graph_containers[container_id]
            existing["input"] = str(state_container.get("input", ""))
            existing["outputs"] = _string_array(state_container.get("outputs", []))
            existing["window_key"] = str(state_container.get("window_key", existing.get("window_key", "")))
            existing["window_name"] = str(state_container.get("window_name", existing.get("window_name", "")))
            continue

        graph_containers[container_id] = _normalize_added_container(state_container, graph_windows)

    for raw_window in graph_windows.values():
        if raw_window is Dictionary:
            raw_window["containers"] = []

    for raw_container in graph_containers.values():
        if not raw_container is Dictionary:
            continue
        var container: Dictionary = raw_container
        var window_key := str(container.get("window_key", ""))
        if graph_windows.has(window_key):
            graph_windows[window_key]["containers"].append(str(container.get("id", "")))

    _sort_window_container_ids(graph_windows)
    _rebuild_derived_indexes(_graph)


func _normalize_added_container(state_container: Dictionary, graph_windows: Dictionary) -> Dictionary:
    var container_id := str(state_container.get("id", ""))
    var window_key := str(state_container.get("window_key", ""))
    var window_name := str(state_container.get("window_name", ""))
    var domain_hint := "system_or_unknown"

    if graph_windows.has(window_key):
        domain_hint = str(graph_windows[window_key].get("domain_hint", "system_or_unknown"))

    var node = state_container.get("node")
    var resource := ""
    var resource_type := ""
    var script_path := ""
    var has_input := false
    var has_output := false
    var connector_color := ""
    var production = null
    var required = null
    var demand = null
    var ratio = null
    var goal = null

    if is_instance_valid(node):
        resource = _object_property_as_string(node, "resource")
        resource_type = _object_property_as_string(node, "resource_type")
        if resource_type.is_empty():
            resource_type = _object_property_as_string(node, "type")

        var script = node.get_script()
        if script is Script:
            script_path = str(script.resource_path)

        has_input = is_instance_valid(node.get_node_or_null("InputConnector"))
        has_output = is_instance_valid(node.get_node_or_null("OutputConnector"))

        if node.has_method("get_connector_color"):
            connector_color = str(node.call("get_connector_color"))

        production = _object_property(node, "production")
        required = _object_property(node, "required")
        demand = _object_property(node, "demand")
        ratio = _object_property(node, "ratio")
        goal = _object_property(node, "goal")

    return {
        "id": container_id,
        "name": str(state_container.get("name", "")),
        "class": node.get_class() if is_instance_valid(node) else "",
        "window_key": window_key,
        "window_name": window_name,
        "domain_hint": domain_hint,
        "script": script_path,
        "resource": resource,
        "resource_type": resource_type,
        "role": _connector_role(has_input, has_output),
        "has_input_connector": has_input,
        "has_output_connector": has_output,
        "connector_color": connector_color,
        "input": str(state_container.get("input", "")),
        "outputs": _string_array(state_container.get("outputs", [])),
        "production": production,
        "required": required,
        "demand": demand,
        "ratio": ratio,
        "goal": goal
    }


func _rebuild_derived_indexes(graph: Dictionary) -> void:
    var windows: Dictionary = graph.get("windows", {})
    var containers: Dictionary = graph.get("containers", {})
    var edges: Array = []
    var domains := {}
    var resources := {}
    var seen_edges := {}
    var dangling_edges := 0
    var nonreciprocal_edges := 0
    var resource_mismatch_edges := 0
    var duplicate_edges := 0
    var role_counts := {
        "source": 0,
        "sink": 0,
        "relay": 0,
        "passive": 0
    }

    for window_key in windows.keys():
        var window: Dictionary = windows[window_key]
        var domain_hint := str(window.get("domain_hint", "system_or_unknown"))
        if not domains.has(domain_hint):
            domains[domain_hint] = []
        domains[domain_hint].append(str(window_key))

    for container_id in containers.keys():
        var container: Dictionary = containers[container_id]
        var role := str(container.get("role", "passive"))
        role_counts[role] = int(role_counts.get(role, 0)) + 1

        var resource := str(container.get("resource", ""))
        if not resource.is_empty():
            if not resources.has(resource):
                resources[resource] = []
            resources[resource].append(str(container_id))

        for target_id in _string_array(container.get("outputs", [])):
            var edge_id := "%s->%s" % [container_id, target_id]
            if seen_edges.has(edge_id):
                duplicate_edges += 1
                continue
            seen_edges[edge_id] = true

            var target_exists := containers.has(target_id)
            var reciprocal := false
            var resource_match := true
            var target_resource := ""

            if target_exists:
                var target: Dictionary = containers[target_id]
                reciprocal = str(target.get("input", "")) == str(container_id)
                target_resource = str(target.get("resource", ""))
                if not resource.is_empty() and not target_resource.is_empty():
                    resource_match = resource.to_lower() == target_resource.to_lower()
            else:
                dangling_edges += 1

            if target_exists and not reciprocal:
                nonreciprocal_edges += 1
            if target_exists and not resource_match:
                resource_mismatch_edges += 1

            edges.append({
                "id": edge_id,
                "from": str(container_id),
                "to": target_id,
                "resource": resource if not resource.is_empty() else target_resource,
                "target_exists": target_exists,
                "reciprocal": reciprocal,
                "resource_match": resource_match
            })

    for domain_key in domains.keys():
        domains[domain_key].sort()
    for resource_key in resources.keys():
        resources[resource_key].sort()
    edges.sort_custom(_sort_edges)

    var previous_stats: Dictionary = graph.get("stats", {})
    graph["edges"] = edges
    graph["domains"] = domains
    graph["resources"] = resources
    graph["stats"] = {
        "window_count": windows.size(),
        "container_count": containers.size(),
        "edge_count": edges.size(),
        "resource_count": resources.size(),
        "dangling_edges": dangling_edges,
        "nonreciprocal_edges": nonreciprocal_edges,
        "resource_mismatch_edges": resource_mismatch_edges,
        "duplicate_edges": duplicate_edges,
        "unidentified_containers": int(previous_stats.get("unidentified_containers", 0)),
        "role_counts": role_counts
    }


func _report_graph(reason: String) -> void:
    var stats: Dictionary = _graph.get("stats", {})
    var role_counts: Dictionary = stats.get("role_counts", {})

    print("%s Graph revision=%d reason=%s windows=%d containers=%d edges=%d resources=%d dangling=%d nonreciprocal=%d resource_mismatch=%d" % [
        LOG_PREFIX,
        _revision,
        reason,
        int(stats.get("window_count", 0)),
        int(stats.get("container_count", 0)),
        int(stats.get("edge_count", 0)),
        int(stats.get("resource_count", 0)),
        int(stats.get("dangling_edges", 0)),
        int(stats.get("nonreciprocal_edges", 0)),
        int(stats.get("resource_mismatch_edges", 0))
    ])

    print("%s Roles source=%d sink=%d relay=%d passive=%d unidentified=%d" % [
        LOG_PREFIX,
        int(role_counts.get("source", 0)),
        int(role_counts.get("sink", 0)),
        int(role_counts.get("relay", 0)),
        int(role_counts.get("passive", 0)),
        int(stats.get("unidentified_containers", 0))
    ])

    var domain_parts: Array[String] = []
    var domains: Dictionary = _graph.get("domains", {})
    var domain_keys := domains.keys()
    domain_keys.sort()
    for domain_key in domain_keys:
        domain_parts.append("%s=%d" % [str(domain_key), domains[domain_key].size()])
    print("%s Domain hints %s" % [LOG_PREFIX, " ".join(domain_parts)])

    _report_edge_issues()


func _report_edge_issues() -> void:
    var logged := 0

    for raw_edge in _graph.get("edges", []):
        if logged >= MAX_ISSUES_TO_LOG:
            break
        if not raw_edge is Dictionary:
            continue

        var edge: Dictionary = raw_edge
        if bool(edge.get("target_exists", true)) and bool(edge.get("reciprocal", true)) and bool(edge.get("resource_match", true)):
            continue

        print("%s   Edge issue from='%s' to='%s' resource='%s' target_exists=%s reciprocal=%s resource_match=%s" % [
            LOG_PREFIX,
            edge.get("from", ""),
            edge.get("to", ""),
            edge.get("resource", ""),
            str(edge.get("target_exists", false)),
            str(edge.get("reciprocal", false)),
            str(edge.get("resource_match", false))
        ])
        logged += 1


func _connector_role(has_input: bool, has_output: bool) -> String:
    if has_input and has_output:
        return "relay"
    if has_output:
        return "source"
    if has_input:
        return "sink"
    return "passive"


func _window_key(window_name: String, scene_path: String) -> String:
    return "%s|%s" % [window_name, scene_path]


func _sort_window_container_ids(windows: Dictionary) -> void:
    for raw_window in windows.values():
        if raw_window is Dictionary:
            raw_window["containers"].sort()


func _string_array(value) -> Array[String]:
    var result: Array[String] = []
    if value is Array or value is PackedStringArray:
        for item in value:
            result.append(str(item))
    result.sort()
    return result


func _object_property(object: Object, property_name: String):
    if not is_instance_valid(object):
        return null
    if not property_name in object:
        return null
    return object.get(property_name)


func _object_property_as_string(object: Object, property_name: String) -> String:
    var value = _object_property(object, property_name)
    if value == null:
        return ""
    return str(value)


func _sort_edges(left: Dictionary, right: Dictionary) -> bool:
    return str(left.get("id", "")) < str(right.get("id", ""))
