extends Node

signal accept_completed(result: Dictionary)
signal undo_completed(result: Dictionary)

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Connect]"

var _last_accept_snapshot: Dictionary = {}


func capture_guard(recommendation: Dictionary, sample_index: int) -> Dictionary:
    var source_id := str(recommendation.get("source_id", ""))
    var target_id := str(recommendation.get("target_id", ""))

    var source = _resolve_exact(source_id)
    var target = _resolve_exact(target_id)
    if not is_instance_valid(source) or not is_instance_valid(target):
        return {
            "valid": false,
            "code": "guard_missing_endpoint",
            "sample_index": sample_index,
            "source_id": source_id,
            "target_id": target_id
        }

    return {
        "valid": true,
        "code": "guard_ready",
        "sample_index": sample_index,
        "source_id": source_id,
        "target_id": target_id,
        "source_outputs": _string_array(source.get("outputs_id")),
        "target_input": str(target.get("input_id")),
        "source_resource": str(source.get("resource")),
        "target_resource": str(target.get("resource")),
        "source_color": _connector_color(source),
        "target_color": _connector_color(target)
    }


func accept(recommendation: Dictionary, guard: Dictionary) -> Dictionary:
    var result := _validate_accept(recommendation, guard)
    if not bool(result.get("ok", false)):
        print("%s Accept refused code='%s' message='%s'" % [
            LOG_PREFIX,
            result.get("code", "unknown"),
            result.get("message", "")
        ])
        accept_completed.emit(result.duplicate(true))
        return result

    var source_id := str(result.get("source_id", ""))
    var target_id := str(result.get("target_id", ""))
    var source = _resolve_exact(source_id)
    var target = _resolve_exact(target_id)

    var snapshot := {
        "source_id": source_id,
        "target_id": target_id,
        "source_window": str(recommendation.get("source_window", "")),
        "source_name": str(recommendation.get("source_name", "")),
        "target_window": str(recommendation.get("target_window", "")),
        "target_name": str(recommendation.get("target_name", "")),
        "resource": str(recommendation.get("resource", "")),
        "source_outputs_before": _string_array(source.get("outputs_id")),
        "target_input_before": str(target.get("input_id")),
        "sample_index": int(guard.get("sample_index", 0))
    }

    Signals.create_connection.emit(source_id, target_id)

    var connected := _connection_exists(source_id, target_id)
    if connected:
        _last_accept_snapshot = snapshot
        if is_instance_valid(Sound) and Sound.has_method("play"):
            Sound.play("connect")

        result = {
            "ok": true,
            "code": "accept_connected",
            "message": "Connection created after live revalidation.",
            "source_id": source_id,
            "target_id": target_id,
            "snapshot": snapshot.duplicate(true),
            "undo_available": true
        }
        print("%s Accept connected source='%s' target='%s' resource='%s' undo_available=true" % [
            LOG_PREFIX,
            source_id,
            target_id,
            recommendation.get("resource", "")
        ])
    else:
        result = {
            "ok": false,
            "code": "accept_unconfirmed",
            "message": "Create signal was emitted but the connection could not be confirmed immediately.",
            "source_id": source_id,
            "target_id": target_id,
            "undo_available": false
        }
        push_warning("%s Accept emitted but connection was not confirmed source='%s' target='%s'." % [
            LOG_PREFIX,
            source_id,
            target_id
        ])

    accept_completed.emit(result.duplicate(true))
    return result


func can_undo_last_accept() -> bool:
    if _last_accept_snapshot.is_empty():
        return false

    var source_id := str(_last_accept_snapshot.get("source_id", ""))
    var target_id := str(_last_accept_snapshot.get("target_id", ""))
    return _connection_exists(source_id, target_id)


func undo_last_accept() -> Dictionary:
    if _last_accept_snapshot.is_empty():
        var empty_result := {
            "ok": false,
            "code": "undo_none",
            "message": "There is no accepted connection to undo."
        }
        undo_completed.emit(empty_result.duplicate(true))
        return empty_result

    var source_id := str(_last_accept_snapshot.get("source_id", ""))
    var target_id := str(_last_accept_snapshot.get("target_id", ""))

    if not _connection_exists(source_id, target_id):
        var changed_result := {
            "ok": false,
            "code": "undo_state_changed",
            "message": "The accepted connection is no longer present exactly as created, so automatic undo was refused."
        }
        print("%s Undo refused source='%s' target='%s' reason='state_changed'" % [LOG_PREFIX, source_id, target_id])
        undo_completed.emit(changed_result.duplicate(true))
        return changed_result

    Signals.delete_connection.emit(source_id, target_id)

    if not _connection_exists(source_id, target_id):
        var snapshot := _last_accept_snapshot.duplicate(true)
        _last_accept_snapshot.clear()
        var success_result := {
            "ok": true,
            "code": "undo_disconnected",
            "message": "Last accepted connection was removed.",
            "snapshot": snapshot,
            "undo_available": false
        }
        print("%s Undo disconnected source='%s' target='%s'" % [LOG_PREFIX, source_id, target_id])
        undo_completed.emit(success_result.duplicate(true))
        return success_result

    var failed_result := {
        "ok": false,
        "code": "undo_unconfirmed",
        "message": "Delete signal was emitted but disconnection could not be confirmed immediately."
    }
    push_warning("%s Undo emitted but disconnect was not confirmed source='%s' target='%s'." % [
        LOG_PREFIX,
        source_id,
        target_id
    ])
    undo_completed.emit(failed_result.duplicate(true))
    return failed_result


func get_last_accept_snapshot() -> Dictionary:
    return _last_accept_snapshot.duplicate(true)


func _validate_accept(recommendation: Dictionary, guard: Dictionary) -> Dictionary:
    if not bool(guard.get("valid", false)):
        return _refusal("accept_guard_invalid", "The recommendation does not have a valid live guard snapshot.")

    var source_id := str(recommendation.get("source_id", ""))
    var target_id := str(recommendation.get("target_id", ""))
    var resource := str(recommendation.get("resource", ""))

    if source_id.is_empty() or target_id.is_empty() or source_id == target_id:
        return _refusal("accept_invalid_ids", "The recommendation endpoint IDs are invalid.")

    if source_id != str(guard.get("source_id", "")) or target_id != str(guard.get("target_id", "")):
        return _refusal("accept_guard_mismatch", "The displayed recommendation changed after its guard snapshot was captured.")

    var source = _resolve_exact(source_id)
    var target = _resolve_exact(target_id)
    if not is_instance_valid(source) or not is_instance_valid(target):
        return _refusal("accept_stale_endpoint", "A recommended runtime endpoint was recreated or removed. Wait for the next advisor refresh.")

    if source.get_node_or_null("OutputConnector") == null or target.get_node_or_null("InputConnector") == null:
        return _refusal("accept_connector_missing", "The live endpoints no longer expose the expected connector direction.")

    var source_color := _connector_color(source)
    var target_color := _connector_color(target)
    if source_color.to_lower() == "black" or target_color.to_lower() == "black":
        return _refusal("accept_connector_blocked", "A connector became blocked after the recommendation was generated.")

    if source_color != str(guard.get("source_color", "")) or target_color != str(guard.get("target_color", "")):
        return _refusal("accept_connector_changed", "Connector state changed after the recommendation was generated.")

    var source_resource := str(source.get("resource"))
    var target_resource := str(target.get("resource"))
    if source_resource != resource or target_resource != resource:
        return _refusal("accept_resource_changed", "The live endpoint resource no longer matches the recommendation.")

    if source_resource != str(guard.get("source_resource", "")) or target_resource != str(guard.get("target_resource", "")):
        return _refusal("accept_resource_guard_changed", "Resource state changed after the recommendation was generated.")

    var current_target_input := str(target.get("input_id"))
    if not current_target_input.is_empty():
        return _refusal("accept_target_served", "The target acquired an input route before Accept was pressed.")

    if current_target_input != str(guard.get("target_input", "")):
        return _refusal("accept_target_changed", "The target input state changed after the recommendation was generated.")

    var current_outputs := _string_array(source.get("outputs_id"))
    var guarded_outputs := _string_array(guard.get("source_outputs", []))
    if current_outputs != guarded_outputs:
        return _refusal("accept_source_routes_changed", "The source output routes changed after the recommendation was generated.")

    if current_outputs.has(target_id):
        return _refusal("accept_duplicate", "The recommended connection already exists.")

    if not _live_can_connect(source, target):
        return _refusal("accept_no_longer_connectable", "The game no longer reports this pair as connectable.")

    return {
        "ok": true,
        "code": "accept_validated",
        "message": "Live topology still matches the displayed recommendation.",
        "source_id": source_id,
        "target_id": target_id
    }


func _resolve_exact(container_id: String):
    if container_id.is_empty() or not is_instance_valid(Globals.desktop):
        return null
    if not Globals.desktop.has_method("get_resource"):
        return null
    return Globals.desktop.call("get_resource", container_id)


func _live_can_connect(source, target) -> bool:
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


func _connection_exists(source_id: String, target_id: String) -> bool:
    var source = _resolve_exact(source_id)
    var target = _resolve_exact(target_id)
    if not is_instance_valid(source) or not is_instance_valid(target):
        return false

    var outputs := _string_array(source.get("outputs_id"))
    var target_input := str(target.get("input_id"))
    return outputs.has(target_id) and target_input == source_id


func _connector_color(container) -> String:
    if not is_instance_valid(container):
        return ""
    if container.has_method("get_connector_color"):
        return str(container.call("get_connector_color"))
    return ""


func _string_array(value) -> Array[String]:
    var result: Array[String] = []
    if value is Array:
        for item in value:
            result.append(str(item))
    result.sort()
    return result


func _refusal(code: String, message: String) -> Dictionary:
    return {
        "ok": false,
        "code": code,
        "message": message,
        "undo_available": can_undo_last_accept()
    }
