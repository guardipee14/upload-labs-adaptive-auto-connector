extends "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/ui/interaction_presenter.gd"

const ADAPTIVE_LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Adaptive]"

var _preference_model: Node = null


func set_preference_model(model: Node) -> void:
    _preference_model = model


func _recommendation_from_candidate(candidate: Dictionary) -> Dictionary:
    var recommendation: Dictionary = super._recommendation_from_candidate(candidate)
    var preference: Dictionary = candidate.get("player_preference", {})
    var adjustment := float(preference.get("adjustment", 0.0))

    if abs(adjustment) > 0.01:
        var reasons: Array = recommendation.get("reasons", [])
        reasons.append("Your choices in this play session adjust this semantic route by %+.2f advisory point(s); legality and live Accept guards still take priority." % adjustment)
        recommendation["reasons"] = reasons

    recommendation["player_preference"] = preference.duplicate(true)
    return recommendation


func _on_find_different_pressed() -> void:
    var before := _current_recommendation().duplicate(true)
    super._on_find_different_pressed()
    if not before.is_empty():
        _record_preference("record_alternate", before)


func _on_no_thanks_pressed() -> void:
    var before := _current_recommendation().duplicate(true)
    super._on_no_thanks_pressed()
    if not before.is_empty():
        _record_preference("record_rejection", before)


func _on_accept_pressed() -> void:
    var before := _current_recommendation().duplicate(true)
    super._on_accept_pressed()

    if before.is_empty() or not is_instance_valid(_connection_controller):
        return
    if not _connection_controller.has_method("get_last_accept_snapshot"):
        return

    var raw_snapshot = _connection_controller.call("get_last_accept_snapshot")
    if raw_snapshot is Dictionary:
        var snapshot: Dictionary = raw_snapshot
        if _snapshot_matches_recommendation(snapshot, before):
            _record_preference("record_accept", before)


func _on_undo_pressed() -> void:
    var before_snapshot: Dictionary = {}
    if is_instance_valid(_connection_controller) and _connection_controller.has_method("get_last_accept_snapshot"):
        var raw_before = _connection_controller.call("get_last_accept_snapshot")
        if raw_before is Dictionary:
            before_snapshot = raw_before.duplicate(true)

    super._on_undo_pressed()

    if before_snapshot.is_empty() or not is_instance_valid(_connection_controller):
        return
    if not _connection_controller.has_method("get_last_accept_snapshot"):
        return

    var raw_after = _connection_controller.call("get_last_accept_snapshot")
    if raw_after is Dictionary:
        var after_snapshot: Dictionary = raw_after
        if after_snapshot.is_empty():
            _record_preference("record_undo", before_snapshot)


func _record_preference(method_name: String, record: Dictionary) -> void:
    if not is_instance_valid(_preference_model):
        return
    if not _preference_model.has_method(method_name):
        return

    var result = _preference_model.call(method_name, record)
    if result is Dictionary:
        print("%s Learned method='%s' key='%s' delta=%s after=%s" % [
            ADAPTIVE_LOG_PREFIX,
            method_name,
            result.get("semantic_key", ""),
            str(result.get("delta", 0.0)),
            str(result.get("after", 0.0))
        ])


func _snapshot_matches_recommendation(snapshot: Dictionary, recommendation: Dictionary) -> bool:
    return (
        str(snapshot.get("source_id", "")) == str(recommendation.get("source_id", ""))
        and str(snapshot.get("target_id", "")) == str(recommendation.get("target_id", ""))
        and str(snapshot.get("resource", "")) == str(recommendation.get("resource", ""))
    )
