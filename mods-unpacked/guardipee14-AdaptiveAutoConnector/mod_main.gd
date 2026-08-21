extends Node

const MOD_ID := "guardipee14-AdaptiveAutoConnector"
const MOD_VERSION := "0.1.0"
const COMPATIBILITY_PROBE_PATH := "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/compatibility/compatibility_probe.gd"

var _compatibility_probe: Node = null


func _init() -> void:
    print("[%s] v%s loading..." % [MOD_ID, MOD_VERSION])
    print("[%s] WIP observer build: no connections will be changed." % MOD_ID)


func _ready() -> void:
    call_deferred("_start_probe")


func _start_probe() -> void:
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

    print("[%s] v%s ready." % [MOD_ID, MOD_VERSION])
