extends Node

signal candidates_scored(scored_by_target: Dictionary, sample_index: int)

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Scoring]"
const EPSILON := 0.000001
const MAX_TARGETS_TO_LOG := 8
const MAX_RANKED_PER_TARGET_TO_LOG := 3

# Scores are relative advisory values, NOT percentages or promised throughput gains.
const VERIFIED_LEGALITY_SCORE := 50.0
const UNSERVED_TARGET_SCORE := 10.0
const ACTIVE_PRODUCTION_SCORE := 10.0
const IDLE_ACTIVE_SOURCE_SCORE := 10.0
const MAX_CAPACITY_HINT_SCORE := 10.0
const FANOUT_PENALTY_PER_OUTPUT := 2.0
const MAX_FANOUT_PENALTY := 10.0

var _scored_by_target: Dictionary = {}
var _last_ranking_signature := ""


func consume_candidates(candidates_by_target: Dictionary, sample_index: int) -> void:
    var next_scored: Dictionary = {}
    var total_candidates := 0
    var low_confidence := 0
    var medium_confidence := 0

    var target_ids := candidates_by_target.keys()
    target_ids.sort()

    for raw_target_id in target_ids:
        var target_id := str(raw_target_id)
        var raw_candidates = candidates_by_target[raw_target_id]
        var scored: Array[Dictionary] = []

        if raw_candidates is Array:
            for raw_candidate in raw_candidates:
                if not raw_candidate is Dictionary:
                    continue

                var record := _score_candidate(raw_candidate)
                scored.append(record)
                total_candidates += 1

                if str(record.get("confidence", "low")) == "medium":
                    medium_confidence += 1
                else:
                    low_confidence += 1

        scored.sort_custom(_sort_scored_candidates)
        next_scored[target_id] = scored

    _scored_by_target = next_scored
    _report_scores(sample_index, total_candidates, low_confidence, medium_confidence)
    candidates_scored.emit(_scored_by_target.duplicate(true), sample_index)


func get_scored_candidates() -> Dictionary:
    return _scored_by_target.duplicate(true)


func _score_candidate(candidate: Dictionary) -> Dictionary:
    var record: Dictionary = candidate.duplicate(true)
    var score := VERIFIED_LEGALITY_SCORE + UNSERVED_TARGET_SCORE
    var components := {
        "verified_legality": VERIFIED_LEGALITY_SCORE,
        "unserved_target": UNSERVED_TARGET_SCORE,
        "active_production": 0.0,
        "idle_active_source": 0.0,
        "capacity_hint": 0.0,
        "fanout_penalty": 0.0
    }

    var production = candidate.get("source_production", null)
    var required = candidate.get("target_required", null)
    var outputs := int(candidate.get("source_outputs", 0))
    var capacity_ratio = null

    if _is_positive(production):
        score += ACTIVE_PRODUCTION_SCORE
        components["active_production"] = ACTIVE_PRODUCTION_SCORE

        if outputs == 0:
            score += IDLE_ACTIVE_SOURCE_SCORE
            components["idle_active_source"] = IDLE_ACTIVE_SOURCE_SCORE

        if _is_positive(required):
            capacity_ratio = float(production) / float(required)
            var capacity_score := _capacity_hint_score(float(capacity_ratio))
            score += capacity_score
            components["capacity_hint"] = capacity_score

    var fanout_penalty: float = min(float(outputs) * FANOUT_PENALTY_PER_OUTPUT, MAX_FANOUT_PENALTY)
    score -= fanout_penalty
    components["fanout_penalty"] = -fanout_penalty

    record["advisory_score"] = clamp(score, 0.0, 100.0)
    record["score_components"] = components
    record["observed_capacity_ratio"] = capacity_ratio
    record["confidence"] = _confidence_for_candidate(production, required)
    record["score_semantics"] = "relative_advisory_not_percent"
    return record


func _capacity_hint_score(ratio: float) -> float:
    # The production/required relationship is intentionally low weight and capped.
    # Runtime tests have not yet proven it safe as a throughput estimate.
    if ratio >= 4.0:
        return MAX_CAPACITY_HINT_SCORE
    if ratio >= 2.0:
        return 8.0
    if ratio >= 1.0:
        return 6.0
    if ratio > EPSILON:
        return 3.0
    return 0.0


func _confidence_for_candidate(production, required) -> String:
    # Never emit "high" yet. Demand/capacity semantics remain under validation.
    if _is_positive(production) and _is_positive(required):
        return "medium"
    return "low"


func _report_scores(
    sample_index: int,
    total_candidates: int,
    low_confidence: int,
    medium_confidence: int
) -> void:
    print("%s Sample index=%d targets=%d scored_candidates=%d confidence_low=%d confidence_medium=%d" % [
        LOG_PREFIX,
        sample_index,
        _scored_by_target.size(),
        total_candidates,
        low_confidence,
        medium_confidence
    ])

    var signature_parts: Array[String] = []
    var target_ids := _scored_by_target.keys()
    target_ids.sort()

    for raw_target_id in target_ids:
        var target_id := str(raw_target_id)
        var candidates: Array = _scored_by_target[target_id]
        if candidates.is_empty():
            signature_parts.append("%s:none" % target_id)
            continue

        var top: Dictionary = candidates[0]
        signature_parts.append("%s:%s:%.2f" % [
            target_id,
            top.get("source_id", ""),
            float(top.get("advisory_score", 0.0))
        ])

    var signature := "|".join(signature_parts)
    if signature == _last_ranking_signature:
        return
    _last_ranking_signature = signature

    var logged_targets := 0
    for raw_target_id in target_ids:
        if logged_targets >= MAX_TARGETS_TO_LOG:
            break

        var target_id := str(raw_target_id)
        var candidates: Array = _scored_by_target[target_id]
        if candidates.is_empty():
            continue

        var top: Dictionary = candidates[0]
        print("%s   Target window='%s' container='%s' id='%s' resource='%s' candidates=%d top_score=%.2f confidence='%s'" % [
            LOG_PREFIX,
            top.get("target_window", ""),
            top.get("target_name", ""),
            target_id,
            top.get("resource", ""),
            candidates.size(),
            float(top.get("advisory_score", 0.0)),
            top.get("confidence", "low")
        ])

        var rank := 1
        for raw_candidate in candidates:
            if rank > MAX_RANKED_PER_TARGET_TO_LOG:
                break
            if not raw_candidate is Dictionary:
                continue

            var candidate: Dictionary = raw_candidate
            print("%s     Ranked rank=%d score=%.2f confidence='%s' source_window='%s' source_container='%s' source_id='%s' outputs=%d production=%s required=%s ratio=%s" % [
                LOG_PREFIX,
                rank,
                float(candidate.get("advisory_score", 0.0)),
                candidate.get("confidence", "low"),
                candidate.get("source_window", ""),
                candidate.get("source_name", ""),
                candidate.get("source_id", ""),
                int(candidate.get("source_outputs", 0)),
                str(candidate.get("source_production", null)),
                str(candidate.get("target_required", null)),
                str(candidate.get("observed_capacity_ratio", null))
            ])
            rank += 1

        logged_targets += 1


func _is_number(value) -> bool:
    return value is int or value is float


func _is_positive(value) -> bool:
    return _is_number(value) and float(value) > EPSILON


func _sort_scored_candidates(left: Dictionary, right: Dictionary) -> bool:
    var left_score := float(left.get("advisory_score", 0.0))
    var right_score := float(right.get("advisory_score", 0.0))

    if not is_equal_approx(left_score, right_score):
        return left_score > right_score

    var left_outputs := int(left.get("source_outputs", 0))
    var right_outputs := int(right.get("source_outputs", 0))
    if left_outputs != right_outputs:
        return left_outputs < right_outputs

    var left_window := str(left.get("source_window", ""))
    var right_window := str(right.get("source_window", ""))
    if left_window != right_window:
        return left_window < right_window

    return str(left.get("source_id", "")) < str(right.get("source_id", ""))
