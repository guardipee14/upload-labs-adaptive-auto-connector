extends "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/ui/connector_highlight_presenter.gd"

const INTERACTION_LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Interaction]"
const INTERACTIVE_WINDOW_HEIGHT := 840.0

var _scorer_provider: Node = null
var _connection_controller: Node = null
var _current_guard: Dictionary = {}
var _preferred_source_by_target: Dictionary = {}
var _suppressed_pairs: Dictionary = {}

var _status_label: Label = null
var _accept_button: Button = null
var _different_button: Button = null
var _no_thanks_button: Button = null
var _undo_button: Button = null


func set_interaction_services(scorer: Node, connection_controller: Node) -> void:
    _scorer_provider = scorer
    _connection_controller = connection_controller
    _refresh_guard_and_actions()


func consume_recommendations(recommendations: Dictionary, sample_index: int) -> void:
    var adjusted := _apply_session_choices(recommendations)
    super.consume_recommendations(adjusted, sample_index)
    _refresh_guard_and_actions()


func _build_advisor_window(menus: Node) -> void:
    super._build_advisor_window(menus)
    if not is_instance_valid(_window):
        return

    _window.custom_minimum_size = Vector2(WINDOW_WIDTH, INTERACTIVE_WINDOW_HEIGHT)
    _window.offset_top = -INTERACTIVE_WINDOW_HEIGHT / 2.0
    _window.offset_bottom = INTERACTIVE_WINDOW_HEIGHT / 2.0

    _replace_read_only_banner(_window)

    if not is_instance_valid(_locate_target_button) or not is_instance_valid(_previous_button):
        return

    var locate_row: Node = _locate_target_button.get_parent()
    var navigation_row: Node = _previous_button.get_parent()
    if locate_row == null or navigation_row == null:
        return

    var column: Node = locate_row.get_parent()
    if column == null or not column is VBoxContainer:
        return
    if navigation_row.get_parent() != column:
        return

    # Keep the recommendation details scrollable while the player-action footer
    # remains visible. This prevents the new controls from expanding the native
    # menu below shorter/scaled viewports.
    var original_children := column.get_children()
    var content_scroll := ScrollContainer.new()
    content_scroll.name = "InteractionContentScroll"
    content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    column.add_child(content_scroll)
    column.move_child(content_scroll, 0)

    var content_column := VBoxContainer.new()
    content_column.name = "InteractionContent"
    content_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_column.add_theme_constant_override("separation", 10)
    content_scroll.add_child(content_column)

    for child in original_children:
        if child == locate_row or child == navigation_row:
            continue
        child.reparent(content_column)

    (column as VBoxContainer).add_theme_constant_override("separation", 8)

    for child in locate_row.get_children():
        if child is Button:
            var locate_button := child as Button
            locate_button.custom_minimum_size = Vector2(200.0, 52.0)
            locate_button.add_theme_font_size_override("font_size", 20)

    for child in navigation_row.get_children():
        if child is Button:
            var navigation_button := child as Button
            navigation_button.custom_minimum_size = Vector2(120.0, 52.0)
            navigation_button.add_theme_font_size_override("font_size", 20)

    _status_label = Label.new()
    _status_label.text = "No topology changes happen unless you press Accept connection."
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.add_theme_font_size_override("font_size", 18)
    column.add_child(_status_label)
    column.move_child(_status_label, 1)

    var primary_actions := HBoxContainer.new()
    primary_actions.name = "PlayerActions"
    primary_actions.alignment = BoxContainer.ALIGNMENT_CENTER
    primary_actions.add_theme_constant_override("separation", 8)
    column.add_child(primary_actions)
    column.move_child(primary_actions, 2)

    _accept_button = _make_text_button(
        "Accept connection",
        "Revalidate the exact displayed route against live topology and create only that one connection."
    )
    _accept_button.custom_minimum_size = Vector2(165.0, 52.0)
    _accept_button.add_theme_font_size_override("font_size", 20)
    _accept_button.pressed.connect(_on_accept_pressed)
    primary_actions.add_child(_accept_button)

    _different_button = _make_text_button(
        "Find different way",
        "Show the next legal ranked source for this same target. No topology change is made."
    )
    _different_button.custom_minimum_size = Vector2(180.0, 52.0)
    _different_button.add_theme_font_size_override("font_size", 20)
    _different_button.pressed.connect(_on_find_different_pressed)
    primary_actions.add_child(_different_button)

    _no_thanks_button = _make_text_button(
        "No thank you",
        "Suppress this source-target recommendation for this play session and show another option if available."
    )
    _no_thanks_button.custom_minimum_size = Vector2(145.0, 52.0)
    _no_thanks_button.add_theme_font_size_override("font_size", 20)
    _no_thanks_button.pressed.connect(_on_no_thanks_pressed)
    primary_actions.add_child(_no_thanks_button)

    _undo_button = _make_text_button(
        "Undo Last Accept",
        "Remove only the last connection created through Adaptive Auto Connector, if that exact connection still exists."
    )
    _undo_button.custom_minimum_size = Vector2(170.0, 52.0)
    _undo_button.add_theme_font_size_override("font_size", 20)
    _undo_button.pressed.connect(_on_undo_pressed)
    primary_actions.add_child(_undo_button)

    # Place locate/navigation rows after the fixed action row. The content above
    # them can scroll, but every player-control button remains on-screen.
    column.move_child(locate_row, 3)
    column.move_child(navigation_row, 4)

    _refresh_guard_and_actions()


func _render_current() -> void:
    super._render_current()
    _refresh_guard_and_actions()


func _render_empty_state() -> void:
    super._render_empty_state()
    _current_guard.clear()
    _refresh_action_buttons()


func _replace_read_only_banner(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            var label := child as Label
            if label.text.begins_with("READ-ONLY PREVIEW"):
                label.text = "PLAYER-CONTROLLED  •  only Accept connection can change topology"
                return
        _replace_read_only_banner(child)


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

        if not preferred_source.is_empty():
            for raw_candidate in candidates:
                if not raw_candidate is Dictionary:
                    continue
                var candidate: Dictionary = raw_candidate
                if str(candidate.get("source_id", "")) == preferred_source and not _candidate_is_suppressed(candidate):
                    chosen = candidate
                    break

        if chosen.is_empty():
            for raw_candidate in candidates:
                if not raw_candidate is Dictionary:
                    continue
                var candidate: Dictionary = raw_candidate
                if not _candidate_is_suppressed(candidate):
                    chosen = candidate
                    break

        if chosen.is_empty():
            _preferred_source_by_target.erase(target_id)
            continue

        _preferred_source_by_target[target_id] = str(chosen.get("source_id", ""))
        adjusted[target_id] = _recommendation_from_candidate(chosen)

    return adjusted


func _get_scored_snapshot() -> Dictionary:
    if not is_instance_valid(_scorer_provider):
        return {}
    if not _scorer_provider.has_method("get_scored_candidates"):
        return {}

    var value = _scorer_provider.call("get_scored_candidates")
    if value is Dictionary:
        return value
    return {}


func _current_candidates() -> Array:
    var target_id := _current_target_id()
    if target_id.is_empty():
        return []

    var scored := _get_scored_snapshot()
    var raw = scored.get(target_id, [])
    if raw is Array:
        return raw
    return []


func _recommendation_from_candidate(candidate: Dictionary) -> Dictionary:
    var reasons: Array[String] = []
    var resource := str(candidate.get("resource", ""))
    var outputs: int = int(candidate.get("source_outputs", 0))
    var production = candidate.get("source_production", null)
    var ratio = candidate.get("observed_capacity_ratio", null)
    var tie_count: int = int(candidate.get("top_tie_count", 1))
    var selection_state := str(candidate.get("selection_state", "not_top"))

    reasons.append("The game currently reports this source-target pair as connectable for '%s'." % resource)
    reasons.append("The target is currently unserved, so accepting this route does not replace an existing player input route.")
    reasons.append("The source currently has %d existing output route(s); route sharing is included in the advisory score." % outputs)

    if production is int or production is float:
        if float(production) > 0.000001:
            reasons.append("Positive source production was observed in the scoring sample.")

    if ratio is int or ratio is float:
        reasons.append("Observed production/required ratio is %.3fx and remains only a capped provisional capacity hint." % float(ratio))

    if selection_state == "tied_top" and tie_count > 1:
        reasons.append("%d candidates share the same top advisory score; this option is not proven better than its tied alternatives." % tie_count)
    elif selection_state == "not_top":
        reasons.append("You asked for a different way, so this is a lower-ranked legal alternative rather than the current top advisory choice.")

    reasons.append("Accept performs a fresh live revalidation and refuses if the displayed route changed since it was shown.")
    reasons.append("Player intent remains authoritative.")

    return {
        "target_id": str(candidate.get("target_id", "")),
        "target_window": str(candidate.get("target_window", "")),
        "target_name": str(candidate.get("target_name", "")),
        "source_id": str(candidate.get("source_id", "")),
        "source_window": str(candidate.get("source_window", "")),
        "source_name": str(candidate.get("source_name", "")),
        "resource": resource,
        "advisory_score": float(candidate.get("advisory_score", 0.0)),
        "confidence": str(candidate.get("confidence", "low")),
        "selection_state": selection_state,
        "top_tie_count": tie_count,
        "score_gap_to_next": candidate.get("score_gap_to_next", null),
        "route_preservation": candidate.get("route_preservation", {}),
        "trusted_manager_metrics": candidate.get("trusted_manager_metrics", {}),
        "reasons": reasons,
        "safety": "player_controlled_accept_revalidates"
    }


func _refresh_guard_and_actions() -> void:
    _current_guard.clear()

    if is_instance_valid(_connection_controller):
        var recommendation := _current_recommendation()
        if not recommendation.is_empty() and _connection_controller.has_method("capture_guard"):
            var value = _connection_controller.call("capture_guard", recommendation, _latest_sample_index)
            if value is Dictionary:
                _current_guard = value

    _refresh_action_buttons()


func _refresh_action_buttons() -> void:
    var has_recommendation := not _current_recommendation().is_empty()
    var guard_valid := bool(_current_guard.get("valid", false))

    if is_instance_valid(_accept_button):
        _accept_button.disabled = not has_recommendation or not guard_valid or not is_instance_valid(_connection_controller)

    if is_instance_valid(_different_button):
        _different_button.disabled = _available_unsuppressed_candidates().size() <= 1

    if is_instance_valid(_no_thanks_button):
        _no_thanks_button.disabled = not has_recommendation

    if is_instance_valid(_undo_button):
        var can_undo := false
        if is_instance_valid(_connection_controller) and _connection_controller.has_method("can_undo_last_accept"):
            can_undo = bool(_connection_controller.call("can_undo_last_accept"))
        _undo_button.disabled = not can_undo


func _available_unsuppressed_candidates() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for raw_candidate in _current_candidates():
        if not raw_candidate is Dictionary:
            continue
        var candidate: Dictionary = raw_candidate
        if not _candidate_is_suppressed(candidate):
            result.append(candidate)
    return result


func _on_find_different_pressed() -> void:
    var current := _current_recommendation()
    if current.is_empty():
        return

    var candidates := _available_unsuppressed_candidates()
    if candidates.size() <= 1:
        _set_status("No different legal source is currently available for this target.")
        return

    var current_source := str(current.get("source_id", ""))
    var current_index := -1
    for index in range(candidates.size()):
        if str(candidates[index].get("source_id", "")) == current_source:
            current_index = index
            break

    var next_index := 0
    if current_index >= 0:
        next_index = (current_index + 1) % candidates.size()

    var next_candidate: Dictionary = candidates[next_index]
    var target_id := _current_target_id()
    _preferred_source_by_target[target_id] = str(next_candidate.get("source_id", ""))
    _recommendations[target_id] = _recommendation_from_candidate(next_candidate)
    _set_status("Showing a different legal route for this same target. No connection was changed.")
    _render_current()

    print("%s Action='find_different' target='%s' source='%s' candidates=%d" % [
        INTERACTION_LOG_PREFIX,
        target_id,
        next_candidate.get("source_id", ""),
        candidates.size()
    ])


func _on_no_thanks_pressed() -> void:
    var current := _current_recommendation()
    if current.is_empty():
        return

    var pair_key := _pair_key_from_recommendation(current)
    _suppressed_pairs[pair_key] = true

    var target_id := _current_target_id()
    var candidates := _available_unsuppressed_candidates()

    print("%s Action='no_thanks' target='%s' source='%s' suppression='session_context' remaining=%d" % [
        INTERACTION_LOG_PREFIX,
        target_id,
        current.get("source_id", ""),
        candidates.size()
    ])

    if not candidates.is_empty():
        var next_candidate: Dictionary = candidates[0]
        _preferred_source_by_target[target_id] = str(next_candidate.get("source_id", ""))
        _recommendations[target_id] = _recommendation_from_candidate(next_candidate)
        _set_status("That source-target suggestion is suppressed for this play session. Showing another option.")
        _render_current()
        return

    _preferred_source_by_target.erase(target_id)
    _recommendations.erase(target_id)
    _target_ids.erase(target_id)
    if _target_ids.is_empty():
        _current_index = 0
        _render_empty_state()
    else:
        _current_index = clampi(_current_index, 0, _target_ids.size() - 1)
        _render_current()
    _set_status("That recommendation context is suppressed for this play session; no alternatives remain for that target.")


func _on_accept_pressed() -> void:
    if not is_instance_valid(_connection_controller):
        _set_status("Connection controller is unavailable; nothing was changed.")
        return

    var recommendation := _current_recommendation()
    if recommendation.is_empty():
        return

    var target_id := _current_target_id()
    var result = _connection_controller.call("accept", recommendation, _current_guard)
    if not result is Dictionary:
        _set_status("Accept returned an invalid result; nothing further was attempted.")
        return

    var result_dict: Dictionary = result
    if bool(result_dict.get("ok", false)):
        _set_status("Connected exactly as approved. Undo Last Accept is now available.")
        _clear_connector_highlight()
        _remove_target_from_view(target_id)
    else:
        _current_guard.clear()
        _set_status("Accept refused: %s" % str(result_dict.get("message", "live topology changed")))

    _refresh_action_buttons()
    print("%s Action='accept' target='%s' source='%s' ok=%s code='%s'" % [
        INTERACTION_LOG_PREFIX,
        target_id,
        recommendation.get("source_id", ""),
        str(result_dict.get("ok", false)),
        result_dict.get("code", "")
    ])


func _on_undo_pressed() -> void:
    if not is_instance_valid(_connection_controller):
        return

    var result = _connection_controller.call("undo_last_accept")
    if not result is Dictionary:
        return

    var result_dict: Dictionary = result
    if bool(result_dict.get("ok", false)):
        _set_status("Last accepted connection was removed. The advisor will re-evaluate it on the next sample.")
    else:
        _set_status("Undo refused: %s" % str(result_dict.get("message", "state changed")))

    _refresh_action_buttons()
    print("%s Action='undo_last_accept' ok=%s code='%s'" % [
        INTERACTION_LOG_PREFIX,
        str(result_dict.get("ok", false)),
        result_dict.get("code", "")
    ])


func _remove_target_from_view(target_id: String) -> void:
    _preferred_source_by_target.erase(target_id)
    _recommendations.erase(target_id)
    _target_ids.erase(target_id)

    if _target_ids.is_empty():
        _current_index = 0
        _render_empty_state()
        return

    _current_index = clampi(_current_index, 0, _target_ids.size() - 1)
    _render_current()


func _candidate_is_suppressed(candidate: Dictionary) -> bool:
    return _suppressed_pairs.has(_pair_key(
        str(candidate.get("target_window", "")),
        str(candidate.get("target_name", "")),
        str(candidate.get("resource", "")),
        str(candidate.get("source_window", "")),
        str(candidate.get("source_name", ""))
    ))


func _is_suppressed(recommendation: Dictionary) -> bool:
    return _suppressed_pairs.has(_pair_key_from_recommendation(recommendation))


func _pair_key_from_recommendation(recommendation: Dictionary) -> String:
    return _pair_key(
        str(recommendation.get("target_window", "")),
        str(recommendation.get("target_name", "")),
        str(recommendation.get("resource", "")),
        str(recommendation.get("source_window", "")),
        str(recommendation.get("source_name", ""))
    )


func _pair_key(
    target_window: String,
    target_name: String,
    resource: String,
    source_window: String,
    source_name: String
) -> String:
    return "%s|%s|%s|%s|%s" % [
        target_window,
        target_name,
        resource,
        source_window,
        source_name
    ]


func _set_status(message: String) -> void:
    if is_instance_valid(_status_label):
        _status_label.text = message
