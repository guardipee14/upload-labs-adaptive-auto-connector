extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector]"

# Verified against a real Upload Labs mod-loader log on 2026-08-20.
# Keep these as optional integrations: the base mod must still work without them.
const COMPATIBILITY_MOD_IDS := {
    "Smart Thread Manager": "kuuk-SmartThreadManager",
    "Smart GPU Manager": "kuuk-SmartGPUManager",
    "SmartConnections": "Helios-SmartConnections",
    "Upload Labs+": "chingcm-UploadLabsPlus",
    "Upload Labs+ ModUtils": "chingcm-ModUtils",
    "Taj's Mods - Core": "TajemnikTV-Core"
}


func report_environment() -> void:
    print("%s Compatibility probe starting." % LOG_PREFIX)

    var active_mod_ids := _get_active_mod_ids()
    print("%s Active mod IDs (%d):" % [LOG_PREFIX, active_mod_ids.size()])

    if active_mod_ids.is_empty():
        print("%s   (none reported by ModLoaderMod)" % LOG_PREFIX)
    else:
        active_mod_ids.sort()
        for mod_id in active_mod_ids:
            print("%s   - %s" % [LOG_PREFIX, mod_id])

    print("%s Compatibility integrations:" % LOG_PREFIX)
    for display_name in COMPATIBILITY_MOD_IDS.keys():
        var expected_id: String = COMPATIBILITY_MOD_IDS[display_name]
        if active_mod_ids.has(expected_id):
            print("%s   %s: detected as '%s'" % [LOG_PREFIX, display_name, expected_id])
        else:
            print("%s   %s: not detected (expected '%s')" % [LOG_PREFIX, display_name, expected_id])

    var tajs_core_available := Engine.has_meta("TajsCore")
    print("%s Taj's Core runtime API: %s" % [LOG_PREFIX, "available" if tajs_core_available else "not detected"])
    print("%s Probe complete. No game state was modified." % LOG_PREFIX)


func _get_active_mod_ids() -> Array[String]:
    var result: Array[String] = []
    var all_mods: Dictionary = ModLoaderMod.get_mod_data_all()

    for raw_id in all_mods.keys():
        var mod_id := str(raw_id)
        var mod_data = all_mods[raw_id]
        var is_active := true

        if mod_data != null:
            var active_value = mod_data.get("is_active")
            if active_value != null:
                is_active = bool(active_value)

        if is_active:
            result.append(mod_id)

    return result
