extends Node

signal candidates_scored(scored_by_target: Dictionary, sample_index: int)

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Scoring]"
const EPSILON := 0.000001
const SCORE_TIE_EPSILON := 0.01
const MAX_TARGETS_TO_LOG := 8
const MAX_RANKED_PER_TARGET_TO_LOG := 3

# Scores are relative advisory values, NOT percentages or promised throughput gains.
const VERIFIED_LEGALITY_SCORE := 50.0
const UNSERVED_TARGET_SCORE := 10.0
const ACTIVE_PRODUCTION_SCORE := 10.0
const IDLE_ACTIVE_SOURCE_SCORE := 8.0
const MAX_CAPACITY_HINT_SCORE := 8.0
const MAX_ADVISORY_SCORE := 90.0

# These thresholds describe the legacy current-load manager adjustment only. v0.1.15
# records what that adjustment would have been, but applies 0 until projected
# post-connect demand is runtime-validated.
const TRUSTED_MANAGER_HEADROOM_BONUS := 4.0
const TRUSTED_MANAGER_PRESSURE_PENALTY := 4.0

var _scored_by_target: Dictionary = {}
var _last_ranking_signature := ""
var _candidate_provider: Node = null
var _sample_index := 0


func set_candidate_provider(provider: Node) -> void:
    _candidate_provider = provider


func consume_resource_sample(_sample: Dictionary) -> void:
    if not is_instance_valid(_candidate_provider):
        return
    if not _candidate_provider.has_method("get_candidates"):
        return

    var raw_candidates = _candidate_provider.call("get_candidates")
    if not raw_candidates is Dictionary:
        return

    _sample_index += 1
    consume_candidates(raw_candidates, _sample_index)


func consume_candidates(candidates_by_target: Dictionary, sample_index: int) -> void:
    var next_scored: Dictionary = {}
    var total_candidates := 0
    var low_confidence := 0
    var medium_confidence := 0
    var unique_top_targets := 0
    var tied_top_targets := 0

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

                var record: Dictionary = _score_candidate(raw_candidate)
                scored.append(record)
                total_candidates += 1

                if str(record.get("confidence", "low")) == "medium":
                    medium_confidence += 1
                else:
                    low_confidence += 1

        scored.sort_custom(_sort_scored_candidates)
        _annotate_selection_context(scored)

        if not scored.is_empty():
            var top: Dictionary = scored[0]
            if str(top.get("selection_state", "unique_top")) == "tied_top":
                tied_top_targets += 1
            else:
                unique_top_targets += 1

        next_scored[target_id] = scored

    _scored_by_target = next_scored
    _report_scores(
        sample_index,
        total_candidates,
        low_confidence,
        medium_confidence,
        unique_top_targets,
        tied_top_targets
    )
    candidates_scored.emit(_scored_by_target.duplicate(true), sample_index)


func get_scored_candidates() -> Dictionary:
    return _scored_by_target.duplicate(true)


func _score_candidate(candidate: Dictionary) -> Dictionary:
    var record: Dictionary = candidate.duplicate(true)
    var score: float = VERIFIED_LEGALITY_SCORE + UNSERVED_TARGET_SCORE
    var components := {
        "verified_legality": VERIFIED_LEGALITY_SCORE,
        "unserved_target": UNSERVED_TARGET_SCORE,
        "active_production": 0.0,
        "idle_active_source": 0.0,
        "capacity_hint": 0.0,
        "shared_route_penalty": 0.0,
        "trusted_manager_headroom": 0.0
    }

    var production = candidate.get("source_production", null)
    var required = candidate.get("target_required", null)
    var outputs: int = int(candidate.get("source_outputs", 0))
    var capacity_ratio = null

    if _is_positive(production):
        score += ACTIVE_PRODUCTION_SCORE
        components["active_production"] = ACTIVE_PRODUCTION_SCORE

        if outputs == 0:
            score += IDLE_ACTIVE_SOURCE_SCORE
            components["idle_active_source"] = IDLE_ACTIVE_SOURCE_SCORE

        if _is_positive(required):
            capacity_ratio = float(production) / float(required)
            var capacity_score: float = _capacity_hint_score(float(capacity_ratio))
            score += capacity_score
            components["capacity_hint"] = capacity_score

    var shared_route_penalty: float = _shared_route_penalty(outputs)
    score -= shared_route_penalty
    components["shared_route_penalty"] = -shared_route_penalty

    var manager_metrics: Dictionary = _trusted_manager_metrics(record)
    var manager_adjustment: float = float(manager_metrics.get("score_adjustment", 0.0))
    score += manager_adjustment
    components["trusted_manager_headroom"] = manager_adjustment

    record["advisory_score"] = clamp(score, 0.0, MAX_ADVISORY_SCORE)
    record["score_components"] = components
    record["observed_capacity_ratio"] = capacity_ratio
    record["confidence"] = _confidence_for_candidate(production, required, manager_metrics)
    record["score_semantics"] = "relative_advisory_not_percent"
    record["route_preservation"] = {
        "target_route_replaced": false,
        "source_existing_routes": outputs,
        "shared_route_penalty": shared_route_penalty
    }
    record["trusted_manager_metrics"] = manager_metrics
    return record


func _shared_route_penalty(outputs: int) -> float:
    if outputs <= 0:
        return 0.0
    if outputs == 1:
        return 2.0
    if outputs == 2:
        return 4.0
    if outputs == 3:
        return 7.0
    if outputs <= 5:
        return 9.0
    return 12.0


func _capacity_hint_score(ratio: float) -> float:
    # The production/required relationship is intentionally low weight and capped.
    # v0.1.15 validates how this ratio participates in Smart Manager demand, but
    # does not yet promote it to a general throughput guarantee.
    if ratio >= 4.0:
        return MAX_CAPACITY_HINT_SCORE
    if ratio >= 2.0:
        return 6.0
    if ratio >= 1.0:
        return 4.0
    if ratio > EPSILON:
        return 2.0
    return 0.0


func _trusted_manager_metrics(candidate: Dictionary) -> Dictionary:
    var kind: String = _trusted_manager_kind(candidate)
    if kind.is_empty():
        return {
            "trusted": false,
            "kind": "",
            "count": null,
            "demand": null,
            "supply_to_demand_ratio": null,
            "status": "not_applicable",
            "score_adjustment": 0.0,
            "diagnostic_current_load_adjustment": 0.0,
            "validation_mode": "not_applicable"
        }

    var source_id := str(candidate.get("source_id", ""))
    if source_id.is_empty() or not is_instance_valid(Globals.desktop):
        return _manager_metrics_unavailable(kind)
    if not Globals.desktop.has_method("get_resource"):
        return _manager_metrics_unavailable(kind)

    var source = Globals.desktop.call("get_resource", source_id)
    if not is_instance_valid(source):
        return _manager_metrics_unavailable(kind)

    var count = _read_numeric_property(source, "count")
    var demand = _read_numeric_property(source, "demand")
    if not _is_number(count) or not _is_number(demand):
        return _manager_metrics_unavailable(kind)

    var ratio = null
    var status := "idle_or_zero_demand"
    var legacy_adjustment := 0.0

    if float(demand) > EPSILON:
        ratio = float(count) / float(demand)
        if float(ratio) >= 1.5:
            status = "headroom"
            legacy_adjustment = TRUSTED_MANAGER_HEADROOM_BONUS
        elif float(ratio) >= 1.0:
            status = "meeting_current_demand"
            legacy_adjustment = TRUSTED_MANAGER_HEADROOM_BONUS * 0.5
        elif float(ratio) >= 0.75:
            status = "near_pressure"
            legacy_adjustment = -TRUSTED_MANAGER_PRESSURE_PENALTY * 0.5
        else:
            status = "under_current_demand"
            legacy_adjustment = -TRUSTED_MANAGER_PRESSURE_PENALTY

    return {
        "trusted": true,
        "kind": kind,
        "count": float(count),
        "demand": float(demand),
        "supply_to_demand_ratio": ratio,
        "status": status,
        "score_adjustment": 0.0,
        "diagnostic_current_load_adjustment": legacy_adjustment,
        "validation_mode": "diagnostic_only_until_projected_post_connect_demand_is_verified",
        "semantics": "current_supply_vs_current_bound_demand_not_prospective"
    }


func _trusted_manager_kind(candidate: Dictionary) -> String:
    var window_name := str(candidate.get("source_window", "")).to_lower()
    var resource := str(candidate.get("resource", "")).to_lower()

    if window_name.begins_with("smart_thread_manager") and resource == "clock_speed":
        return "smart_thread_manager"
    if window_name.begins_with("smart_gpu_manager") and resource == "gpu_speed":
        return "smart_gpu_manager"
    return ""


func _manager_metrics_unavailable(kind: String) -> Dictionary:
    return {
        "trusted": true,
        "kind": kind,
        "count": null,
        "demand": null,
        "supply_to_demand_ratio": null,
        "status": "unavailable",
        "score_adjustment": 0.0,
        "diagnostic_current_load_adjustment": 0.0,
        "validation_mode": "diagnostic_only_until_projected_post_connect_demand_is_verified",
        "semantics": "known_manager_metric_unavailable_this_sample"
    }


func _read_numeric_property(object: Object, property_name: String):
    if not is_instance_valid(object) or not property_name in object:
        return null

    var value = object.get(property_name)
    if value is int or value is float:
        return float(value)
    return null


func _confidence_for_candidate(production, required, manager_metrics: Dictionary) -> String:
    # Never emit "high" yet. General production/required semantics remain provisional.
    if _is_positive(production) and _is_positive(required):
        return "medium"

    # Smart Manager current-load ratios do not raise candidate confidence in v0.1.15.
    # The proposed target's incremental demand must be validated first.
    if bool(manager_metrics.get("trusted", false)):
        return "low"

    return "low"


func _annotate_selection_context(scored: Array[Dictionary]) -> void:
    if scored.is_empty():
        return

    var top_score: float = float(scored[0].get("advisory_score", 0.0))
    var tied_top_count := 0
    var next_distinct_score = null

    for candidate in scored:
        var candidate_score: float = float(candidate.get("advisory_score", 0.0))
        if abs(candidate_score - top_score) <= SCORE_TIE_EPSILON:
            tied_top_count += 1
        else:
            next_distinct_score = candidate_score
            break

    var score_gap_to_next = null
    if _is_number(next_distinct_score):
        score_gap_to_next = top_score - float(next_distinct_score)

    for index in range(scored.size()):
        var record: Dictionary = scored[index]
        record["rank_position"] = index + 1
        if index < tied_top_count:
            record["top_tie_count"] = tied_top_count
            record["selection_state"] = "tied_top" if tied_top_count > 1 else "unique_top"
            record["score_gap_to_next"] = score_gap_to_next
        else:
            record["top_tie_count"] = tied_top_count
            record["selection_state"] = "not_top"
            record["score_gap_to_next"] = null


func _report_scores(
    sample_index: int,
    total_candidates: int,
    low_confidence: int,
    medium_confidence: int,
    unique_top_targets: int,
    tied_top_targets: int
) -> void:
    print("%s Sample index=%d targets=%d scored_candidates=%d confidence_low=%d confidence_medium=%d unique_top=%d tied_top=%d" % [
        LOG_PREFIX,
        sample_index,
        _scored_by_target.size(),
        total_candidates,
        low_confidence,
        medium_confidence,
        unique_top_targets,
        tied_top_targets
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
        signature_parts.append("%s:%s:%.2f:%s:%d" % [
            target_id,
            top.get("source_id", ""),
            float(top.get("advisory_score", 0.0)),
            top.get("selection_state", "unique_top"),
            int(top.get("top_tie_count", 1))
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
        print("%s   Target window='%s' container='%s' id='%s' resource='%s' candidates=%d top_score=%.2f confidence='%s' selection='%s' tied_top=%d gap=%s" % [
            LOG_PREFIX,
            top.get("target_window", ""),
            top.get("target_name", ""),
            target_id,
            top.get("resource", ""),
            candidates.size(),
            float(top.get("advisory_score", 0.0)),
            top.get("confidence", "low"),
            top.get("selection_state", "unique_top"),
            int(top.get("top_tie_count", 1)),
            str(top.get("score_gap_to_next", null))
        ])

        var rank := 1
        for raw_candidate in candidates:
            if rank > MAX_RANKED_PER_TARGET_TO_LOG:
                break
            if not raw_candidate is Dictionary:
                continue

            var candidate: Dictionary = raw_candidate
            var manager_metrics: Dictionary = candidate.get("trusted_manager_metrics", {})
            print("%s     Ranked rank=%d score=%.2f confidence='%s' source_window='%s' source_container='%s' source_id='%s' outputs=%d production=%s required=%s ratio=%s manager_status='%s' manager_ratio=%s manager_score_applied=%s manager_current_load_diagnostic=%s" % [
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
                str(candidate.get("observed_capacity_ratio", null)),
                manager_metrics.get("status", "not_applicable"),
                str(manager_metrics.get("supply_to_demand_ratio", null)),
                str(manager_metrics.get("score_adjustment", 0.0)),
                str(manager_metrics.get("diagnostic_current_load_adjustment", 0.0))
            ])
            rank += 1

        logged_targets += 1


func _is_number(value) -> bool:
    return value is int or value is float


func _is_positive(value) -> bool:
    return _is_number(value) and float(value) > EPSILON


func _sort_scored_candidates(left: Dictionary, right: Dictionary) -> bool:
    var left_score: float = float(left.get("advisory_score", 0.0))
    var right_score: float = float(right.get("advisory_score", 0.0))

    if not is_equal_approx(left_score, right_score):
        return left_score > right_score

    var left_outputs: int = int(left.get("source_outputs", 0))
    var right_outputs: int = int(right.get("source_outputs", 0))
    if left_outputs != right_outputs:
        return left_outputs < right_outputs

    var left_window := str(left.get("source_window", ""))
    var right_window := str(right.get("source_window", ""))
    if left_window != right_window:
        return left_window < right_window

    return str(left.get("source_id", "")) < str(right.get("source_id", ""))