extends Node

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][UI]"
const PANEL_WIDTH := 430.0
const PANEL_TOP := 24.0
const PANEL_RIGHT := 24.0
const PANEL_HEIGHT := 500.0
const MAX_REASON_LINES := 4

var _recommendations: Dictionary = {}
var _target_ids: Array[String] = []
var _current_index: int = 0
var _latest_sample_index: int = 0
var _user_hidden: bool = false

var _canvas: CanvasLayer = null
var _root: Control = null
var _panel: PanelContainer = null
var _reopen_button: Button = null
var _position_label: Label = null
var _target_label: Label = null
var _route_label: Label = null
var _score_label: Label = null
var _ambiguity_label: Label = null
var _reasons_label: Label = null
var _next_button: Button = null


func _ready() -> void:
    _build_ui()
    _render_empty_state()
    print("%s Presenter ready; read-only preview card created." % LOG_PREFIX)


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
        print("%s Sample index=%d recommendations=0 visible=%s" % [
            LOG_PREFIX,
            sample_index,
            str(not _user_hidden)
        ])
        return

    var preserved_index := _target_ids.find(previous_target_id)
    if preserved_index >= 0:
        _current_index = preserved_index
    else:
        _current_index = clampi(_current_index, 0, _target_ids.size() - 1)

    _render_current()
    print("%s Sample index=%d recommendations=%d current='%s' position=%d/%d visible=%s" % [
        LOG_PREFIX,
        sample_index,
        _target_ids.size(),
        _current_target_id(),
        _current_index + 1,
        _target_ids.size(),
        str(not _user_hidden)
    ])


func _build_ui() -> void:
    _canvas = CanvasLayer.new()
    _canvas.name = "AdaptiveAutoConnectorSuggestionLayer"
    _canvas.layer = 100
    add_child(_canvas)

    _root = Control.new()
    _root.name = "SuggestionRoot"
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _canvas.add_child(_root)

    _panel = PanelContainer.new()
    _panel.name = "SuggestionCard"
    _panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _panel.offset_left = -PANEL_WIDTH - PANEL_RIGHT
    _panel.offset_top = PANEL_TOP
    _panel.offset_right = -PANEL_RIGHT
    _panel.offset_bottom = PANEL_TOP + PANEL_HEIGHT
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.add_child(_panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_bottom", 12)
    _panel.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    margin.add_child(column)

    var title := Label.new()
    title.text = "Adaptive Auto Connector"
    title.add_theme_font_size_override("font_size", 20)
    column.add_child(title)

    var safety := Label.new()
    safety.text = "READ-ONLY PREVIEW · no connections will be changed"
    safety.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(safety)

    column.add_child(HSeparator.new())

    _position_label = Label.new()
    _position_label.text = "Recommendation"
    column.add_child(_position_label)

    _target_label = Label.new()
    _target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _target_label.add_theme_font_size_override("font_size", 17)
    column.add_child(_target_label)

    _route_label = Label.new()
    _route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_route_label)

    _score_label = Label.new()
    _score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_score_label)

    _ambiguity_label = Label.new()
    _ambiguity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_ambiguity_label)

    column.add_child(HSeparator.new())

    var why_title := Label.new()
    why_title.text = "Why this is being suggested"
    column.add_child(why_title)

    _reasons_label = Label.new()
    _reasons_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _reasons_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(_reasons_label)

    var intent := Label.new()
    intent.text = "Player intent > optimizer score"
    intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(intent)

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_END
    buttons.add_theme_constant_override("separation", 8)
    column.add_child(buttons)

    _next_button = Button.new()
    _next_button.text = "Next preview"
    _next_button.tooltip_text = "Cycle to another current recommendation. This does not change the network."
    _next_button.pressed.connect(_on_next_pressed)
    buttons.add_child(_next_button)

    var hide_button := Button.new()
    hide_button.text = "Hide"
    hide_button.tooltip_text = "Hide the preview card."
    hide_button.pressed.connect(_on_hide_pressed)
    buttons.add_child(hide_button)

    _reopen_button = Button.new()
    _reopen_button.name = "AdvisorReopenButton"
    _reopen_button.text = "Advisor"
    _reopen_button.tooltip_text = "Show the Adaptive Auto Connector read-only preview card."
    _reopen_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _reopen_button.offset_left = -120.0 - PANEL_RIGHT
    _reopen_button.offset_top = PANEL_TOP
    _reopen_button.offset_right = -PANEL_RIGHT
    _reopen_button.offset_bottom = PANEL_TOP + 38.0
    _reopen_button.visible = false
    _reopen_button.pressed.connect(_on_reopen_pressed)
    _root.add_child(_reopen_button)


func _render_empty_state() -> void:
    if not is_instance_valid(_panel):
        return

    _position_label.text = "Waiting for recommendation data..."
    _target_label.text = "No current recommendation"
    _route_label.text = "The advisor will populate this card after the next read-only analysis sample."
    _score_label.text = ""
    _ambiguity_label.text = ""
    _reasons_label.text = ""
    _next_button.disabled = true


func _render_current() -> void:
    if _target_ids.is_empty() or not is_instance_valid(_panel):
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

    _position_label.text = "Recommendation %d of %d · sample %d" % [
        _current_index + 1,
        _target_ids.size(),
        _latest_sample_index
    ]
    _target_label.text = "Target: %s / %s" % [target_window, target_name]
    _route_label.text = "Suggested route: %s / %s → %s\nResource: %s" % [
        source_window,
        source_name,
        target_window,
        resource
    ]
    _score_label.text = "Advisory score: %.2f · confidence: %s" % [score, confidence]

    if selection_state == "tied_top" and tie_count > 1:
        _ambiguity_label.text = "TIED TOP: %d candidates share this score. This preview is not proven better than the tied alternatives." % tie_count
    elif _is_number(score_gap):
        _ambiguity_label.text = "UNIQUE TOP: leads the next distinct score by %.2f advisory point(s)." % float(score_gap)
    else:
        _ambiguity_label.text = "UNIQUE TOP: this target currently has one best/only legal candidate at this score."

    _reasons_label.text = _format_reasons(recommendation.get("reasons", []))
    _next_button.disabled = _target_ids.size() <= 1


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


func _on_hide_pressed() -> void:
    _user_hidden = true
    _panel.visible = false
    _reopen_button.visible = true
    print("%s User preview navigation action='hide'" % LOG_PREFIX)


func _on_reopen_pressed() -> void:
    _user_hidden = false
    _panel.visible = true
    _reopen_button.visible = false
    _render_current()
    print("%s User preview navigation action='show'" % LOG_PREFIX)


func _is_number(value) -> bool:
    return value is int or value is float
