extends Node

const MOD_ID := "guardipee14-AdaptiveAutoConnector"
const MOD_VERSION := "0.1.9"
const COMPATIBILITY_PROBE_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/compatibility/compatibility_probe.gd"
const TOPOLOGY_OBSERVER_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/topology_observer.gd"
const TOPOLOGY_GRAPH_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/topology_graph.gd"
const RESOURCE_MODEL_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/resource_model.gd"
const CANDIDATE_GENERATOR_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/candidate_generator.gd"
const CANDIDATE_SCORER_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/candidate_scorer.gd"
const EXPLANATION_ENGINE_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/explanation_engine.gd"
const CONNECTION_CONTROLLER_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/connection_controller.gd"
const SUGGESTION_PRESENTER_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/ui/interaction_presenter.gd"

var _compatibility_probe: Node = null
var _topology_observer: Node = null
var _topology_graph: Node = null
var _resource_model: Node = null
var _candidate_generator: Node = null
var _candidate_scorer: Node = null
var _explanation_engine: Node = null
var _connection_controller: Node = null
var _suggestion_presenter: Node = null


func _init() -> void:
    print("[%s] v%s loading..." % [MOD_ID, MOD_VERSION])
    print("[%s] Player-controlled build: topology changes require explicit Accept connection." % MOD_ID)


func _ready() -> void:
    call_deferred("_start_services")


func _start_services() -> void:
    _start_compatibility_probe()
    _start_topology_graph()
    _start_resource_model()
    _start_candidate_generator()
    _start_candidate_scorer()
    _start_explanation_engine()
    _start_connection_controller()
    _start_suggestion_presenter()
    _wire_candidate_pipeline()
    _start_topology_observer()
    print("[%s] v%s ready." % [MOD_ID, MOD_VERSION])


func _start_compatibility_probe() -> void:
    if not ResourceLoader.exists(COMPATIBILITY_PROBE_PATH):
        push_warning("[%s] Compatibility probe script was not found." % MOD_ID)
        return

    var probe_script := load(COMPATIBILITY_PROBE_PATH)
    if probe_script == null:
        push_warning("[%s] Compatibility probe script could not be loaded." % MOD_ID)
        return

    _compatibility_probe = probe_script.new()
    add_child(_compatibility_probe)

    if _compatibility_probe.has_method("report_environment"):
        _compatibility_probe.call("report_environment")


func _start_topology_graph() -> void:
    if not ResourceLoader.exists(TOPOLOGY_GRAPH_PATH):
        push_warning("[%s] Topology graph script was not found." % MOD_ID)
        return

    var graph_script := load(TOPOLOGY_GRAPH_PATH)
    if graph_script == null:
        push_warning("[%s] Topology graph script could not be loaded." % MOD_ID)
        return

    _topology_graph = graph_script.new()
    add_child(_topology_graph)


func _start_resource_model() -> void:
    if not ResourceLoader.exists(RESOURCE_MODEL_PATH):
        push_warning("[%s] Resource model script was not found." % MOD_ID)
        return

    var resource_script := load(RESOURCE_MODEL_PATH)
    if resource_script == null:
        push_warning("[%s] Resource model script could not be loaded." % MOD_ID)
        return

    _resource_model = resource_script.new()
    add_child(_resource_model)


func _start_candidate_generator() -> void:
    if not ResourceLoader.exists(CANDIDATE_GENERATOR_PATH):
        push_warning("[%s] Candidate generator script was not found." % MOD_ID)
        return

    var candidate_script := load(CANDIDATE_GENERATOR_PATH)
    if candidate_script == null:
        push_warning("[%s] Candidate generator script could not be loaded." % MOD_ID)
        return

    _candidate_generator = candidate_script.new()
    add_child(_candidate_generator)


func _start_candidate_scorer() -> void:
    if not ResourceLoader.exists(CANDIDATE_SCORER_PATH):
        push_warning("[%s] Candidate scorer script was not found." % MOD_ID)
        return

    var scorer_script := load(CANDIDATE_SCORER_PATH)
    if scorer_script == null:
        push_warning("[%s] Candidate scorer script could not be loaded." % MOD_ID)
        return

    _candidate_scorer = scorer_script.new()
    add_child(_candidate_scorer)


func _start_explanation_engine() -> void:
    if not ResourceLoader.exists(EXPLANATION_ENGINE_PATH):
        push_warning("[%s] Explanation engine script was not found." % MOD_ID)
        return

    var explanation_script := load(EXPLANATION_ENGINE_PATH)
    if explanation_script == null:
        push_warning("[%s] Explanation engine script could not be loaded." % MOD_ID)
        return

    _explanation_engine = explanation_script.new()
    add_child(_explanation_engine)


func _start_connection_controller() -> void:
    if not ResourceLoader.exists(CONNECTION_CONTROLLER_PATH):
        push_warning("[%s] Connection controller script was not found." % MOD_ID)
        return

    var controller_script := load(CONNECTION_CONTROLLER_PATH)
    if controller_script == null:
        push_warning("[%s] Connection controller script could not be loaded." % MOD_ID)
        return

    _connection_controller = controller_script.new()
    add_child(_connection_controller)


func _start_suggestion_presenter() -> void:
    if not ResourceLoader.exists(SUGGESTION_PRESENTER_PATH):
        push_warning("[%s] Suggestion presenter script was not found." % MOD_ID)
        return

    var presenter_script := load(SUGGESTION_PRESENTER_PATH)
    if presenter_script == null:
        push_warning("[%s] Suggestion presenter script could not be loaded." % MOD_ID)
        return

    _suggestion_presenter = presenter_script.new()
    add_child(_suggestion_presenter)


func _wire_candidate_pipeline() -> void:
    if is_instance_valid(_candidate_scorer) and is_instance_valid(_candidate_generator):
        if _candidate_scorer.has_method("set_candidate_provider"):
            _candidate_scorer.call("set_candidate_provider", _candidate_generator)

    if is_instance_valid(_candidate_scorer) and is_instance_valid(_explanation_engine):
        if _candidate_scorer.has_signal("candidates_scored") and _explanation_engine.has_method("consume_scored_candidates"):
            _candidate_scorer.connect(
                "candidates_scored",
                Callable(_explanation_engine, "consume_scored_candidates")
            )

    if is_instance_valid(_explanation_engine) and is_instance_valid(_suggestion_presenter):
        if _explanation_engine.has_signal("recommendations_updated") and _suggestion_presenter.has_method("consume_recommendations"):
            _explanation_engine.connect(
                "recommendations_updated",
                Callable(_suggestion_presenter, "consume_recommendations")
            )

    if is_instance_valid(_suggestion_presenter) and _suggestion_presenter.has_method("set_interaction_services"):
        _suggestion_presenter.call(
            "set_interaction_services",
            _candidate_scorer,
            _connection_controller
        )


func _start_topology_observer() -> void:
    if not ResourceLoader.exists(TOPOLOGY_OBSERVER_PATH):
        push_warning("[%s] Topology observer script was not found." % MOD_ID)
        return

    var observer_script := load(TOPOLOGY_OBSERVER_PATH)
    if observer_script == null:
        push_warning("[%s] Topology observer script could not be loaded." % MOD_ID)
        return

    _topology_observer = observer_script.new()
    add_child(_topology_observer)

    if is_instance_valid(_topology_graph):
        if _topology_observer.has_signal("detailed_snapshot_ready") and _topology_graph.has_method("consume_detailed_snapshot"):
            _topology_observer.connect(
                "detailed_snapshot_ready",
                Callable(_topology_graph, "consume_detailed_snapshot")
            )

        if _topology_observer.has_signal("lightweight_state_changed") and _topology_graph.has_method("consume_lightweight_state"):
            _topology_observer.connect(
                "lightweight_state_changed",
                Callable(_topology_graph, "consume_lightweight_state")
            )

    if is_instance_valid(_resource_model):
        if _topology_observer.has_signal("detailed_snapshot_ready") and _resource_model.has_method("consume_detailed_snapshot"):
            _topology_observer.connect(
                "detailed_snapshot_ready",
                Callable(_resource_model, "consume_detailed_snapshot")
            )

        if _topology_observer.has_signal("lightweight_state_changed") and _resource_model.has_method("consume_lightweight_state"):
            _topology_observer.connect(
                "lightweight_state_changed",
                Callable(_resource_model, "consume_lightweight_state")
            )

        if _topology_observer.has_signal("resource_state_sampled") and _resource_model.has_method("consume_resource_sample"):
            _topology_observer.connect(
                "resource_state_sampled",
                Callable(_resource_model, "consume_resource_sample")
            )

    if is_instance_valid(_candidate_generator):
        if _topology_observer.has_signal("detailed_snapshot_ready") and _candidate_generator.has_method("consume_detailed_snapshot"):
            _topology_observer.connect(
                "detailed_snapshot_ready",
                Callable(_candidate_generator, "consume_detailed_snapshot")
            )

        if _topology_observer.has_signal("lightweight_state_changed") and _candidate_generator.has_method("consume_lightweight_state"):
            _topology_observer.connect(
                "lightweight_state_changed",
                Callable(_candidate_generator, "consume_lightweight_state")
            )

        if _topology_observer.has_signal("resource_state_sampled") and _candidate_generator.has_method("consume_resource_sample"):
            _topology_observer.connect(
                "resource_state_sampled",
                Callable(_candidate_generator, "consume_resource_sample")
            )

    if is_instance_valid(_candidate_scorer):
        if _topology_observer.has_signal("resource_state_sampled") and _candidate_scorer.has_method("consume_resource_sample"):
            _topology_observer.connect(
                "resource_state_sampled",
                Callable(_candidate_scorer, "consume_resource_sample")
            )

    if _topology_observer.has_method("start_observing"):
        _topology_observer.call("start_observing")
