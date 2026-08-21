extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][UI]"
const GRAPH_ICON_PATH := "res://textures/icons/graph.png"
const SIDEBAR_PATH := "Main/MainContainer/Overlay/ExtrasButtons/Container"
const MENUS_PATH := "Main/MainContainer/Overlay/Menus"
const WINDOW_WIDTH := 760.0
const WINDOW_HEIGHT := 640.0
const MAX_REASON_LINES := 6

var _recommendations: Dictionary = {}
var _target_ids: Array[String] = []
var _current_index: int = 0
var _latest_sample_index: int = 0
var _native_attached: bool = false

var _hud: Node = null
var _sidebar_button: Button = null
var _window: PanelContainer = null
var _position_label: Label = null
var _target_label: Label = null
var _route_label: Label = null
var _score_label: Label = null
var _ambiguity_label: Label = null
var _reasons_label: Label = null
var _previous_button: Button = null
var _next_button: Button = null


func _ready() -> void:
    var callback := Callable(self, "_on_node_added")
    if not get_tree().node_added.is_connected(callback):
        get_tree().node_added.connect(callback)

    call_deferred("_try_attach_native_ui")
    print("%s Presenter ready; waiting for native Upload Labs HUD." % LOG_PREFIX)


func _exit_tree() -> void:
    var callback := Callable(self, "_on_node_added")
    if get_tree() != null and get_tree().node_added.is_connected(callback):
        get_tree().node_added.disconnect(callback)


func consume_recommendations(recommendations: Dictionary, sample_index: int) -> void:
    var previous_target_id := _current_target_id()

    _recommendations = recommendations.duplicate(true)
    _latest_sample_index = sample_index
    _target_ids.clear()

    for raw_target_id in _recommendations.keys():
        _target_ids.append(str(raw_target_id))
    _target_ids.sort()

    if _target_ids.is_empty():
        _current_index = 0
        _render_empty_state()
        _update_sidebar_tooltip()
        print("%s Sample index=%d recommendations=0 native_attached=%s window_open=%s" % [
            LOG_PREFIX,
            sample_index,
            str(_native_attached),
            str(_is_window_open())
        ])
        return

    var preserved_index: int = _target_ids.find(previous_target_id)
    if preserved_index >= 0:
        _current_index = preserved_index
    else:
        _current_index = clampi(_current_index, 0, _target_ids.size() - 1)

    _render_current()
    _update_sidebar_tooltip()
    print("%s Sample index=%d recommendations=%d current='%s' position=%d/%d native_attached=%s window_open=%s" % [
        LOG_PREFIX,
        sample_index,
        _target_ids.size(),
        _current_target_id(),
        _current_index + 1,
        _target_ids.size(),
        str(_native_attached),
        str(_is_window_open())
    ])


func _on_node_added(node: Node) -> void:
    if _native_attached:
        return

    var node_name := str(node.name)
    if node_name == "Main" or node_name == "HUD" or node_name == "ExtrasButtons" or node_name == "Menus":
        call_deferred("_try_attach_native_ui")


func _try_attach_native_ui() -> void:
    if _native_attached:
        return

    var main: Node = get_tree().root.get_node_or_null("Main")
    if main == null:
        return

    var hud: Node = main.get_node_or_null("HUD")
    if hud == null:
        return

    var sidebar: Node = hud.get_node_or_null(SIDEBAR_PATH)
    var menus: Node = hud.get_node_or_null(MENUS_PATH)
    if sidebar == null or menus == null:
        return

    _hud = hud
    _build_sidebar_button(sidebar)
    _build_advisor_window(menus)
    _connect_peer_sidebar_buttons(sidebar)
    _native_attached = is_instance_valid(_sidebar_button) and is_instance_valid(_window)

    if not _native_attached:
        push_warning("%s Native HUD attach was incomplete." % LOG_PREFIX)
        return

    if not _hud.tree_exiting.is_connected(Callable(self, "_on_native_hud_exiting")):
        _hud.tree_exiting.connect(Callable(self, "_on_native_hud_exiting"))

    _render_current()
    _update_sidebar_tooltip()
    print("%s Native sidebar button attached path='%s'; advisor window attached path='%s'." % [
        LOG_PREFIX,
        SIDEBAR_PATH,
        MENUS_PATH
    ])


func _build_sidebar_button(sidebar: Node) -> void:
    var existing: Node = sidebar.get_node_or_null("AdaptiveAutoConnector")
    if existing is Button:
        _sidebar_button = existing as Button
        return

    _sidebar_button = Button.new()
    _sidebar_button.name = "AdaptiveAutoConnector"
    _sidebar_button.custom_minimum_size = Vector2(80.0, 80.0)
    _sidebar_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _sidebar_button.focus_mode = Control.FOCUS_NONE
    _sidebar_button.theme_type_variation = &"ButtonMenu"
    _sidebar_button.toggle_mode = true
    _sidebar_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _sidebar_button.expand_icon = true
    _sidebar_button.tooltip_text = "Adaptive Auto Connector"

    if ResourceLoader.exists(GRAPH_ICON_PATH):
        var icon_resource = load(GRAPH_ICON_PATH)
        if icon_resource is Texture2D:
            _sidebar_button.icon = icon_resource as Texture2D

    _sidebar_button.pressed.connect(_on_sidebar_pressed)
    sidebar.add_child(_sidebar_button)


func _build_advisor_window(menus: Node) -> void:
    var existing: Node = menus.get_node_or_null("AdaptiveAutoConnector")
    if existing is PanelContainer:
        _window = existing as PanelContainer
        return

    _window = PanelContainer.new()
    _window.name = "AdaptiveAutoConnector"
    _window.custom_minimum_size = Vector2(WINDOW_WIDTH, WINDOW_HEIGHT)
    _window.theme_type_variation = &"ShadowPanelContainer"
    _window.mouse_filter = Control.MOUSE_FILTER_STOP
    _window.visible = false
    menus.add_child(_window)
    _window.set_anchors_preset(Control.PRESET_CENTER)
    _window.offset_left = -WINDOW_WIDTH / 2.0
    _window.offset_top = -WINDOW_HEIGHT / 2.0
    _window.offset_right = WINDOW_WIDTH / 2.0
    _window.offset_bottom = WINDOW_HEIGHT / 2.0

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 0)
    _window.add_child(outer)

    var title_panel := Panel.new()
    title_panel.custom_minimum_size = Vector2(0.0, 80.0)
    title_panel.theme_type_variation = &"OverlayPanelTitle"
    outer.add_child(title_panel)

    var title_margin := MarginContainer.new()
    title_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    title_margin.add_theme_constant_override("margin_left", 18)
    title_margin.add_theme_constant_override("margin_right", 18)
    title_panel.add_child(title_margin)

    var title_row := HBoxContainer.new()
    title_row.alignment = BoxContainer.ALIGNMENT_CENTER
    title_row.add_theme_constant_override("separation", 12)
    title_margin.add_child(title_row)

    if ResourceLoader.exists(GRAPH_ICON_PATH):
        var title_icon_resource = load(GRAPH_ICON_PATH)
        if title_icon_resource is Texture2D:
            var title_icon := TextureRect.new()
            title_icon.custom_minimum_size = Vector2(48.0, 48.0)
            title_icon.texture = title_icon_resource as Texture2D
            title_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
            title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            title_row.add_child(title_icon)

    var title := Label.new()
    title.text = "Adaptive Auto Connector"
    title.add_theme_font_size_override("font_size", 40)
    title_row.add_child(title)

    var body_panel := PanelContainer.new()
    body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body_panel.theme_type_variation = &"MenuPanel"
    outer.add_child(body_panel)

    var body_margin := MarginContainer.new()
    body_margin.add_theme_constant_override("margin_left", 24)
    body_margin.add_theme_constant_override("margin_top", 18)
    body_margin.add_theme_constant_override("margin_right", 24)
    body_margin.add_theme_constant_override("margin_bottom", 18)
    body_panel.add_child(body_margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    body_margin.add_child(column)

    var safety := Label.new()
    safety.text = "READ-ONLY PREVIEW  •  no connections will be changed"
    safety.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    safety.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    safety.add_theme_font_size_override("font_size", 24)
    column.add_child(safety)

    column.add_child(HSeparator.new())

    _position_label = Label.new()
    _position_label.add_theme_font_size_override("font_size", 24)
    column.add_child(_position_label)

    _target_label = Label.new()
    _target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _target_label.add_theme_font_size_override("font_size", 30)
    column.add_child(_target_label)

    _route_label = Label.new()
    _route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _route_label.add_theme_font_size_override("font_size", 26)
    column.add_child(_route_label)

    _score_label = Label.new()
    _score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _score_label.add_theme_font_size_override("font_size", 24)
    column.add_child(_score_label)

    _ambiguity_label = Label.new()
    _ambiguity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _ambiguity_label.add_theme_font_size_override("font_size", 24)
    column.add_child(_ambiguity_label)

    column.add_child(HSeparator.new())

    var why_title := Label.new()
    why_title.text = "Why this is being suggested"
    why_title.add_theme_font_size_override("font_size", 28)
    column.add_child(why_title)

    var reason_scroll := ScrollContainer.new()
    reason_scroll.custom_minimum_size = Vector2(0.0, 190.0)
    reason_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    reason_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    reason_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    column.add_child(reason_scroll)

    _reasons_label = Label.new()
    _reasons_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _reasons_label.add_theme_font_size_override("font_size", 24)
    _reasons_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reason_scroll.add_child(_reasons_label)

    var intent := Label.new()
    intent.text = "Player intent > optimizer score"
    intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intent.add_theme_font_size_override("font_size", 22)
    column.add_child(intent)

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_END
    buttons.add_theme_constant_override("separation", 10)
    column.add_child(buttons)

    _previous_button = _make_text_button("Previous", "Show the previous recommendation.")
    _previous_button.pressed.connect(_on_previous_pressed)
    buttons.add_child(_previous_button)

    _next_button = _make_text_button("Next", "Show the next recommendation.")
    _next_button.pressed.connect(_on_next_pressed)
    buttons.add_child(_next_button)

    var close_button := _make_text_button("Close", "Close the advisor window.")
    close_button.pressed.connect(_on_close_pressed)
    buttons.add_child(close_button)


func _make_text_button(text_value: String, tooltip: String) -> Button:
    var button := Button.new()
    button.text = text_value
    button.tooltip_text = tooltip
    button.custom_minimum_size = Vector2(140.0, 64.0)
    button.focus_mode = Control.FOCUS_NONE
    button.theme_type_variation = &"TabButton"
    button.add_theme_font_size_override("font_size", 24)
    return button


func _connect_peer_sidebar_buttons(sidebar: Node) -> void:
    var callback := Callable(self, "_on_peer_sidebar_pressed")
    for child in sidebar.get_children():
        if child is Button and child != _sidebar_button:
            var peer_button: Button = child as Button
            if not peer_button.pressed.is_connected(callback):
                peer_button.pressed.connect(callback)


func _render_empty_state() -> void:
    if not is_instance_valid(_window) or not is_instance_valid(_position_label):
        return

    _position_label.text = "Waiting for recommendation data..."
    _target_label.text = "No current recommendation"
    _route_label.text = "The advisor will populate after the next read-only analysis sample."
    _score_label.text = ""
    _ambiguity_label.text = ""
    _reasons_label.text = ""
    _previous_button.disabled = true
    _next_button.disabled = true


func _render_current() -> void:
    if not is_instance_valid(_window):
        return

    if _target_ids.is_empty():
        _render_empty_state()
        return

    _current_index = clampi(_current_index, 0, _target_ids.size() - 1)
    var target_id := _target_ids[_current_index]
    var raw_recommendation = _recommendations.get(target_id, {})
    if not raw_recommendation is Dictionary:
        _render_empty_state()
        return

    var recommendation: Dictionary = raw_recommendation
    var target_window := str(recommendation.get("target_window", ""))
    var target_name := str(recommendation.get("target_name", ""))
    var source_window := str(recommendation.get("source_window", ""))
    var source_name := str(recommendation.get("source_name", ""))
    var resource := str(recommendation.get("resource", ""))
    var score: float = float(recommendation.get("advisory_score", 0.0))
    var confidence := str(recommendation.get("confidence", "low"))
    var selection_state := str(recommendation.get("selection_state", "unique_top"))
    var tie_count: int = int(recommendation.get("top_tie_count", 1))
    var score_gap = recommendation.get("score_gap_to_next", null)

    _position_label.text = "Recommendation %d of %d  •  sample %d" % [
        _current_index + 1,
        _target_ids.size(),
        _latest_sample_index
    ]
    _target_label.text = "Target: %s / %s" % [target_window, target_name]
    _route_label.text = "Suggested route: %s / %s → %s / %s\nResource: %s" % [
        source_window,
        source_name,
        target_window,
        target_name,
        resource
    ]
    _score_label.text = "Advisory score: %.2f  •  confidence: %s" % [score, confidence]

    if selection_state == "tied_top" and tie_count > 1:
        _ambiguity_label.text = "TIED TOP  •  %d candidates share this score; this one is not proven better." % tie_count
    elif _is_number(score_gap):
        _ambiguity_label.text = "UNIQUE TOP  •  leads the next distinct score by %.2f advisory point(s)." % float(score_gap)
    else:
        _ambiguity_label.text = "UNIQUE TOP  •  currently the only/best legal candidate at this score."

    _reasons_label.text = _format_reasons(recommendation.get("reasons", []))
    var multiple: bool = _target_ids.size() > 1
    _previous_button.disabled = not multiple
    _next_button.disabled = not multiple


func _format_reasons(raw_reasons) -> String:
    var lines: Array[String] = []
    if raw_reasons is Array:
        for raw_reason in raw_reasons:
            var reason := str(raw_reason)
            if reason.is_empty():
                continue
            lines.append("• %s" % reason)
            if lines.size() >= MAX_REASON_LINES:
                break

    if lines.is_empty():
        return "• No explanation details are available for this sample."

    return "\n".join(lines)


func _current_target_id() -> String:
    if _target_ids.is_empty():
        return ""
    if _current_index < 0 or _current_index >= _target_ids.size():
        return ""
    return _target_ids[_current_index]


func _update_sidebar_tooltip() -> void:
    if not is_instance_valid(_sidebar_button):
        return

    if _target_ids.is_empty():
        _sidebar_button.tooltip_text = "Adaptive Auto Connector — no current recommendations"
    else:
        _sidebar_button.tooltip_text = "Adaptive Auto Connector — %d recommendation(s)" % _target_ids.size()


func _is_window_open() -> bool:
    return is_instance_valid(_window) and _window.visible


func _open_window() -> void:
    if not is_instance_valid(_window):
        return

    _window.visible = true
    if is_instance_valid(_sidebar_button):
        _sidebar_button.button_pressed = true
    _render_current()
    var position: int = _current_index + 1 if not _target_ids.is_empty() else 0
    print("%s User window action='open' current='%s' position=%d/%d" % [
        LOG_PREFIX,
        _current_target_id(),
        position,
        _target_ids.size()
    ])


func _close_window(log_action: bool = true) -> void:
    if is_instance_valid(_window):
        _window.visible = false
    if is_instance_valid(_sidebar_button):
        _sidebar_button.button_pressed = false
    if log_action:
        print("%s User window action='close'" % LOG_PREFIX)


func _on_sidebar_pressed() -> void:
    if not is_instance_valid(_sidebar_button):
        return

    if _sidebar_button.button_pressed:
        _open_window()
    else:
        _close_window()


func _on_peer_sidebar_pressed() -> void:
    if _is_window_open():
        _close_window(false)


func _on_previous_pressed() -> void:
    if _target_ids.size() <= 1:
        return

    _current_index = (_current_index - 1 + _target_ids.size()) % _target_ids.size()
    _render_current()
    print("%s User preview navigation action='previous' current='%s' position=%d/%d" % [
        LOG_PREFIX,
        _current_target_id(),
        _current_index + 1,
        _target_ids.size()
    ])


func _on_next_pressed() -> void:
    if _target_ids.size() <= 1:
        return

    _current_index = (_current_index + 1) % _target_ids.size()
    _render_current()
    print("%s User preview navigation action='next' current='%s' position=%d/%d" % [
        LOG_PREFIX,
        _current_target_id(),
        _current_index + 1,
        _target_ids.size()
    ])


func _on_close_pressed() -> void:
    _close_window()


func _on_native_hud_exiting() -> void:
    _native_attached = false
    _hud = null
    _sidebar_button = null
    _window = null
    _position_label = null
    _target_label = null
    _route_label = null
    _score_label = null
    _ambiguity_label = null
    _reasons_label = null
    _previous_button = null
    _next_button = null
    call_deferred("_try_attach_native_ui")


func _is_number(value) -> bool:
    return value is int or value is float
