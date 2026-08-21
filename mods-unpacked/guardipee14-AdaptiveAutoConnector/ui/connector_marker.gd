extends Control

const TARGET_COLOR := Color(1.0, 0.55, 0.12, 1.0)
const SOURCE_COLOR := Color(0.25, 0.78, 1.0, 1.0)
const INNER_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const EXTRA_MARGIN := 12.0

var _role := "target"


func configure(role: String) -> void:
    _role = role
    queue_redraw()


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_mode = Control.FOCUS_NONE
    z_index = 4096
    set_anchors_preset(Control.PRESET_FULL_RECT)
    offset_left = -EXTRA_MARGIN
    offset_top = -EXTRA_MARGIN
    offset_right = EXTRA_MARGIN
    offset_bottom = EXTRA_MARGIN
    queue_redraw()

    var pulse := create_tween()
    pulse.set_loops()
    pulse.set_trans(Tween.TRANS_SINE)
    pulse.set_ease(Tween.EASE_IN_OUT)
    pulse.tween_property(self, "modulate:a", 0.38, 0.55)
    pulse.tween_property(self, "modulate:a", 1.0, 0.55)


func _draw() -> void:
    var center := size / 2.0
    var min_dimension := minf(size.x, size.y)
    var outer_radius := maxf(8.0, (min_dimension / 2.0) - 2.0)
    var inner_radius := maxf(4.0, outer_radius - 5.0)
    var color := TARGET_COLOR if _role == "target" else SOURCE_COLOR

    draw_circle(center, outer_radius, Color(color.r, color.g, color.b, 0.12))
    draw_arc(center, outer_radius, 0.0, TAU, 48, color, 3.0, true)
    draw_arc(center, inner_radius, 0.0, TAU, 48, INNER_COLOR, 1.5, true)

    var arm := outer_radius + 5.0
    draw_line(center + Vector2(-arm, 0.0), center + Vector2(-inner_radius, 0.0), color, 2.0, true)
    draw_line(center + Vector2(inner_radius, 0.0), center + Vector2(arm, 0.0), color, 2.0, true)
    draw_line(center + Vector2(0.0, -arm), center + Vector2(0.0, -inner_radius), color, 2.0, true)
    draw_line(center + Vector2(0.0, inner_radius), center + Vector2(0.0, arm), color, 2.0, true)
