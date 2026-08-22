extends Node

signal recommendations_updated(recommendations: Dictionary, sample_index: int)

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
    recommendations_updated.emit(_recommendations.duplicate(true), sample_index)


func get_recommendations() -> Dictionary:
    return _recommendations.duplicate(true)


func _build_recommendation(candidate: Dictionary) -> Dictionary:
    var reasons: Array[String] = []
    var resource := str(candidate.get("resource", ""))
    var outputs: int = int(candidate.get("source_outputs", 0))
    var production = candidate.get("source_production", null)
    var required = candidate.get("target_required", null)
    var ratio = candidate.get("observed_capacity_ratio", null)
    var selection_state := str(candidate.get("selection_state", "unique_top"))
    var tied_top_count: int = int(candidate.get("top_tie_count", 1))
    var score_gap = candidate.get("score_gap_to_next", null)
    var route_preservation: Dictionary = candidate.get("route_preservation", {})
    var manager_metrics: Dictionary = candidate.get("trusted_manager_metrics", {})

    reasons.append("The game reports this source-target pair as connectable for '%s'." % resource)
    reasons.append("The target is currently unserved, so this proposal does not replace an existing player input route.")

    if outputs == 0:
        reasons.append("The source currently has no output routes, so adding this route does not increase sharing on an existing player path.")
    elif outputs == 1:
        reasons.append("The source currently serves 1 output route; the advisory score applies a small route-sharing penalty to preserve existing player paths where possible.")
    else:
        reasons.append("The source currently serves %d output routes; the advisory score applies a stronger nonlinear sharing penalty so heavily shared sources do not win by default." % outputs)

    if _is_positive(production):
        reasons.append("The source currently reports positive production; this increases confidence that it is active.")
        if _is_positive(required) and _is_number(ratio):
            reasons.append("Observed production/required ratio is %.3fx and is used only as a capped provisional capacity hint." % float(ratio))
    else:
        reasons.append("No positive source production was observed in this sample, so general capacity confidence remains limited.")

    if bool(manager_metrics.get("trusted", false)):
        var manager_status := str(manager_metrics.get("status", "unavailable"))
        var manager_ratio = manager_metrics.get("supply_to_demand_ratio", null)
        if _is_number(manager_ratio):
            reasons.append("Known Smart Manager current supply/demand is %.3fx with status '%s'. v0.1.15 records this for validation only; current-load manager headroom contributes 0 advisory points until projected post-connect demand is runtime-verified." % [float(manager_ratio), manager_status])
        else:
            reasons.append("This is a known Smart Manager source, but its current supply/demand values were unavailable; manager headroom contributes 0 advisory points.")

    if selection_state == "tied_top" and tied_top_count > 1:
        reasons.append("%d candidates share the same top advisory score. This source is listed first only by deterministic tie-breaking, not because it is proven better than the tied alternatives." % tied_top_count)
    elif _is_number(score_gap):
        reasons.append("This candidate leads the next distinct score by %.2f advisory point(s); that gap is relative ranking evidence, not a throughput percentage." % float(score_gap))

    reasons.append("The advisory score is relative, not a percentage improvement or guaranteed throughput gain.")
    reasons.append("Player intent remains authoritative; topology changes occur only after explicit Accept and live guard revalidation.")

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
        "selection_state": selection_state,
        "top_tie_count": tied_top_count,
        "score_gap_to_next": score_gap,
        "route_preservation": route_preservation,
        "trusted_manager_metrics": manager_metrics,
        "reasons": reasons,
        "safety": "explicit_accept_required_guarded"
    }


func _report_recommendations(sample_index: int) -> void:
    var unique_top := 0
    var tied_top := 0

    for raw_recommendation in _recommendations.values():
        if not raw_recommendation is Dictionary:
            continue
        var recommendation: Dictionary = raw_recommendation
        if str(recommendation.get("selection_state", "unique_top")) == "tied_top":
            tied_top += 1
        else:
            unique_top += 1

    print("%s Sample index=%d recommendations=%d unique_top=%d tied_top=%d mode='player_controlled_advisory'" % [
        LOG_PREFIX,
        sample_index,
        _recommendations.size(),
        unique_top,
        tied_top
    ])

    var target_ids := _recommendations.keys()
    target_ids.sort()

    var signature_parts: Array[String] = []
    for raw_target_id in target_ids:
        var recommendation: Dictionary = _recommendations[raw_target_id]
        signature_parts.append("%s:%s:%.2f:%s:%s:%d" % [
            str(raw_target_id),
            recommendation.get("source_id", ""),
            float(recommendation.get("advisory_score", 0.0)),
            recommendation.get("confidence", "low"),
            recommendation.get("selection_state", "unique_top"),
            int(recommendation.get("top_tie_count", 1))
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
        print("%s   Suggest target='%s/%s' <- source='%s/%s' resource='%s' score=%.2f confidence='%s' selection='%s' tied_top=%d gap=%s" % [
            LOG_PREFIX,
            recommendation.get("target_window", ""),
            recommendation.get("target_name", ""),
            recommendation.get("source_window", ""),
            recommendation.get("source_name", ""),
            recommendation.get("resource", ""),
            float(recommendation.get("advisory_score", 0.0)),
            recommendation.get("confidence", "low"),
            recommendation.get("selection_state", "unique_top"),
            int(recommendation.get("top_tie_count", 1)),
            str(recommendation.get("score_gap_to_next", null))
        ])

        var reasons: Array = recommendation.get("reasons", [])
        for reason in reasons:
            print("%s     Why: %s" % [LOG_PREFIX, str(reason)])

        logged += 1


func _is_number(value) -> bool:
    return value is int or value is float


func _is_positive(value) -> bool:
    return _is_number(value) and float(value) > 0.000001
