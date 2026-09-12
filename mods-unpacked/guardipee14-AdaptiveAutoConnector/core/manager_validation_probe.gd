extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][ManagerValidation]"
const EPSILON := 0.000001
const ABS_TOLERANCE := 0.01
const REL_TOLERANCE := 0.02
const MAX_BOUND_WINDOWS_TO_LOG := 6
const MAX_PROJECTIONS_TO_LOG := 12

var _resource_sample_index := 0
var _last_manager_signature := ""
var _last_projection_signature := ""


func consume_resource_sample(sample: Dictionary) -> void:
    _resource_sample_index += 1

    var containers: Dictionary = sample.get("containers", {})
    var managers: Array[Dictionary] = []

    for raw_id in containers.keys():
        var container_id := str(raw_id)
        var sample_record = containers[raw_id]
        if not sample_record is Dictionary:
            continue

        var record: Dictionary = sample_record
        var kind := _manager_kind(
            str(record.get("window_name", "")),
            str(record.get("resource", ""))
        )
        if kind.is_empty():
            continue

        # ASM exposes both its SmartResourceContainer and a generic input
        # ResourceContainer with the same manager window/resource identity.
        # Only the SmartResourceContainer owns window_binds/demand semantics.
        var live_source = _live_resource(container_id)
        if not is_instance_valid(live_source):
            continue
        if not "window_binds" in live_source:
            continue

        managers.append(_build_manager_record(kind, container_id, record))

    managers.sort_custom(_sort_manager_records)
    _report_manager_sample(managers)


func consume_scored_candidates(scored_by_target: Dictionary, sample_index: int) -> void:
    var projections: Array[Dictionary] = []
    var target_ids := scored_by_target.keys()
    target_ids.sort()

    for raw_target_id in target_ids:
        var raw_candidates = scored_by_target[raw_target_id]
        if not raw_candidates is Array:
            continue

        for raw_candidate in raw_candidates:
            if not raw_candidate is Dictionary:
                continue

            var candidate: Dictionary = raw_candidate
            var kind := _manager_kind(
                str(candidate.get("source_window", "")),
                str(candidate.get("resource", ""))
            )
            if kind.is_empty():
                continue

            projections.append(_build_candidate_projection(kind, candidate))

    projections.sort_custom(_sort_projection_records)
    _report_projection_sample(projections, sample_index)


func get_projected_manager_metrics(candidate: Dictionary) -> Dictionary:
    var kind := _manager_kind(
        str(candidate.get("source_window", "")),
        str(candidate.get("resource", ""))
    )

    var unavailable := {
        "available": false,
        "trusted": not kind.is_empty(),
        "kind": kind,
        "status": "unavailable",
        "score_adjustment": 0.0,
        "validation_mode": "projected_headroom_unavailable",
        "semantics": "no_score_without_runtime_validated_projection"
    }

    if kind.is_empty():
        return unavailable

    var source_id := str(candidate.get("source_id", ""))
    if source_id.is_empty():
        unavailable["status"] = "missing_source_id"
        return unavailable

    var manager_state := _build_manager_record(
        kind,
        source_id,
        {
            "window_name": str(candidate.get("source_window", "")),
            "resource": str(candidate.get("resource", ""))
        }
    )

    var raw_validation_ok: bool = (
        str(manager_state.get("raw_mirror_match", "unavailable")) == "match"
        and int(manager_state.get("reprojection_mismatches", 0)) == 0
        and int(manager_state.get("reprojection_unavailable", 0)) == 0
        and int(manager_state.get("bound_windows", 0)) > 0
    )

    if not raw_validation_ok:
        unavailable["status"] = "manager_raw_validation_failed"
        unavailable["raw_mirror_match"] = manager_state.get(
            "raw_mirror_match",
            "unavailable"
        )
        unavailable["reprojection_mismatches"] = int(
            manager_state.get("reprojection_mismatches", 0)
        )
        unavailable["reprojection_unavailable"] = int(
            manager_state.get("reprojection_unavailable", 0)
        )
        return unavailable

    var projection := _build_candidate_projection(kind, candidate)
    var projected_ratio = projection.get("projected_ratio", null)
    var target_demand = projection.get("projected_target_demand", null)
    var conservative_baseline = projection.get("conservative_baseline", null)

    if (
        not _is_number(projected_ratio)
        or not _is_number(target_demand)
        or not _is_number(conservative_baseline)
    ):
        unavailable["status"] = "projection_unavailable"
        return unavailable

    var ratio := float(projected_ratio)
    var adjustment := _diagnostic_headroom_adjustment(ratio)

    return {
        "available": true,
        "trusted": true,
        "kind": kind,
        "status": _projected_headroom_status(ratio),
        "score_adjustment": adjustment,
        "count": projection.get("current_count", null),
        "live_demand": projection.get("current_demand", null),
        "raw_bound_demand": projection.get("raw_bound_demand", null),
        "conservative_baseline": conservative_baseline,
        "projected_target_demand": target_demand,
        "projected_total_demand": projection.get(
            "projected_total_demand",
            null
        ),
        "projected_ratio": ratio,
        "basis": projection.get("basis", "count_per_second"),
        "baseline_policy": projection.get(
            "baseline_policy",
            "max_live_and_raw_bound_demand"
        ),
        "already_bound_window": bool(
            projection.get("already_bound_window", false)
        ),
        "raw_mirror_match": manager_state.get(
            "raw_mirror_match",
            "unavailable"
        ),
        "reprojection_matches": int(
            manager_state.get("reprojection_matches", 0)
        ),
        "reprojection_mismatches": int(
            manager_state.get("reprojection_mismatches", 0)
        ),
        "reprojection_unavailable": int(
            manager_state.get("reprojection_unavailable", 0)
        ),
        "validation_mode": "runtime_validated_projected_headroom",
        "semantics": "projected_post_connect_supply_over_conservative_demand"
    }


func _build_manager_record(kind: String, source_id: String, sample_record: Dictionary) -> Dictionary:
    var result := {
        "kind": kind,
        "source_id": source_id,
        "source_window": str(sample_record.get("window_name", "")),
        "resource": str(sample_record.get("resource", "")),
        "count": null,
        "demand": null,
        "current_ratio": null,
        "use_count": false,
        "basis": "count_per_second",
        "distribution_mode": null,
        "bound_windows": 0,
        "binding_demand_sum": null,
        "mirror_demand_sum": null,
        "binding_match": "unavailable",
        "mirror_match": "unavailable",
        "raw_mirror_match": "unavailable",
        "live_state_semantics": "unknown",
        "raw_supply_to_demand_ratio": null,
        "conservative_demand": null,
        "conservative_ratio": null,
        "synthetic_increment_demand": null,
        "synthetic_projected_total": null,
        "synthetic_projected_ratio": null,
        "synthetic_adjustment": 0.0,
        "reprojection_matches": 0,
        "reprojection_mismatches": 0,
        "reprojection_unavailable": 0,
        "live_reprojection_matches": 0,
        "live_reprojection_mismatches": 0,
        "bindings": []
    }

    var source = _live_resource(source_id)
    if not is_instance_valid(source):
        return result

    var count = _read_numeric_property(source, "count")
    var demand = _read_numeric_property(source, "demand")
    var use_count := false
    if "use_count" in source:
        use_count = bool(source.get("use_count"))
    var distribution_mode = source.get("distribution_mode") if "distribution_mode" in source else null

    result["count"] = count
    result["demand"] = demand
    result["use_count"] = use_count
    result["basis"] = "count" if use_count else "count_per_second"
    result["distribution_mode"] = distribution_mode
    if _is_number(count) and _is_number(demand) and float(demand) > EPSILON:
        result["current_ratio"] = float(count) / float(demand)

    if not "window_binds" in source:
        return result

    var raw_binds = source.get("window_binds")
    if not raw_binds is Dictionary:
        return result

    var binds: Dictionary = raw_binds
    result["bound_windows"] = binds.size()

    var binding_sum := 0.0
    var mirror_sum := 0.0
    var binding_sum_available := true
    var mirror_sum_available := true
    var details: Array[Dictionary] = []

    for raw_binding in binds.values():
        if not is_instance_valid(raw_binding):
            binding_sum_available = false
            mirror_sum_available = false
            continue

        var binding: Object = raw_binding
        var window = binding.get("window") if "window" in binding else null
        var own_sources = binding.get("own_sources") if "own_sources" in binding else []
        var binding_demand = null
        var demand_method := "get_count_demand" if use_count else "get_demand"
        if binding.has_method(demand_method):
            var raw_demand = binding.call(demand_method)
            if _is_number(raw_demand):
                binding_demand = float(raw_demand)
                binding_sum += float(raw_demand)
            else:
                binding_sum_available = false
        else:
            binding_sum_available = false

        var mirror: Dictionary = _mirror_window_demand(window, own_sources, use_count)
        if bool(mirror.get("available", false)):
            mirror_sum += float(mirror.get("demand", 0.0))
        else:
            mirror_sum_available = false

        details.append({
            "window": str(window.name) if is_instance_valid(window) else "",
            "basis": "count" if use_count else "count_per_second",
            "binding_demand": binding_demand,
            "mirror_demand": mirror.get("demand", null),
            "goal": mirror.get("goal", null),
            "min_input_ratio": mirror.get("min_input_ratio", null),
            "input_count": int(mirror.get("input_count", 0)),
            "own_source_count": _array_size(own_sources)
        })

    details.sort_custom(_sort_binding_records)
    result["bindings"] = details

    if binding_sum_available:
        result["binding_demand_sum"] = binding_sum
    if mirror_sum_available:
        result["mirror_demand_sum"] = mirror_sum

    if _is_number(demand) and binding_sum_available:
        result["binding_match"] = "match" if _approximately_equal(float(demand), binding_sum) else "mismatch"
    if _is_number(demand) and mirror_sum_available:
        result["mirror_match"] = "match" if _approximately_equal(float(demand), mirror_sum) else "mismatch"
    if binding_sum_available and mirror_sum_available:
        result["raw_mirror_match"] = (
            "match" if _approximately_equal(binding_sum, mirror_sum) else "mismatch"
        )

    # ASM Demand and Graph modes intentionally smooth/transform state.demand.
    # A fresh binding sum is therefore not required to equal source.demand in
    # those modes. Ratio mode uses the raw demand sum directly.
    var mode_value := int(distribution_mode) if _is_number(distribution_mode) else -1
    result["live_state_semantics"] = (
        "raw_sum_expected"
        if mode_value == 0
        else "smoothed_or_effective_state"
    )

    if _is_number(count) and binding_sum_available and binding_sum > EPSILON:
        result["raw_supply_to_demand_ratio"] = float(count) / binding_sum

    var conservative_demand = null
    if _is_number(demand) and binding_sum_available:
        conservative_demand = maxf(float(demand), binding_sum)
    elif binding_sum_available:
        conservative_demand = binding_sum
    elif _is_number(demand):
        conservative_demand = float(demand)

    result["conservative_demand"] = conservative_demand
    if _is_number(count) and _is_number(conservative_demand) and float(conservative_demand) > EPSILON:
        result["conservative_ratio"] = float(count) / float(conservative_demand)

    # Validate the projected-addition equation without mutating topology:
    # remove each existing binding's ASM demand, then re-add AAC's mirrored
    # demand for that same window. Raw binding equality is the proof condition.
    # Live source.demand is tracked separately because Demand/Graph modes can
    # smooth or transform it between ticks.
    var reprojection_matches := 0
    var reprojection_mismatches := 0
    var reprojection_unavailable := 0
    var live_reprojection_matches := 0
    var live_reprojection_mismatches := 0
    var largest_increment := 0.0

    for detail in details:
        var binding_demand = detail.get("binding_demand", null)
        var mirror_demand = detail.get("mirror_demand", null)

        detail["reprojection_base_without"] = null
        detail["reprojected_total"] = null
        detail["reprojection_binding_match"] = "unavailable"
        detail["reprojection_live_match"] = "unavailable"

        if (
            not binding_sum_available
            or not _is_number(binding_demand)
            or not _is_number(mirror_demand)
        ):
            reprojection_unavailable += 1
            continue

        largest_increment = maxf(largest_increment, float(mirror_demand))

        var base_without := binding_sum - float(binding_demand)
        var reprojected_total := base_without + float(mirror_demand)
        detail["reprojection_base_without"] = base_without
        detail["reprojected_total"] = reprojected_total

        var binding_projection_match := _approximately_equal(
            binding_sum,
            reprojected_total
        )
        detail["reprojection_binding_match"] = (
            "match" if binding_projection_match else "mismatch"
        )

        if binding_projection_match:
            reprojection_matches += 1
        else:
            reprojection_mismatches += 1

        if _is_number(demand):
            var live_projection_match := _approximately_equal(
                float(demand),
                reprojected_total
            )
            detail["reprojection_live_match"] = (
                "match" if live_projection_match else "mismatch"
            )
            if live_projection_match:
                live_reprojection_matches += 1
            else:
                live_reprojection_mismatches += 1

    result["reprojection_matches"] = reprojection_matches
    result["reprojection_mismatches"] = reprojection_mismatches
    result["reprojection_unavailable"] = reprojection_unavailable
    result["live_reprojection_matches"] = live_reprojection_matches
    result["live_reprojection_mismatches"] = live_reprojection_mismatches

    # A conservative synthetic projection exercises the exact arithmetic AAC
    # will use for a future unserved manager target. It adds the largest
    # currently observed finite binding demand to max(live, raw) demand.
    # This is diagnostic-only and never affects score or topology.
    if _is_number(conservative_demand):
        result["synthetic_increment_demand"] = largest_increment
        var synthetic_total := float(conservative_demand) + largest_increment
        result["synthetic_projected_total"] = synthetic_total
        if _is_number(count) and synthetic_total > EPSILON:
            var synthetic_ratio := float(count) / synthetic_total
            result["synthetic_projected_ratio"] = synthetic_ratio
            result["synthetic_adjustment"] = _diagnostic_headroom_adjustment(synthetic_ratio)

    return result


func _build_candidate_projection(kind: String, candidate: Dictionary) -> Dictionary:
    var result := {
        "kind": kind,
        "source_id": str(candidate.get("source_id", "")),
        "source_window": str(candidate.get("source_window", "")),
        "target_id": str(candidate.get("target_id", "")),
        "target_window": str(candidate.get("target_window", "")),
        "target_name": str(candidate.get("target_name", "")),
        "resource": str(candidate.get("resource", "")),
        "basis": "count_per_second",
        "current_count": null,
        "current_demand": null,
        "current_ratio": null,
        "projected_target_demand": null,
        "projected_total_demand": null,
        "projected_ratio": null,
        "raw_bound_demand": null,
        "conservative_baseline": null,
        "baseline_policy": "unavailable",
        "diagnostic_adjustment": 0.0,
        "applied_score_adjustment": 0.0,
        "already_bound_window": false,
        "target_goal": null,
        "target_min_input_ratio": null,
        "target_input_count": 0,
        "mode": "diagnostic_only_no_score_effect"
    }

    var scorer_metrics = candidate.get("trusted_manager_metrics", {})
    if scorer_metrics is Dictionary:
        result["applied_score_adjustment"] = float(
            scorer_metrics.get("score_adjustment", 0.0)
        )

    var source = _live_resource(str(result["source_id"]))
    var target = _live_resource(str(result["target_id"]))
    if not is_instance_valid(source) or not is_instance_valid(target):
        return result

    var count = _read_numeric_property(source, "count")
    var demand = _read_numeric_property(source, "demand")
    var use_count := false
    if "use_count" in source:
        use_count = bool(source.get("use_count"))
    result["current_count"] = count
    result["current_demand"] = demand
    result["basis"] = "count" if use_count else "count_per_second"
    if _is_number(count) and _is_number(demand) and float(demand) > EPSILON:
        result["current_ratio"] = float(count) / float(demand)

    var target_window = _parent_window(target)
    if not is_instance_valid(target_window):
        return result

    var mirror: Dictionary = _mirror_window_demand(target_window, [target], use_count)
    result["target_goal"] = mirror.get("goal", null)
    result["target_min_input_ratio"] = mirror.get("min_input_ratio", null)
    result["target_input_count"] = int(mirror.get("input_count", 0))
    if not bool(mirror.get("available", false)):
        return result

    var target_demand := float(mirror.get("demand", 0.0))
    result["projected_target_demand"] = target_demand

    var already_bound := _manager_has_window(source, target_window)
    result["already_bound_window"] = already_bound

    var raw_bound_demand = _raw_manager_binding_sum(source, use_count)
    result["raw_bound_demand"] = raw_bound_demand

    var conservative_baseline = null
    if _is_number(demand) and _is_number(raw_bound_demand):
        conservative_baseline = maxf(float(demand), float(raw_bound_demand))
    elif _is_number(raw_bound_demand):
        conservative_baseline = float(raw_bound_demand)
    elif _is_number(demand):
        conservative_baseline = float(demand)

    result["conservative_baseline"] = conservative_baseline
    result["baseline_policy"] = "max_live_and_raw_bound_demand"

    if _is_number(conservative_baseline):
        var incremental_demand := 0.0 if already_bound else target_demand
        var projected_total := float(conservative_baseline) + incremental_demand
        result["projected_total_demand"] = projected_total
        if _is_number(count) and projected_total > EPSILON:
            var projected_ratio := float(count) / projected_total
            result["projected_ratio"] = projected_ratio
            result["diagnostic_adjustment"] = _diagnostic_headroom_adjustment(projected_ratio)

    return result


func _mirror_window_demand(window, own_sources_value, use_count: bool = false) -> Dictionary:
    var result := {
        "available": false,
        "demand": null,
        "goal": null,
        "min_input_ratio": null,
        "input_count": 0,
        "role": "unknown"
    }

    if not is_instance_valid(window):
        return result

    var own_sources: Array = []
    if own_sources_value is Array:
        own_sources = own_sources_value

    # SmartWindowData.get_demand() returns zero when none of this manager's
    # supplied inputs are actually bound into the target window.
    if own_sources.is_empty():
        result["available"] = true
        result["demand"] = 0.0
        result["goal"] = 0.0
        result["min_input_ratio"] = 0.0
        result["role"] = "unbound"
        return result

    # SmartWindowData classifies a window exposing "demand" as another manager.
    # In that role its demand is forwarded directly rather than goal-derived.
    if "demand" in window:
        var raw_manager_demand = window.get("demand")
        if not _is_number(raw_manager_demand):
            return result

        result["available"] = true
        result["demand"] = float(raw_manager_demand)
        result["goal"] = null
        result["min_input_ratio"] = null
        result["role"] = "manager"
        return result

    if not "containers" in window:
        return result

    var raw_containers = window.get("containers")
    if not raw_containers is Array:
        return result

    # Mirror SmartWindowData.dependent: only material/material-limited input
    # containers that are not supplied by this manager contribute to demand.
    var input_ratios: Array[float] = []
    for raw_container in raw_containers:
        if not is_instance_valid(raw_container):
            continue

        var container: Object = raw_container
        if not container.is_in_group("input"):
            continue
        if own_sources.has(container):
            continue
        if not _is_material_input(container):
            continue

        var numerator_property := "count" if use_count else "production"
        var numerator = _read_numeric_property(container, numerator_property)
        var required = _read_numeric_property(container, "required")
        if not _is_number(numerator) or not _is_number(required):
            return result

        var divisor := float(required)
        if is_zero_approx(divisor):
            divisor = 1.0
        input_ratios.append(float(numerator) / divisor)

    result["input_count"] = input_ratios.size()

    # No dependent material inputs means SmartWindowData is not a finite
    # consumer and contributes zero finite demand.
    if input_ratios.is_empty():
        result["available"] = true
        result["demand"] = 0.0
        result["goal"] = 0.0
        result["min_input_ratio"] = 0.0
        result["role"] = "storage_or_artifact"
        return result

    var goal := 0.0
    if window.has_method("get_goal"):
        var raw_goal = window.call("get_goal")
        if not _is_number(raw_goal):
            return result
        goal = float(raw_goal)
    elif "goal" in window:
        # Compatibility fallback for a window that exposes a numeric goal
        # property instead of the game's normal get_goal() method.
        var raw_goal = window.get("goal")
        if not _is_number(raw_goal):
            return result
        goal = float(raw_goal)
    else:
        return result

    var min_ratio := input_ratios[0]
    for ratio in input_ratios:
        min_ratio = minf(min_ratio, ratio)

    result["available"] = true
    result["goal"] = goal
    result["min_input_ratio"] = min_ratio
    result["demand"] = min_ratio * goal
    result["role"] = "consumer"
    return result


func _manager_has_window(source: Object, target_window: Object) -> bool:
    if not is_instance_valid(source) or not is_instance_valid(target_window):
        return false
    if not "window_binds" in source:
        return false

    var raw_binds = source.get("window_binds")
    if not raw_binds is Dictionary:
        return false

    var binds: Dictionary = raw_binds
    return binds.has(target_window)


func _parent_window(node: Object):
    if not is_instance_valid(node) or not node is Node:
        return null

    var current: Node = node
    var depth := 0
    while is_instance_valid(current) and depth < 16:
        if current.is_in_group("window"):
            return current
        current = current.get_parent()
        depth += 1
    return null


func _live_resource(container_id: String):
    if container_id.is_empty() or not is_instance_valid(Globals.desktop):
        return null
    if not Globals.desktop.has_method("get_resource"):
        return null
    return Globals.desktop.call("get_resource", container_id)


func _report_manager_sample(managers: Array[Dictionary]) -> void:
    var signature_parts: Array[String] = []
    for manager in managers:
        signature_parts.append("%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s" % [
            manager.get("source_id", ""),
            str(manager.get("count", null)),
            str(manager.get("demand", null)),
            str(manager.get("mirror_demand_sum", null)),
            manager.get("binding_match", "unavailable"),
            manager.get("mirror_match", "unavailable"),
            str(manager.get("reprojection_matches", 0)),
            str(manager.get("reprojection_mismatches", 0)),
            manager.get("basis", "count_per_second"),
            str(manager.get("distribution_mode", null)),
            manager.get("raw_mirror_match", "unavailable"),
            str(manager.get("synthetic_projected_ratio", null))
        ])
    var signature := "|".join(signature_parts)

    print("%s ManagerSample index=%d managers=%d changed=%s" % [
        LOG_PREFIX,
        _resource_sample_index,
        managers.size(),
        str(signature != _last_manager_signature)
    ])

    if signature == _last_manager_signature and _resource_sample_index > 1:
        return
    _last_manager_signature = signature

    for manager in managers:
        print("%s   Manager kind='%s' window='%s' source='%s' resource='%s' basis='%s' mode=%s count=%s live_demand=%s live_ratio=%s raw_demand=%s raw_ratio=%s mirror_sum=%s raw_mirror_match='%s' live_binding_match='%s' live_mirror_match='%s' live_semantics='%s' conservative_demand=%s conservative_ratio=%s reprojection_match=%d reprojection_mismatch=%d reprojection_unavailable=%d live_reprojection_match=%d live_reprojection_mismatch=%d synthetic_increment=%s synthetic_total=%s synthetic_ratio=%s synthetic_adjustment=%s synthetic_scoring='diagnostic_only' candidate_scoring='enabled_if_runtime_validation_passes'" % [
            LOG_PREFIX,
            manager.get("kind", ""),
            manager.get("source_window", ""),
            manager.get("source_id", ""),
            manager.get("resource", ""),
            manager.get("basis", "count_per_second"),
            str(manager.get("distribution_mode", null)),
            str(manager.get("count", null)),
            str(manager.get("demand", null)),
            str(manager.get("current_ratio", null)),
            str(manager.get("binding_demand_sum", null)),
            str(manager.get("raw_supply_to_demand_ratio", null)),
            str(manager.get("mirror_demand_sum", null)),
            manager.get("raw_mirror_match", "unavailable"),
            manager.get("binding_match", "unavailable"),
            manager.get("mirror_match", "unavailable"),
            manager.get("live_state_semantics", "unknown"),
            str(manager.get("conservative_demand", null)),
            str(manager.get("conservative_ratio", null)),
            int(manager.get("reprojection_matches", 0)),
            int(manager.get("reprojection_mismatches", 0)),
            int(manager.get("reprojection_unavailable", 0)),
            int(manager.get("live_reprojection_matches", 0)),
            int(manager.get("live_reprojection_mismatches", 0)),
            str(manager.get("synthetic_increment_demand", null)),
            str(manager.get("synthetic_projected_total", null)),
            str(manager.get("synthetic_projected_ratio", null)),
            str(manager.get("synthetic_adjustment", 0.0))
        ])

        var logged := 0
        for raw_binding in manager.get("bindings", []):
            if logged >= MAX_BOUND_WINDOWS_TO_LOG:
                break
            if not raw_binding is Dictionary:
                continue

            var binding: Dictionary = raw_binding
            print("%s     Bound window='%s' basis='%s' binding_demand=%s mirror_demand=%s goal=%s min_basis_required=%s other_inputs=%d own_sources=%d reprojected_total=%s reproject_binding='%s' reproject_live='%s'" % [
                LOG_PREFIX,
                binding.get("window", ""),
                binding.get("basis", "count_per_second"),
                str(binding.get("binding_demand", null)),
                str(binding.get("mirror_demand", null)),
                str(binding.get("goal", null)),
                str(binding.get("min_input_ratio", null)),
                int(binding.get("input_count", 0)),
                int(binding.get("own_source_count", 0)),
                str(binding.get("reprojected_total", null)),
                binding.get("reprojection_binding_match", "unavailable"),
                binding.get("reprojection_live_match", "unavailable")
            ])
            logged += 1


func _report_projection_sample(projections: Array[Dictionary], sample_index: int) -> void:
    var signature_parts: Array[String] = []
    for projection in projections:
        signature_parts.append("%s:%s:%s:%s:%s:%s" % [
            projection.get("source_id", ""),
            projection.get("target_id", ""),
            str(projection.get("current_demand", null)),
            str(projection.get("projected_target_demand", null)),
            str(projection.get("projected_ratio", null)),
            str(projection.get("applied_score_adjustment", 0.0))
        ])
    var signature := "|".join(signature_parts)

    var nonzero_score_effects := 0
    for projection in projections:
        if absf(float(projection.get("applied_score_adjustment", 0.0))) > EPSILON:
            nonzero_score_effects += 1

    print("%s ProjectionSample index=%d manager_candidates=%d changed=%s score_effect='enabled_bounded_projected_headroom' nonzero_effects=%d" % [
        LOG_PREFIX,
        sample_index,
        projections.size(),
        str(signature != _last_projection_signature),
        nonzero_score_effects
    ])

    if signature == _last_projection_signature and sample_index > 1:
        return
    _last_projection_signature = signature

    var logged := 0
    for projection in projections:
        if logged >= MAX_PROJECTIONS_TO_LOG:
            break

        print("%s   Project kind='%s' source='%s/%s' target='%s/%s' resource='%s' basis='%s' count=%s live_demand=%s live_ratio=%s raw_bound_demand=%s conservative_baseline=%s baseline_policy='%s' target_demand=%s projected_total=%s projected_ratio=%s diagnostic_adjustment=%s applied_adjustment=%s target_goal=%s target_min_basis_required=%s target_other_inputs=%d already_bound_window=%s scoring='enabled_if_runtime_validation_passes'" % [
            LOG_PREFIX,
            projection.get("kind", ""),
            projection.get("source_window", ""),
            projection.get("source_id", ""),
            projection.get("target_window", ""),
            projection.get("target_name", ""),
            projection.get("resource", ""),
            projection.get("basis", "count_per_second"),
            str(projection.get("current_count", null)),
            str(projection.get("current_demand", null)),
            str(projection.get("current_ratio", null)),
            str(projection.get("raw_bound_demand", null)),
            str(projection.get("conservative_baseline", null)),
            projection.get("baseline_policy", "unavailable"),
            str(projection.get("projected_target_demand", null)),
            str(projection.get("projected_total_demand", null)),
            str(projection.get("projected_ratio", null)),
            str(projection.get("diagnostic_adjustment", 0.0)),
            str(projection.get("applied_score_adjustment", 0.0)),
            str(projection.get("target_goal", null)),
            str(projection.get("target_min_input_ratio", null)),
            int(projection.get("target_input_count", 0)),
            str(projection.get("already_bound_window", false))
        ])
        logged += 1


func _read_numeric_property(object: Object, property_name: String):
    if not is_instance_valid(object) or not property_name in object:
        return null

    var value = object.get(property_name)
    if value is int or value is float:
        return float(value)
    return null


func _manager_kind(window_name: String, resource: String) -> String:
    var window_value := window_name.to_lower()
    var resource_value := resource.to_lower()

    if window_value.begins_with("smart_thread_manager") and resource_value == "clock_speed":
        return "smart_thread_manager"
    if window_value.begins_with("smart_gpu_manager") and resource_value == "gpu_speed":
        return "smart_gpu_manager"
    return ""


func _raw_manager_binding_sum(source: Object, use_count: bool):
    if not is_instance_valid(source) or not "window_binds" in source:
        return null

    var raw_binds = source.get("window_binds")
    if not raw_binds is Dictionary:
        return null

    var total := 0.0
    var method_name := "get_count_demand" if use_count else "get_demand"

    for raw_binding in raw_binds.values():
        if not is_instance_valid(raw_binding):
            return null
        var binding: Object = raw_binding
        if not binding.has_method(method_name):
            return null

        var value = binding.call(method_name)
        if not _is_number(value):
            return null
        total += float(value)

    return total


func _diagnostic_headroom_adjustment(ratio: float) -> float:
    if ratio >= 1.5:
        return 4.0
    if ratio >= 1.0:
        return 2.0
    if ratio >= 0.75:
        return -2.0
    return -4.0


func _is_material_input(container: Object) -> bool:
    if not is_instance_valid(container):
        return false
    if not "type" in container:
        return false

    var raw_type = container.get("type")
    if not _is_number(raw_type):
        return false

    var type_value := int(raw_type)
    return (
        type_value == int(Utils.resource_types.MATERIAL)
        or type_value == int(Utils.resource_types.MATERIAL_LIMITED)
    )


func _projected_headroom_status(ratio: float) -> String:
    if ratio >= 1.5:
        return "projected_headroom"
    if ratio >= 1.0:
        return "projected_meets_demand"
    if ratio >= 0.75:
        return "projected_near_pressure"
    return "projected_under_demand"


func _approximately_equal(left: float, right: float) -> bool:
    var difference := absf(left - right)
    if difference <= ABS_TOLERANCE:
        return true
    var scale := maxf(absf(left), absf(right))
    if scale <= EPSILON:
        return true
    return difference / scale <= REL_TOLERANCE


func _array_size(value) -> int:
    if value is Array or value is PackedStringArray:
        return value.size()
    return 0


func _is_number(value) -> bool:
    return value is int or value is float


func _sort_manager_records(left: Dictionary, right: Dictionary) -> bool:
    var left_kind := str(left.get("kind", ""))
    var right_kind := str(right.get("kind", ""))
    if left_kind != right_kind:
        return left_kind < right_kind
    return str(left.get("source_id", "")) < str(right.get("source_id", ""))


func _sort_binding_records(left: Dictionary, right: Dictionary) -> bool:
    return str(left.get("window", "")) < str(right.get("window", ""))


func _sort_projection_records(left: Dictionary, right: Dictionary) -> bool:
    var left_target := "%s|%s|%s" % [
        left.get("target_window", ""),
        left.get("target_name", ""),
        left.get("source_id", "")
    ]
    var right_target := "%s|%s|%s" % [
        right.get("target_window", ""),
        right.get("target_name", ""),
        right.get("source_id", "")
    ]
    return left_target < right_target
