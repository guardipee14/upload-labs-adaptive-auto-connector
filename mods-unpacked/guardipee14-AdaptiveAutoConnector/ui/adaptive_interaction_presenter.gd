extends "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/ui/interaction_presenter.gd"

const ADAPTIVE_LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Adaptive]"
const SUPPRESSION_LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Suppression]"

var _preference_model: Node = null
var _last_suppression_signature_by_target: Dictionary = {}


func set_preference_model(model: Node) -> void:
    _preference_model = model


func _apply_session_choices(incoming: Dictionary) -> Dictionary:
    var adjusted: Dictionary = {}
    var scored_snapshot := _get_scored_snapshot()

    for raw_target_id in incoming.keys():
        var target_id := str(raw_target_id)
        var original = incoming[raw_target_id]
        if not original is Dictionary:
            continue

        var candidates: Array = scored_snapshot.get(target_id, [])
        if candidates.is_empty():
            var original_rec: Dictionary = original
            if not _is_suppressed(original_rec):
                adjusted[target_id] = original_rec.duplicate(true)
            continue

        var preferred_source := str(_preferred_source_by_target.get(target_id, ""))
        var chosen: Dictionary = {}

        # An explicit player-selected alternative remains authoritative even when
        # its persistent history would normally keep it out of the default slot.
        if not preferred_source.is_empty():
            for raw_candidate in candidates:
                if not raw_candidate is Dictionary:
                    continue
                var candidate: Dictionary = raw_candidate
                if str(candidate.get("source_id", "")) == preferred_source and not _candidate_is_suppressed(candidate):
                    chosen = candidate
                    break

        if chosen.is_empty():
            var fallback: Dictionary = {}
            var first_soft_suppressed: Dictionary = {}

            for raw_candidate in candidates:
                if not raw_candidate is Dictionary:
                    continue
                var candidate: Dictionary = raw_candidate
                if _candidate_is_suppressed(candidate):
                    continue

                if fallback.is_empty():
                    fallback = candidate

                if _candidate_is_soft_suppressed(candidate):
                    if first_soft_suppressed.is_empty():
                        first_soft_suppressed = candidate
                    continue

                chosen = candidate
                break

            if chosen.is_empty() and not fallback.is_empty():
                chosen = fallback
                _log_default_suppression(target_id, first_soft_suppressed, chosen, true)
            elif not chosen.is_empty() and not first_soft_suppressed.is_empty():
                _log_default_suppression(target_id, first_soft_suppressed, chosen, false)
            else:
                _last_suppression_signature_by_target.erase(target_id)

        if chosen.is_empty():
            _preferred_source_by_target.erase(target_id)
            _last_suppression_signature_by_target.erase(target_id)
            continue

        _preferred_source_by_target[target_id] = str(chosen.get("source_id", ""))
        adjusted[target_id] = _recommendation_from_candidate(chosen)

    return adjusted


func _recommendation_from_candidate(candidate: Dictionary) -> Dictionary:
    var recommendation: Dictionary = super._recommendation_from_candidate(candidate)
    var preference: Dictionary = candidate.get("player_preference", {})
    var adjustment := float(preference.get("adjustment", 0.0))
    var suppression: Dictionary = candidate.get("recommendation_suppression", {})

    if abs(adjustment) > 0.01:
        var reasons: Array = recommendation.get("reasons", [])
        reasons.append("Your learned choices adjust this semantic route by %+.2f advisory point(s); legality and live Accept guards still take priority." % adjustment)
        recommendation["reasons"] = reasons

    if bool(suppression.get("soft_suppressed", false)):
        var reasons: Array = recommendation.get("reasons", [])
        reasons.append("Repeated negative feedback normally keeps this legal route out of the default suggestion slot; you can still inspect or choose it explicitly.")
        recommendation["reasons"] = reasons

    recommendation["player_preference"] = preference.duplicate(true)
    recommendation["recommendation_suppression"] = suppression.duplicate(true)
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
        print("%s Learned method='%s' key='%s' delta=%s after=%s persistent=%s" % [
            ADAPTIVE_LOG_PREFIX,
            method_name,
            result.get("semantic_key", ""),
            str(result.get("delta", 0.0)),
            str(result.get("after", 0.0)),
            str(result.get("persistent", false))
        ])


func _candidate_is_soft_suppressed(candidate: Dictionary) -> bool:
    var suppression: Dictionary = candidate.get("recommendation_suppression", {})
    return bool(suppression.get("soft_suppressed", false))


func _log_default_suppression(
    target_id: String,
    suppressed_candidate: Dictionary,
    chosen_candidate: Dictionary,
    fallback_used: bool
) -> void:
    if suppressed_candidate.is_empty():
        return

    var suppression: Dictionary = suppressed_candidate.get("recommendation_suppression", {})
    var signature := "%s|%s|%s|%s" % [
        str(suppressed_candidate.get("source_id", "")),
        str(chosen_candidate.get("source_id", "")),
        str(suppression.get("semantic_key", "")),
        str(fallback_used)
    ]

    if str(_last_suppression_signature_by_target.get(target_id, "")) == signature:
        return

    _last_suppression_signature_by_target[target_id] = signature
    print("%s Default target='%s' skipped_source='%s' chosen_source='%s' key='%s' adjustment=%s negative_events=%d fallback_used=%s legal_candidate_retained=true" % [
        SUPPRESSION_LOG_PREFIX,
        target_id,
        suppressed_candidate.get("source_id", ""),
        chosen_candidate.get("source_id", ""),
        suppression.get("semantic_key", ""),
        str(suppression.get("adjustment", 0.0)),
        int(suppression.get("negative_events", 0)),
        str(fallback_used)
    ])


func _snapshot_matches_recommendation(snapshot: Dictionary, recommendation: Dictionary) -> bool:
    return (
        str(snapshot.get("source_id", "")) == str(recommendation.get("source_id", ""))
        and str(snapshot.get("target_id", "")) == str(recommendation.get("target_id", ""))
        and str(snapshot.get("resource", "")) == str(recommendation.get("resource", ""))
    )
