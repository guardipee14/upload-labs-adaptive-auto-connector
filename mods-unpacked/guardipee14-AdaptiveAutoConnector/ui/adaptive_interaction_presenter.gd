extends "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/ui/interaction_presenter.gd"

const ADAPTIVE_LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Adaptive]"
const SUPPRESSION_LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Suppression]"
const DIAGNOSTICS_LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Diagnostics]"

var _preference_model: Node = null
var _last_suppression_signature_by_target: Dictionary = {}

var _diagnostics_summary_label: Label = null
var _diagnostics_list: ItemList = null
var _diagnostics_detail_label: Label = null
var _diagnostics_reset_selected_button: Button = null
var _diagnostics_reset_all_button: Button = null
var _diagnostics_selected_key := ""
var _reset_all_armed := false


func set_preference_model(model: Node) -> void:
    var callback := Callable(self, "_on_preference_changed")

    if is_instance_valid(_preference_model) and _preference_model.has_signal("preference_changed"):
        if _preference_model.is_connected("preference_changed", callback):
            _preference_model.disconnect("preference_changed", callback)

    _preference_model = model

    if is_instance_valid(_preference_model) and _preference_model.has_signal("preference_changed"):
        if not _preference_model.is_connected("preference_changed", callback):
            _preference_model.connect("preference_changed", callback)

    _refresh_preference_diagnostics()


func _build_advisor_window(menus: Node) -> void:
    super._build_advisor_window(menus)
    _build_preference_diagnostics()


func _build_preference_diagnostics() -> void:
    if not is_instance_valid(_window):
        return

    var content = _find_descendant_by_name(_window, "InteractionContent")
    if content == null or not content is VBoxContainer:
        print("%s UI build skipped reason='interaction_content_missing'" % DIAGNOSTICS_LOG_PREFIX)
        return

    if content.get_node_or_null("PreferenceDiagnostics") != null:
        _refresh_preference_diagnostics()
        return

    var separator := HSeparator.new()
    separator.name = "PreferenceDiagnosticsSeparator"
    content.add_child(separator)

    var panel := VBoxContainer.new()
    panel.name = "PreferenceDiagnostics"
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_constant_override("separation", 8)
    content.add_child(panel)

    var title := Label.new()
    title.text = "Learned Preferences / Diagnostics"
    title.add_theme_font_size_override("font_size", 22)
    panel.add_child(title)

    _diagnostics_summary_label = Label.new()
    _diagnostics_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _diagnostics_summary_label.add_theme_font_size_override("font_size", 17)
    panel.add_child(_diagnostics_summary_label)

    _diagnostics_list = ItemList.new()
    _diagnostics_list.name = "PreferenceList"
    _diagnostics_list.custom_minimum_size = Vector2(0.0, 150.0)
    _diagnostics_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _diagnostics_list.select_mode = ItemList.SELECT_SINGLE
    _diagnostics_list.item_selected.connect(_on_preference_item_selected)
    panel.add_child(_diagnostics_list)

    _diagnostics_detail_label = Label.new()
    _diagnostics_detail_label.name = "PreferenceDetails"
    _diagnostics_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _diagnostics_detail_label.add_theme_font_size_override("font_size", 17)
    panel.add_child(_diagnostics_detail_label)

    var actions := HBoxContainer.new()
    actions.name = "PreferenceActions"
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 8)
    panel.add_child(actions)

    var refresh_button := _make_text_button(
        "Refresh",
        "Refresh the learned-preference diagnostics from the in-memory schema-1 preference model."
    )
    refresh_button.custom_minimum_size = Vector2(120.0, 46.0)
    refresh_button.add_theme_font_size_override("font_size", 18)
    refresh_button.pressed.connect(_on_refresh_preferences_pressed)
    actions.add_child(refresh_button)

    _diagnostics_reset_selected_button = _make_text_button(
        "Reset Selected",
        "Remove only the selected semantic preference and persist the updated preference store. Topology is never changed."
    )
    _diagnostics_reset_selected_button.custom_minimum_size = Vector2(160.0, 46.0)
    _diagnostics_reset_selected_button.add_theme_font_size_override("font_size", 18)
    _diagnostics_reset_selected_button.pressed.connect(_on_reset_selected_preference_pressed)
    actions.add_child(_diagnostics_reset_selected_button)

    _diagnostics_reset_all_button = _make_text_button(
        "Reset All",
        "Two-click confirmation: clear all learned preferences and persist an empty schema-1 store. Topology is never changed."
    )
    _diagnostics_reset_all_button.custom_minimum_size = Vector2(160.0, 46.0)
    _diagnostics_reset_all_button.add_theme_font_size_override("font_size", 18)
    _diagnostics_reset_all_button.pressed.connect(_on_reset_all_preferences_pressed)
    actions.add_child(_diagnostics_reset_all_button)

    print("%s UI ready mode='scrollable_inline'" % DIAGNOSTICS_LOG_PREFIX)
    _refresh_preference_diagnostics()


func _apply_session_choices(incoming: Dictionary) -> Dictionary:
    var adjusted: Dictionary = {}
    var scored_snapshot := _get_scored_snapshot()

    for raw_target_id in incoming.keys():
        var target_id := str(raw_target_id)
        var original = incoming[raw_target_id]
        if not original is Dictionary:
            continue

        var candidates: Array = scored_snapshot.get(target_id, [])
        if candidates.is_empty():
            var original_rec: Dictionary = original
            if not _is_suppressed(original_rec):
                adjusted[target_id] = original_rec.duplicate(true)
            continue

        var preferred_source := str(_preferred_source_by_target.get(target_id, ""))
        var chosen: Dictionary = {}

        # An explicit player-selected alternative remains authoritative even when
        # its persistent history would normally keep it out of the default slot.
        if not preferred_source.is_empty():
            for raw_candidate in candidates:
                if not raw_candidate is Dictionary:
                    continue
                var candidate: Dictionary = raw_candidate
                if str(candidate.get("source_id", "")) == preferred_source and not _candidate_is_suppressed(candidate):
                    chosen = candidate
                    if _candidate_is_soft_suppressed(candidate):
                        _log_explicit_soft_route(target_id, candidate)
                    break

        if chosen.is_empty():
            var fallback: Dictionary = {}
            var soft_candidates: Array[Dictionary] = []

            for raw_candidate in candidates:
                if not raw_candidate is Dictionary:
                    continue
                var candidate: Dictionary = raw_candidate
                if _candidate_is_suppressed(candidate):
                    continue

                if fallback.is_empty():
                    fallback = candidate

                if _candidate_is_soft_suppressed(candidate):
                    soft_candidates.append(candidate)
                    continue

                if chosen.is_empty():
                    chosen = candidate

            var fallback_used := false
            if chosen.is_empty() and not fallback.is_empty():
                chosen = fallback
                fallback_used = true

            if not soft_candidates.is_empty() and not chosen.is_empty():
                _log_default_suppression(target_id, soft_candidates, chosen, fallback_used)
            else:
                _last_suppression_signature_by_target.erase(target_id)

        if chosen.is_empty():
            _preferred_source_by_target.erase(target_id)
            _last_suppression_signature_by_target.erase(target_id)
            continue

        _preferred_source_by_target[target_id] = str(chosen.get("source_id", ""))
        adjusted[target_id] = _recommendation_from_candidate(chosen)

    return adjusted


func _recommendation_from_candidate(candidate: Dictionary) -> Dictionary:
    var recommendation: Dictionary = super._recommendation_from_candidate(candidate)
    var preference: Dictionary = candidate.get("player_preference", {})
    var adjustment := float(preference.get("adjustment", 0.0))
    var suppression: Dictionary = candidate.get("recommendation_suppression", {})
    var reasons: Array = recommendation.get("reasons", [])

    if abs(adjustment) > 0.01:
        reasons.append("Your learned choices adjust this semantic route by %+.2f advisory point(s); legality and live Accept guards still take priority." % adjustment)

    if bool(suppression.get("soft_suppressed", false)):
        reasons.append("Repeated negative feedback normally keeps this legal route out of the default suggestion slot; you can still inspect or choose it explicitly.")

    recommendation["reasons"] = reasons
    recommendation["player_preference"] = preference.duplicate(true)
    recommendation["recommendation_suppression"] = suppression.duplicate(true)
    return recommendation


func _on_find_different_pressed() -> void:
    var before := _current_recommendation().duplicate(true)
    super._on_find_different_pressed()
    if not before.is_empty():
        _record_preference("record_alternate", before)


func _on_no_thanks_pressed() -> void:
    var before := _current_recommendation().duplicate(true)
    super._on_no_thanks_pressed()
    if not before.is_empty():
        _record_preference("record_rejection", before)


func _on_accept_pressed() -> void:
    var before := _current_recommendation().duplicate(true)
    super._on_accept_pressed()

    if before.is_empty() or not is_instance_valid(_connection_controller):
        return
    if not _connection_controller.has_method("get_last_accept_snapshot"):
        return

    var raw_snapshot = _connection_controller.call("get_last_accept_snapshot")
    if raw_snapshot is Dictionary:
        var snapshot: Dictionary = raw_snapshot
        if _snapshot_matches_recommendation(snapshot, before):
            _record_preference("record_accept", before)


func _on_undo_pressed() -> void:
    var before_snapshot: Dictionary = {}
    if is_instance_valid(_connection_controller) and _connection_controller.has_method("get_last_accept_snapshot"):
        var raw_before = _connection_controller.call("get_last_accept_snapshot")
        if raw_before is Dictionary:
            before_snapshot = raw_before.duplicate(true)

    super._on_undo_pressed()

    if before_snapshot.is_empty() or not is_instance_valid(_connection_controller):
        return
    if not _connection_controller.has_method("get_last_accept_snapshot"):
        return

    var raw_after = _connection_controller.call("get_last_accept_snapshot")
    if raw_after is Dictionary:
        var after_snapshot: Dictionary = raw_after
        if after_snapshot.is_empty():
            _record_preference("record_undo", before_snapshot)


func _record_preference(method_name: String, record: Dictionary) -> void:
    if not is_instance_valid(_preference_model):
        return
    if not _preference_model.has_method(method_name):
        return

    var result = _preference_model.call(method_name, record)
    if result is Dictionary:
        print("%s Learned method='%s' key='%s' delta=%s after=%s persistent=%s" % [
            ADAPTIVE_LOG_PREFIX,
            method_name,
            result.get("semantic_key", ""),
            str(result.get("delta", 0.0)),
            str(result.get("after", 0.0)),
            str(result.get("persistent", false))
        ])


func _candidate_is_soft_suppressed(candidate: Dictionary) -> bool:
    var suppression: Dictionary = candidate.get("recommendation_suppression", {})
    return bool(suppression.get("soft_suppressed", false))


func _log_default_suppression(
    target_id: String,
    soft_candidates: Array[Dictionary],
    chosen_candidate: Dictionary,
    fallback_used: bool
) -> void:
    var semantic_keys: Array[String] = []
    var source_ids: Array[String] = []
    var max_negative_events := 0

    for candidate in soft_candidates:
        var suppression: Dictionary = candidate.get("recommendation_suppression", {})
        var semantic_key := str(suppression.get("semantic_key", ""))
        var source_id := str(candidate.get("source_id", ""))
        if not semantic_keys.has(semantic_key):
            semantic_keys.append(semantic_key)
        if not source_ids.has(source_id):
            source_ids.append(source_id)
        max_negative_events = maxi(max_negative_events, int(suppression.get("negative_events", 0)))

    semantic_keys.sort()
    source_ids.sort()
    var signature := "%s|%s|%s|%s" % [
        ",".join(semantic_keys),
        ",".join(source_ids),
        str(chosen_candidate.get("source_id", "")),
        str(fallback_used)
    ]

    if str(_last_suppression_signature_by_target.get(target_id, "")) == signature:
        return

    _last_suppression_signature_by_target[target_id] = signature
    print("%s Default target='%s' soft_candidates=%d soft_sources=%s keys=%s chosen_source='%s' max_negative_events=%d fallback_used=%s default_ineligible=true legal_candidates_retained=true" % [
        SUPPRESSION_LOG_PREFIX,
        target_id,
        soft_candidates.size(),
        JSON.stringify(source_ids),
        JSON.stringify(semantic_keys),
        chosen_candidate.get("source_id", ""),
        max_negative_events,
        str(fallback_used)
    ])


func _log_explicit_soft_route(target_id: String, candidate: Dictionary) -> void:
    var suppression: Dictionary = candidate.get("recommendation_suppression", {})
    print("%s Explicit target='%s' source='%s' key='%s' adjustment=%s negative_events=%d retained_because_player_selected=true" % [
        SUPPRESSION_LOG_PREFIX,
        target_id,
        candidate.get("source_id", ""),
        suppression.get("semantic_key", ""),
        str(suppression.get("adjustment", 0.0)),
        int(suppression.get("negative_events", 0))
    ])


func _on_preference_changed(event: String, semantic_key: String, score: float) -> void:
    _last_suppression_signature_by_target.clear()
    _disarm_reset_all()
    _refresh_preference_diagnostics()

    print("%s Model changed event='%s' key='%s' score=%s" % [
        DIAGNOSTICS_LOG_PREFIX,
        event,
        semantic_key,
        str(score)
    ])


func _refresh_preference_diagnostics() -> void:
    if not is_instance_valid(_diagnostics_summary_label) or not is_instance_valid(_diagnostics_list):
        return

    _diagnostics_list.clear()

    if not is_instance_valid(_preference_model):
        _diagnostics_summary_label.text = "Preference model unavailable."
        _diagnostics_detail_label.text = "No learned preference data is available."
        _diagnostics_selected_key = ""
        _refresh_diagnostic_buttons({}, 0)
        return

    if not _preference_model.has_method("get_persistence_status") or not _preference_model.has_method("get_preference_diagnostics"):
        _diagnostics_summary_label.text = "Preference diagnostics API unavailable."
        _diagnostics_detail_label.text = "This build cannot inspect learned preference data."
        _diagnostics_selected_key = ""
        _refresh_diagnostic_buttons({}, 0)
        return

    var raw_status = _preference_model.call("get_persistence_status")
    var status: Dictionary = raw_status if raw_status is Dictionary else {}
    var raw_records = _preference_model.call("get_preference_diagnostics")
    var records: Array = raw_records if raw_records is Array else []

    var mode := "writable" if bool(status.get("writable", false)) else "read-only"
    var lock_reason := str(status.get("lock_reason", ""))
    var lock_suffix := "" if lock_reason.is_empty() else " | lock=%s" % lock_reason
    _diagnostics_summary_label.text = "Schema %d | learned routes=%d | store=%s%s | stale after %d days" % [
        int(status.get("schema_version", 0)),
        records.size(),
        mode,
        lock_suffix,
        int(status.get("stale_after_days", 0))
    ]

    var selected_index := -1

    for raw_record in records:
        if not raw_record is Dictionary:
            continue
        var record: Dictionary = raw_record
        var semantic_key := str(record.get("semantic_key", ""))
        var marker := "QUIET" if bool(record.get("soft_suppressed", false)) else "ACTIVE"
        var item_index := _diagnostics_list.item_count
        _diagnostics_list.add_item("%+.1f | %s | %s" % [
            float(record.get("score", 0.0)),
            marker,
            semantic_key
        ])
        _diagnostics_list.set_item_metadata(item_index, semantic_key)

        if semantic_key == _diagnostics_selected_key:
            selected_index = item_index

    if _diagnostics_list.item_count == 0:
        _diagnostics_selected_key = ""
        _diagnostics_detail_label.text = "No learned semantic preferences are currently stored."
    else:
        if selected_index < 0:
            selected_index = 0
            _diagnostics_selected_key = str(_diagnostics_list.get_item_metadata(0))
        _diagnostics_list.select(selected_index)
        _render_selected_preference_detail()

    _refresh_diagnostic_buttons(status, records.size())


func _refresh_diagnostic_buttons(status: Dictionary, record_count: int) -> void:
    var writable := bool(status.get("writable", false))
    var reset_allowed := bool(status.get("reset_allowed", true))
    var lock_reason := str(status.get("lock_reason", ""))

    if is_instance_valid(_diagnostics_reset_selected_button):
        _diagnostics_reset_selected_button.disabled = _diagnostics_selected_key.is_empty() or not writable

    if is_instance_valid(_diagnostics_reset_all_button):
        var has_recoverable_state := record_count > 0 or not lock_reason.is_empty()
        _diagnostics_reset_all_button.disabled = not reset_allowed or not has_recoverable_state


func _render_selected_preference_detail() -> void:
    if not is_instance_valid(_diagnostics_detail_label):
        return

    var record := _diagnostic_record_for_key(_diagnostics_selected_key)
    if record.is_empty():
        _diagnostics_detail_label.text = "Select a learned preference to inspect it."
        return

    var events: Dictionary = record.get("events", {})
    var suppression_text := "soft-suppressed from the default suggestion slot" if bool(record.get("soft_suppressed", false)) else "not soft-suppressed"
    var age_days := int(record.get("age_days", 0))
    var age_text := "today" if age_days <= 0 else "%d day(s) ago" % age_days

    _diagnostics_detail_label.text = "Key: %s\nScore: %+.2f | Negative events: %d | %s\nEvents: %s\nLast event: %s | event index: %d | updated: %s" % [
        record.get("semantic_key", ""),
        float(record.get("score", 0.0)),
        int(record.get("negative_events", 0)),
        suppression_text,
        _format_event_counts(events),
        record.get("last_event", ""),
        int(record.get("event_index", 0)),
        age_text
    ]


func _diagnostic_record_for_key(semantic_key: String) -> Dictionary:
    if semantic_key.is_empty() or not is_instance_valid(_preference_model):
        return {}
    if not _preference_model.has_method("get_preference_diagnostics"):
        return {}

    var raw_records = _preference_model.call("get_preference_diagnostics")
    if not raw_records is Array:
        return {}

    for raw_record in raw_records:
        if not raw_record is Dictionary:
            continue
        var record: Dictionary = raw_record
        if str(record.get("semantic_key", "")) == semantic_key:
            return record
    return {}


func _format_event_counts(events: Dictionary) -> String:
    var keys: Array[String] = []
    var parts: Array[String] = []

    for raw_key in events.keys():
        keys.append(str(raw_key))
    keys.sort()

    for key in keys:
        parts.append("%s=%d" % [key, int(events.get(key, 0))])

    return "none" if parts.is_empty() else ", ".join(parts)


func _on_preference_item_selected(index: int) -> void:
    if not is_instance_valid(_diagnostics_list):
        return
    if index < 0 or index >= _diagnostics_list.item_count:
        return

    _diagnostics_selected_key = str(_diagnostics_list.get_item_metadata(index))
    _disarm_reset_all()
    _render_selected_preference_detail()

    if is_instance_valid(_preference_model) and _preference_model.has_method("get_persistence_status"):
        var raw_status = _preference_model.call("get_persistence_status")
        var status: Dictionary = raw_status if raw_status is Dictionary else {}
        _refresh_diagnostic_buttons(status, _diagnostics_list.item_count)


func _on_refresh_preferences_pressed() -> void:
    _disarm_reset_all()
    _refresh_preference_diagnostics()
    _set_status("Preference diagnostics refreshed. No topology was changed.")
    print("%s Action='refresh'" % DIAGNOSTICS_LOG_PREFIX)


func _on_reset_selected_preference_pressed() -> void:
    if _diagnostics_selected_key.is_empty() or not is_instance_valid(_preference_model):
        return
    if not _preference_model.has_method("reset_preference"):
        _set_status("Preference reset API is unavailable; nothing was changed.")
        return

    var key := _diagnostics_selected_key
    var raw_result = _preference_model.call("reset_preference", key)
    var result: Dictionary = raw_result if raw_result is Dictionary else {}
    var ok := bool(result.get("ok", false))

    print("%s Action='reset_selected' key='%s' ok=%s code='%s' topology_changed=false" % [
        DIAGNOSTICS_LOG_PREFIX,
        key,
        str(ok),
        result.get("code", "invalid_result")
    ])

    if ok:
        _diagnostics_selected_key = ""
        _last_suppression_signature_by_target.clear()
        _set_status("Reset the selected learned preference. Topology was not changed; ranking will refresh on the next scoring sample.")
    else:
        _set_status("Could not reset the selected preference (%s). Nothing was changed." % result.get("code", "unknown"))

    _refresh_preference_diagnostics()


func _on_reset_all_preferences_pressed() -> void:
    if not is_instance_valid(_diagnostics_reset_all_button) or not is_instance_valid(_preference_model):
        return

    if not _reset_all_armed:
        _reset_all_armed = true
        _diagnostics_reset_all_button.text = "Confirm Reset All"
        _set_status("Press Confirm Reset All to erase every learned preference. Topology will not change.")
        print("%s Action='reset_all_arm' topology_changed=false" % DIAGNOSTICS_LOG_PREFIX)
        return

    _reset_all_armed = false
    _diagnostics_reset_all_button.text = "Reset All"

    if not _preference_model.has_method("reset_persistent_preferences"):
        _set_status("Preference reset API is unavailable; nothing was changed.")
        return

    var raw_result = _preference_model.call("reset_persistent_preferences")
    var result: Dictionary = raw_result if raw_result is Dictionary else {}
    var ok := bool(result.get("ok", false))

    print("%s Action='reset_all_confirm' ok=%s code='%s' topology_changed=false" % [
        DIAGNOSTICS_LOG_PREFIX,
        str(ok),
        result.get("code", "invalid_result")
    ])

    if ok:
        _diagnostics_selected_key = ""
        _preferred_source_by_target.clear()
        _last_suppression_signature_by_target.clear()
        _set_status("All learned preferences were reset. Topology was not changed; ranking will refresh on the next scoring sample.")
    else:
        _set_status("Could not reset all preferences (%s). Nothing was changed." % result.get("code", "unknown"))

    _refresh_preference_diagnostics()


func _disarm_reset_all() -> void:
    _reset_all_armed = false
    if is_instance_valid(_diagnostics_reset_all_button):
        _diagnostics_reset_all_button.text = "Reset All"


func _find_descendant_by_name(node: Node, wanted_name: String):
    if node.name == wanted_name:
        return node

    for child in node.get_children():
        var found = _find_descendant_by_name(child, wanted_name)
        if found != null:
            return found
    return null


func _snapshot_matches_recommendation(snapshot: Dictionary, recommendation: Dictionary) -> bool:
    return (
        str(snapshot.get("source_id", "")) == str(recommendation.get("source_id", ""))
        and str(snapshot.get("target_id", "")) == str(recommendation.get("target_id", ""))
        and str(snapshot.get("resource", "")) == str(recommendation.get("resource", ""))
    )
