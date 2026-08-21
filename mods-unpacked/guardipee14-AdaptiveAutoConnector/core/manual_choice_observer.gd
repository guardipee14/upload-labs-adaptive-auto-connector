extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][ManualChoice]"
const SUPPRESSION_WINDOW_MSEC := 30000

var _preference_model: Node = null
var _baseline_ready := false
var _previous_edges: Dictionary = {}
var _previous_container_ids: Dictionary = {}
var _suppressed_additions: Dictionary = {}
var _suppressed_removals: Dictionary = {}


func set_preference_model(model: Node) -> void:
    _preference_model = model


func set_connection_controller(controller: Node) -> void:
    if not is_instance_valid(controller):
        return

    if controller.has_signal("accept_completed"):
        controller.connect("accept_completed", Callable(self, "_on_accept_completed"))
    if controller.has_signal("undo_completed"):
        controller.connect("undo_completed", Callable(self, "_on_undo_completed"))


func consume_detailed_snapshot(snapshot: Dictionary) -> void:
    _previous_edges = _edges_from_detailed_snapshot(snapshot)
    _previous_container_ids = _container_ids_from_detailed_snapshot(snapshot)
    _baseline_ready = true
    print("%s Baseline ready containers=%d edges=%d mode='session_simple_additions'" % [
        LOG_PREFIX,
        _previous_container_ids.size(),
        _previous_edges.size()
    ])


func consume_lightweight_state(state: Dictionary) -> void:
    var current_edges := _edges_from_lightweight_state(state)
    var current_container_ids := _container_ids_from_lightweight_state(state)

    if not _baseline_ready:
        _previous_edges = current_edges
        _previous_container_ids = current_container_ids
        _baseline_ready = true
        print("%s Baseline recovered containers=%d edges=%d mode='session_simple_additions'" % [
            LOG_PREFIX,
            _previous_container_ids.size(),
            _previous_edges.size()
        ])
        return

    _cleanup_suppressions()

    var added_edges := _dictionary_difference(current_edges, _previous_edges)
    var removed_edges := _dictionary_difference(_previous_edges, current_edges)
    var added_containers := _dictionary_difference(current_container_ids, _previous_container_ids)
    var removed_containers := _dictionary_difference(_previous_container_ids, current_container_ids)

    var ignored_additions: Array[String] = []
    var ignored_removals: Array[String] = []

    for edge_id in added_edges.keys():
        if _suppressed_additions.has(edge_id):
            ignored_additions.append(str(edge_id))
            added_edges.erase(edge_id)
            _suppressed_additions.erase(edge_id)

    for edge_id in removed_edges.keys():
        if _suppressed_removals.has(edge_id):
            ignored_removals.append(str(edge_id))
            removed_edges.erase(edge_id)
            _suppressed_removals.erase(edge_id)

    ignored_additions.sort()
    ignored_removals.sort()

    if not ignored_additions.is_empty() or not ignored_removals.is_empty():
        print("%s Ignored AAC-owned delta additions=%s removals=%s" % [
            LOG_PREFIX,
            JSON.stringify(ignored_additions),
            JSON.stringify(ignored_removals)
        ])

    if added_edges.size() == 1 and removed_edges.is_empty() and added_containers.is_empty() and removed_containers.is_empty():
        var edge_id := str(added_edges.keys()[0])
        _consider_manual_addition(edge_id, current_edges[edge_id], state)
    elif not added_edges.is_empty():
        print("%s Observation skipped reason='ambiguous_delta' additions=%d removals=%d added_containers=%d removed_containers=%d" % [
            LOG_PREFIX,
            added_edges.size(),
            removed_edges.size(),
            added_containers.size(),
            removed_containers.size()
        ])

    _previous_edges = current_edges
    _previous_container_ids = current_container_ids


func _consider_manual_addition(edge_id: String, edge: Dictionary, state: Dictionary) -> void:
    var source_id := str(edge.get("source_id", ""))
    var target_id := str(edge.get("target_id", ""))
    var containers: Dictionary = state.get("containers", {})

    if not containers.has(source_id) or not containers.has(target_id):
        _skip(edge_id, "missing_endpoint")
        return

    var source_state: Dictionary = containers[source_id]
    var target_state: Dictionary = containers[target_id]

    if str(target_state.get("input", "")) != source_id:
        _skip(edge_id, "nonreciprocal_target")
        return

    var source_outputs := _string_array(source_state.get("outputs", []))
    if not source_outputs.has(target_id):
        _skip(edge_id, "nonreciprocal_source")
        return

    var source_node = source_state.get("node")
    var target_node = target_state.get("node")
    if not is_instance_valid(source_node) or not is_instance_valid(target_node):
        _skip(edge_id, "missing_live_node")
        return

    if source_node.get_node_or_null("OutputConnector") == null or target_node.get_node_or_null("InputConnector") == null:
        _skip(edge_id, "connector_direction")
        return

    var source_color := _connector_color(source_node)
    var target_color := _connector_color(target_node)
    if source_color.to_lower() == "black" or target_color.to_lower() == "black":
        _skip(edge_id, "blocked_connector")
        return

    var source_resource := _property_as_string(source_node, "resource")
    var target_resource := _property_as_string(target_node, "resource")
    if source_resource.is_empty() or target_resource.is_empty() or source_resource.to_lower() != target_resource.to_lower():
        _skip(edge_id, "resource_mismatch")
        return

    var record := {
        "source_id": source_id,
        "target_id": target_id,
        "source_window": str(source_state.get("window_name", "")),
        "source_name": str(source_state.get("name", "")),
        "target_window": str(target_state.get("window_name", "")),
        "target_name": str(target_state.get("name", "")),
        "resource": source_resource
    }

    if not is_instance_valid(_preference_model) or not _preference_model.has_method("record_manual_choice"):
        _skip(edge_id, "preference_model_unavailable")
        return

    var metadata := {
        "confidence": "strict_simple_addition",
        "source": "topology_delta",
        "session_only": true
    }
    var raw_result = _preference_model.call("record_manual_choice", record, metadata)
    if not raw_result is Dictionary:
        _skip(edge_id, "preference_result_invalid")
        return

    var result: Dictionary = raw_result
    print("%s Learned edge='%s' key='%s' delta=%s after=%s confidence='strict_simple_addition'" % [
        LOG_PREFIX,
        edge_id,
        result.get("semantic_key", ""),
        str(result.get("delta", 0.0)),
        str(result.get("after", 0.0))
    ])


func _on_accept_completed(result: Dictionary) -> void:
    if not bool(result.get("ok", false)) or str(result.get("code", "")) != "accept_connected":
        return

    var source_id := str(result.get("source_id", ""))
    var target_id := str(result.get("target_id", ""))
    if source_id.is_empty() or target_id.is_empty():
        return

    var edge_id := _edge_id(source_id, target_id)
    _suppressed_additions[edge_id] = Time.get_ticks_msec() + SUPPRESSION_WINDOW_MSEC
    print("%s Suppress AAC addition edge='%s' window_msec=%d" % [LOG_PREFIX, edge_id, SUPPRESSION_WINDOW_MSEC])


func _on_undo_completed(result: Dictionary) -> void:
    if not bool(result.get("ok", false)) or str(result.get("code", "")) != "undo_disconnected":
        return

    var snapshot: Dictionary = result.get("snapshot", {})
    var source_id := str(snapshot.get("source_id", ""))
    var target_id := str(snapshot.get("target_id", ""))
    if source_id.is_empty() or target_id.is_empty():
        return

    var edge_id := _edge_id(source_id, target_id)
    _suppressed_removals[edge_id] = Time.get_ticks_msec() + SUPPRESSION_WINDOW_MSEC
    print("%s Suppress AAC removal edge='%s' window_msec=%d" % [LOG_PREFIX, edge_id, SUPPRESSION_WINDOW_MSEC])


func _edges_from_detailed_snapshot(snapshot: Dictionary) -> Dictionary:
    var edges := {}
    for raw_window in snapshot.get("windows", []):
        if not raw_window is Dictionary:
            continue
        var window_record: Dictionary = raw_window
        for raw_container in window_record.get("containers", []):
            if not raw_container is Dictionary:
                continue
            var container: Dictionary = raw_container
            var source_id := str(container.get("id", ""))
            if source_id.is_empty():
                continue
            for target_id in _string_array(container.get("outputs", [])):
                var edge_id := _edge_id(source_id, target_id)
                edges[edge_id] = {
                    "source_id": source_id,
                    "target_id": target_id
                }
    return edges


func _container_ids_from_detailed_snapshot(snapshot: Dictionary) -> Dictionary:
    var ids := {}
    for raw_window in snapshot.get("windows", []):
        if not raw_window is Dictionary:
            continue
        var window_record: Dictionary = raw_window
        for raw_container in window_record.get("containers", []):
            if not raw_container is Dictionary:
                continue
            var container: Dictionary = raw_container
            var container_id := str(container.get("id", ""))
            if not container_id.is_empty():
                ids[container_id] = true
    return ids


func _edges_from_lightweight_state(state: Dictionary) -> Dictionary:
    var edges := {}
    var containers: Dictionary = state.get("containers", {})
    for raw_id in containers.keys():
        var source_id := str(raw_id)
        var record: Dictionary = containers[raw_id]
        for target_id in _string_array(record.get("outputs", [])):
            var edge_id := _edge_id(source_id, target_id)
            edges[edge_id] = {
                "source_id": source_id,
                "target_id": target_id
            }
    return edges


func _container_ids_from_lightweight_state(state: Dictionary) -> Dictionary:
    var ids := {}
    for raw_id in state.get("containers", {}).keys():
        ids[str(raw_id)] = true
    return ids


func _dictionary_difference(left: Dictionary, right: Dictionary) -> Dictionary:
    var result := {}
    for key in left.keys():
        if not right.has(key):
            result[key] = left[key]
    return result


func _cleanup_suppressions() -> void:
    var now := Time.get_ticks_msec()
    for edge_id in _suppressed_additions.keys():
        if int(_suppressed_additions[edge_id]) < now:
            _suppressed_additions.erase(edge_id)
    for edge_id in _suppressed_removals.keys():
        if int(_suppressed_removals[edge_id]) < now:
            _suppressed_removals.erase(edge_id)


func _connector_color(container) -> String:
    if is_instance_valid(container) and container.has_method("get_connector_color"):
        return str(container.call("get_connector_color"))
    return ""


func _property_as_string(object: Object, property_name: String) -> String:
    if not is_instance_valid(object) or not property_name in object:
        return ""
    var value = object.get(property_name)
    return "" if value == null else str(value)


func _string_array(value) -> Array[String]:
    var result: Array[String] = []
    if value is Array or value is PackedStringArray:
        for item in value:
            result.append(str(item))
    result.sort()
    return result


func _edge_id(source_id: String, target_id: String) -> String:
    return "%s->%s" % [source_id, target_id]


func _skip(edge_id: String, reason: String) -> void:
    print("%s Observation skipped edge='%s' reason='%s'" % [LOG_PREFIX, edge_id, reason])
