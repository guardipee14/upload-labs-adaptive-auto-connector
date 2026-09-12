extends SceneTree

const CORE := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/"
var checks := 0
var failures := 0


class TestResource extends Node:
    var resource := "clock_speed"
    var required = 0.0
    var production := 0.0
    var count := 0.0
    var type := 1
    var input_id := ""
    var output_ids: Array[String] = []
    var connectable := true

    func can_connect(other) -> bool:
        return connectable and other.connectable and resource == other.resource


class TestManager extends TestResource:
    var demand := 12.0
    var window_binds: Dictionary = {}
    var use_count := false
    var distribution_mode := 1


class TestWindow extends Node:
    var containers: Array = []
    var goal := 2.0

    func get_goal() -> float:
        return goal


class TestBinding extends RefCounted:
    var window: Node
    var own_sources: Array = []
    var production_demand := 10.0
    var count_demand := 30.0

    func get_demand() -> float:
        return production_demand

    func get_count_demand() -> float:
        return count_demand


class TestDesktop extends Node:
    var resources: Dictionary = {}

    func get_resource(id: String):
        return resources.get(id)


class TestPreference extends Node:
    func get_candidate_preference(_candidate: Dictionary) -> Dictionary:
        return {"adjustment": -8.0, "events": {}, "semantic_key": "test"}


func _initialize() -> void:
    call_deferred("_run")


func _expect(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + label)


func _window(parent: Node, label: String, production: float, stock: float) -> TestWindow:
    var window := TestWindow.new()
    window.name = label
    parent.add_child(window)
    window.add_to_group("window")
    var speed := TestResource.new()
    speed.name = "Speed"
    window.add_child(speed)
    speed.add_to_group("input")
    var material := TestResource.new()
    material.name = "File"
    material.type = 0
    material.required = 1.0
    material.resource = "text"
    material.production = production
    material.count = stock
    window.add_child(material)
    material.add_to_group("input")
    window.containers = [speed, material]
    return window


func _sample(source: TestResource, target: TestResource, kind: String) -> Dictionary:
    return {"containers": {
        "source": {"window_name": kind, "name": "Output", "resource": source.resource,
            "required": 0.0, "production": source.production, "input": "",
            "outputs": source.output_ids},
        "target": {"window_name": "analyzer5", "name": "Speed", "resource": target.resource,
            "required": target.required, "production": 0.0, "input": target.input_id,
            "outputs": []}
    }}


func _snapshot(resource: String, kind: String, color: String = "orange",
        source_has_output: bool = true, target_has_input: bool = true) -> Dictionary:
    return {"windows": [
        {"name": kind, "containers": [{"id": "source", "name": "Output",
            "has_input_connector": false, "has_output_connector": source_has_output,
            "connector_color": "orange", "discovery": {"resource": resource}}]},
        {"name": "analyzer5", "containers": [{"id": "target", "name": "Speed",
            "has_input_connector": target_has_input, "has_output_connector": false,
            "connector_color": color, "discovery": {"resource": resource}}]}
    ]}


func _candidate_count(generator: Node) -> int:
    return generator.get_candidates().get("target", []).size()


func _run_case(resource: String, use_count: bool) -> void:
    var kind := "smart_gpu_manager0" if resource == "gpu_speed" else "smart_thread_manager0"
    var fixture := Node.new()
    root.add_child(fixture)
    var desktop := TestDesktop.new()
    fixture.add_child(desktop)
    root.get_node("Globals").desktop = desktop
    var manager := TestManager.new()
    manager.resource = resource
    manager.count = 120.0
    manager.use_count = use_count
    manager.output_ids = ["bound_speed"]
    fixture.add_child(manager)
    var bound := _window(fixture, "bound_consumer", 5.0, 15.0)
    var target_window := _window(fixture, "analyzer5", 3.0, 8.0)
    var target: TestResource = target_window.containers[0]
    target.resource = resource
    var binding := TestBinding.new()
    binding.window = bound
    binding.own_sources = [bound.containers[0]]
    manager.window_binds[bound] = binding
    desktop.resources = {"source": manager, "target": target}

    var generator = load(CORE + "candidate_generator.gd").new()
    var validator = load(CORE + "manager_validation_probe.gd").new()
    var scorer = load(CORE + "adaptive_candidate_scorer.gd").new()
    var explainer = load(CORE + "explanation_engine.gd").new()
    fixture.add_child(generator)
    fixture.add_child(validator)
    fixture.add_child(scorer)
    fixture.add_child(explainer)
    generator.consume_detailed_snapshot(_snapshot(resource, kind))

    # Reproduce the real disconnect: required=0, no input, manager still supplied.
    generator.consume_resource_sample(_sample(manager, target, kind))
    _expect(_candidate_count(generator) == 1, resource + ": disconnected speed reaches candidates")
    if _candidate_count(generator) != 1:
        root.get_node("Globals").desktop = null
        fixture.free()
        return
    var candidate: Dictionary = generator.get_candidates()["target"][0]
    _expect(candidate.target_required == 0.0, "keep zero cost; do not fabricate a ratio")
    _expect(candidate.target_reason == "unserved_speed_input", "diagnostic reason is explicit")

    # Exercise the actual validation provider and adaptive scorer together.
    scorer.set_manager_metrics_provider(validator)
    scorer.consume_candidates(generator.get_candidates(), 1)
    var ranked: Dictionary = scorer.get_scored_candidates()["target"][0]
    var metrics: Dictionary = ranked.trusted_manager_metrics
    var expected_target := 16.0 if use_count else 6.0
    var expected_baseline := 30.0 if use_count else 12.0
    _expect(metrics.validation_mode == "runtime_validated_projected_headroom", "projection gate passes")
    _expect(metrics.projected_target_demand == expected_target, "correct production/count basis")
    _expect(metrics.conservative_baseline == expected_baseline, "max live/raw baseline")
    _expect(metrics.projected_total_demand == expected_target + expected_baseline, "new target added once")
    _expect(metrics.score_adjustment == 4.0, "validated +4 reaches ranking")
    _expect(ranked.observed_capacity_ratio == null, "zero denominator remains unavailable")
    _expect(ranked.score_components.capacity_hint == 0.0, "zero cost earns no capacity ratio bonus")
    explainer.consume_scored_candidates(scorer.get_scored_candidates(), 1)
    _expect(explainer.get_recommendations().has("target"), "candidate reaches recommendation")
    validator.consume_scored_candidates(scorer.get_scored_candidates(), 1)

    var preference := TestPreference.new()
    fixture.add_child(preference)
    scorer.set_preference_model(preference)
    var preferred: Dictionary = scorer._score_candidate(candidate)
    _expect(preferred.advisory_score == ranked.advisory_score - 8.0, "player preference remains independent")
    manager.count = 1.0
    _expect(scorer._score_candidate(candidate).trusted_manager_metrics.score_adjustment == -4.0,
        "validated shortage contributes bounded -4")
    manager.count = 120.0
    binding.production_demand = 100.0
    binding.count_demand = 100.0
    _expect(scorer._score_candidate(candidate).trusted_manager_metrics.score_adjustment == 0.0,
        "failed raw validation contributes zero")
    scorer.set_manager_metrics_provider(null)
    _expect(scorer._score_candidate(candidate).trusted_manager_metrics.score_adjustment == 0.0,
        "missing provider contributes zero")

    # Reconnection and live legality still exclude unavailable/occupied inputs.
    target.input_id = "source"
    generator.consume_resource_sample(_sample(manager, target, kind))
    _expect(_candidate_count(generator) == 0, "reconnected target disappears")
    target.input_id = ""
    target.connectable = false
    generator.consume_resource_sample(_sample(manager, target, kind))
    _expect(_candidate_count(generator) == 0, "live can_connect rejection is respected")
    target.connectable = true
    manager.output_ids.append("target")
    generator.consume_resource_sample(_sample(manager, target, kind))
    _expect(_candidate_count(generator) == 0, "existing source route is excluded")
    manager.output_ids = ["bound_speed"]
    generator.consume_detailed_snapshot(_snapshot(resource, kind, "black"))
    generator.consume_resource_sample(_sample(manager, target, kind))
    _expect(_candidate_count(generator) == 0, "black connectors remain excluded")
    generator.consume_detailed_snapshot(_snapshot(resource, kind, "orange", false))
    generator.consume_resource_sample(_sample(manager, target, kind))
    _expect(_candidate_count(generator) == 0, "source output connector is required")
    generator.consume_detailed_snapshot(_snapshot(resource, kind, "orange", true, false))
    generator.consume_resource_sample(_sample(manager, target, kind))
    _expect(_candidate_count(generator) == 0, "target input connector is required")
    generator.consume_detailed_snapshot(_snapshot(resource, kind))
    for invalid_required in [null, -1.0, "0", NAN]:
        target.required = invalid_required
        generator.consume_resource_sample(_sample(manager, target, kind))
        _expect(_candidate_count(generator) == 0, "invalid required cannot enter speed exception")
    target.required = 0.0
    manager.resource = "text"
    target.resource = "text"
    generator.consume_resource_sample(_sample(manager, target, kind))
    _expect(_candidate_count(generator) == 0, "zero-cost material input is still excluded")
    target.required = 2.0
    generator.consume_resource_sample(_sample(manager, target, kind))
    _expect(_candidate_count(generator) == 1, "ordinary positive-cost inputs remain eligible")
    manager.resource = "gpu_speed" if resource == "clock_speed" else "clock_speed"
    target.resource = resource
    target.required = 0.0
    generator.consume_resource_sample(_sample(manager, target, kind))
    _expect(_candidate_count(generator) == 0, "resource mismatch remains excluded")
    _expect(target.input_id.is_empty() and manager.output_ids == ["bound_speed"],
        "candidate/scoring pipeline never mutates the topology")

    root.get_node("Globals").desktop = null
    fixture.free()


func _run() -> void:
    _run_case("clock_speed", false)
    _run_case("gpu_speed", true)
    print("AAC REGRESSION: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
