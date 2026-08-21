extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Explain]"
const MAX_RECOMMENDATIONS_TO_LOG := 8

var _recommendations: Dictionary = {}
var _last_recommendation_signature := ""


func consume_scored_candidates(scored_by_target: Dictionary, sample_index: int) -> void:
    var next_recommendations: Dictionary = {}

    var target_ids := scored_by_target.keys()
    target_ids.sort()

    for raw_target_id in target_ids:
        var target_id := str(raw_target_id)
        var candidates = scored_by_target[raw_target_id]
        if not candidates is Array or candidates.is_empty():
            continue

        var top = candidates[0]
        if not top is Dictionary:
            continue

        next_recommendations[target_id] = _build_recommendation(top)

    _recommendations = next_recommendations
    _report_recommendations(sample_index)


func get_recommendations() -> Dictionary:
    return _recommendations.duplicate(true)


func _build_recommendation(candidate: Dictionary) -> Dictionary:
    var reasons: Array[String] = []
    var resource := str(candidate.get("resource", ""))
    var outputs := int(candidate.get("source_outputs", 0))
    var production = candidate.get("source_production", null)
    var required = candidate.get("target_required", null)
    var ratio = candidate.get("observed_capacity_ratio", null)

    reasons.append("The game reports this source-target pair as connectable for '%s'." % resource)
    reasons.append("The target is currently unserved, so this proposal does not replace an existing input route.")

    if outputs == 0:
        reasons.append("The source currently has no output routes, so it receives no fan-out penalty.")
    else:
        reasons.append("The source currently serves %d output route(s); the advisory score applies a small fan-out penalty." % outputs)

    if _is_positive(production):
        reasons.append("The source currently reports positive production; this increases confidence that it is active.")
        if _is_positive(required) and _is_number(ratio):
            reasons.append("Observed production/required ratio is %.3fx and is used only as a capped provisional capacity hint." % float(ratio))
    else:
        reasons.append("No positive source production was observed in this sample, so capacity confidence remains limited.")

    reasons.append("The advisory score is relative, not a percentage improvement or guaranteed throughput gain.")

    return {
        "target_id": str(candidate.get("target_id", "")),
        "target_window": str(candidate.get("target_window", "")),
        "target_name": str(candidate.get("target_name", "")),
        "source_id": str(candidate.get("source_id", "")),
        "source_window": str(candidate.get("source_window", "")),
        "source_name": str(candidate.get("source_name", "")),
        "resource": resource,
        "advisory_score": float(candidate.get("advisory_score", 0.0)),
        "confidence": str(candidate.get("confidence", "low")),
        "reasons": reasons,
        "safety": "read_only_no_connection_change"
    }


func _report_recommendations(sample_index: int) -> void:
    print("%s Sample index=%d recommendations=%d mode='read_only'" % [
        LOG_PREFIX,
        sample_index,
        _recommendations.size()
    ])

    var target_ids := _recommendations.keys()
    target_ids.sort()

    var signature_parts: Array[String] = []
    for raw_target_id in target_ids:
        var recommendation: Dictionary = _recommendations[raw_target_id]
        signature_parts.append("%s:%s:%.2f:%s" % [
            str(raw_target_id),
            recommendation.get("source_id", ""),
            float(recommendation.get("advisory_score", 0.0)),
            recommendation.get("confidence", "low")
        ])
    var signature := "|".join(signature_parts)
    if signature == _last_recommendation_signature:
        return
    _last_recommendation_signature = signature

    var logged := 0

    for raw_target_id in target_ids:
        if logged >= MAX_RECOMMENDATIONS_TO_LOG:
            break

        var recommendation: Dictionary = _recommendations[raw_target_id]
        print("%s   Suggest target='%s/%s' <- source='%s/%s' resource='%s' score=%.2f confidence='%s'" % [
            LOG_PREFIX,
            recommendation.get("target_window", ""),
            recommendation.get("target_name", ""),
            recommendation.get("source_window", ""),
            recommendation.get("source_name", ""),
            recommendation.get("resource", ""),
            float(recommendation.get("advisory_score", 0.0)),
            recommendation.get("confidence", "low")
        ])

        var reasons: Array = recommendation.get("reasons", [])
        for reason in reasons:
            print("%s     Why: %s" % [LOG_PREFIX, str(reason)])

        logged += 1


func _is_number(value) -> bool:
    return value is int or value is float


func _is_positive(value) -> bool:
    return _is_number(value) and float(value) > 0.000001
