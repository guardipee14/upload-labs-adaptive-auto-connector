extends Node

const MOD_ID := "guardipee14-AdaptiveAutoConnector"
const MOD_VERSION := "0.1.4"
const COMPATIBILITY_PROBE_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/compatibility/compatibility_probe.gd"
const TOPOLOGY_OBSERVER_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/topology_observer.gd"
const TOPOLOGY_GRAPH_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/topology_graph.gd"
const RESOURCE_MODEL_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/resource_model.gd"
const CANDIDATE_GENERATOR_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/candidate_generator.gd"

var _compatibility_probe: Node = null
var _topology_observer: Node = null
var _topology_graph: Node = null
var _resource_model: Node = null
var _candidate_generator: Node = null


func _init() -> void:
    print("[%s] v%s loading..." % [MOD_ID, MOD_VERSION])
    print("[%s] WIP read-only build: no connections will be changed." % MOD_ID)


func _ready() -> void:
    call_deferred("_start_services")


func _start_services() -> void:
    _start_compatibility_probe()
    _start_topology_graph()
    _start_resource_model()
    _start_candidate_generator()
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

    if _topology_observer.has_method("start_observing"):
        _topology_observer.call("start_observing")
