extends "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/candidate_scorer.gd"

const PREFERENCE_SCORE_MIN := -8.0
const PREFERENCE_SCORE_MAX := 8.0
const FINAL_SCORE_CAP := 90.0
const SOFT_SUPPRESSION_SCORE_THRESHOLD := -5.0
const SOFT_SUPPRESSION_NEGATIVE_EVENTS_REQUIRED := 2
const NEGATIVE_EVENT_NAMES := ["alternate", "no_thanks", "undo"]

var _preference_model: Node = null


func set_preference_model(model: Node) -> void:
    _preference_model = model


func _score_candidate(candidate: Dictionary) -> Dictionary:
    var record: Dictionary = super._score_candidate(candidate)
    var base_score := float(record.get("advisory_score", 0.0))
    var preference := {
        "semantic_key": "",
        "adjustment": 0.0,
        "events": {},
        "session_only": true
    }

    if is_instance_valid(_preference_model) and _preference_model.has_method("get_candidate_preference"):
        var raw_preference = _preference_model.call("get_candidate_preference", candidate)
        if raw_preference is Dictionary:
            preference = raw_preference

    var adjustment: float = clampf(
        float(preference.get("adjustment", 0.0)),
        PREFERENCE_SCORE_MIN,
        PREFERENCE_SCORE_MAX
    )

    var components: Dictionary = record.get("score_components", {})
    components["player_preference"] = adjustment
    record["score_components"] = components
    record["base_advisory_score"] = base_score
    record["player_preference"] = preference.duplicate(true)
    record["recommendation_suppression"] = _suppression_metadata(preference, adjustment)
    record["advisory_score"] = clampf(base_score + adjustment, 0.0, FINAL_SCORE_CAP)
    return record


func _suppression_metadata(preference: Dictionary, adjustment: float) -> Dictionary:
    var events: Dictionary = preference.get("events", {})
    var negative_events := 0

    for event_name in NEGATIVE_EVENT_NAMES:
        negative_events += maxi(0, int(events.get(event_name, 0)))

    var soft_suppressed := (
        adjustment <= SOFT_SUPPRESSION_SCORE_THRESHOLD
        and negative_events >= SOFT_SUPPRESSION_NEGATIVE_EVENTS_REQUIRED
    )

    return {
        "soft_suppressed": soft_suppressed,
        "reason": "repeated_negative_preference" if soft_suppressed else "none",
        "semantic_key": str(preference.get("semantic_key", "")),
        "adjustment": adjustment,
        "negative_events": negative_events,
        "score_threshold": SOFT_SUPPRESSION_SCORE_THRESHOLD,
        "required_negative_events": SOFT_SUPPRESSION_NEGATIVE_EVENTS_REQUIRED,
        "default_slot_only": true,
        "legal_candidate_retained": true
    }
