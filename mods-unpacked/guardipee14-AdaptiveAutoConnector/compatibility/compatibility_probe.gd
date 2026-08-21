extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector]"

# These are intentionally only discovery hints in v0.1.0. After testing against
# the actual installed mods, exact mod IDs will replace heuristic matching.
const COMPATIBILITY_HINTS := {
    "Smart Thread Manager": ["smartthread", "threadmanager"],
    "Smart GPU Manager": ["smartgpu", "gpumanager"],
    "SmartConnections": ["smartconnections"],
    "Upload Labs+": ["uploadlabsplus", "uploadlabs+"],
    "Upload Labs+ Dev Utils": ["devutils", "uploadlabsplusdev"],
    "Taj's Mods - Core": ["taj", "core"]
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

    print("%s Compatibility candidates:" % LOG_PREFIX)
    for display_name in COMPATIBILITY_HINTS.keys():
        var candidate := _find_candidate(active_mod_ids, COMPATIBILITY_HINTS[display_name])
        if candidate.is_empty():
            print("%s   %s: not detected" % [LOG_PREFIX, display_name])
        else:
            print("%s   %s: candidate '%s'" % [LOG_PREFIX, display_name, candidate])

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


func _find_candidate(active_mod_ids: Array[String], hints: Array) -> String:
    for mod_id in active_mod_ids:
        var normalized_id := _normalize(mod_id)
        for raw_hint in hints:
            var normalized_hint := _normalize(str(raw_hint))
            if not normalized_hint.is_empty() and normalized_id.contains(normalized_hint):
                return mod_id
    return ""


func _normalize(value: String) -> String:
    return value.to_lower().replace(" ", "").replace("-", "").replace("_", "")
