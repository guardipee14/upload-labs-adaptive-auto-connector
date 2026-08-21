extends Node

const MOD_ID := "guardipee14-AdaptiveAutoConnector"
const MOD_VERSION := "0.1.1"
const COMPATIBILITY_PROBE_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/compatibility/compatibility_probe.gd"
const TOPOLOGY_OBSERVER_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/core/topology_observer.gd"

var _compatibility_probe: Node = null
var _topology_observer: Node = null


func _init() -> void:
    print("[%s] v%s loading..." % [MOD_ID, MOD_VERSION])
    print("[%s] WIP observer build: no connections will be changed." % MOD_ID)


func _ready() -> void:
    call_deferred("_start_services")


func _start_services() -> void:
    _start_compatibility_probe()
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

    if _topology_observer.has_method("start_observing"):
        _topology_observer.call("start_observing")
