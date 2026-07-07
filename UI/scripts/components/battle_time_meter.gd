extends Control
class_name BattleTimeMeter

const METER_SIZE := Vector2(116.0, 72.0)
const NORMAL_FILL := Color(0.36, 0.82, 1.0, 0.95)
const NORMAL_EDGE := Color(0.70, 0.94, 1.0, 1.0)
const WARNING_FILL := Color(1.0, 0.67, 0.24, 1.0)
const WARNING_EDGE := Color(1.0, 0.84, 0.42, 1.0)
const CRITICAL_FILL := Color(1.0, 0.22, 0.16, 1.0)
const CRITICAL_EDGE := Color(1.0, 0.45, 0.34, 1.0)
const BACK_FILL := Color(0.025, 0.035, 0.045, 0.82)
const BACK_EDGE := Color(0.15, 0.24, 0.28, 0.82)
const INACTIVE_EDGE := Color(0.30, 0.36, 0.38, 0.65)

var _remaining: int = 0
var _duration: int = 1
var _phase: String = ""
var _ratio: float = 0.0
var _state: StringName = &"normal"
var _pulse_time: float = 0.0
var _hit_pulse: float = 0.0
var _digit_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = METER_SIZE
	size = METER_SIZE
	_ensure_digit_label()
	set_process(true)
	queue_redraw()

func set_time(remaining: int, duration: int, phase: String) -> void:
	var safe_duration: int = maxi(duration, 1)
	var safe_remaining: int = clampi(remaining, 0, safe_duration)
	var previous_remaining := _remaining
	_remaining = safe_remaining
	_duration = safe_duration
	_phase = phase
	_ratio = clampf(float(_remaining) / float(_duration), 0.0, 1.0)
	_state = _resolve_state()
	visible = _phase == "battle"
	if previous_remaining != _remaining:
		_hit_pulse = 1.0
	_update_digit_label()
	queue_redraw()

func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if _state == &"warning" or _state == &"critical":
		_pulse_time += safe_delta
	if _hit_pulse > 0.0:
		_hit_pulse = maxf(0.0, _hit_pulse - safe_delta * 4.6)
		_update_digit_label()
	if visible and (_state == &"warning" or _state == &"critical" or _hit_pulse > 0.0):
		queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x * 0.5, 35.0)
	var pulse := _pulse_strength()
	var edge_color := _edge_color()
	var fill_color := _fill_color()
	var radius := 28.0 + pulse * 2.0 + _hit_pulse * 1.8
	_draw_shell(center, radius, edge_color, pulse)
	_draw_progress_ring(center, radius, fill_color, edge_color, pulse)
	_draw_tick_marks(center, radius + 6.0, edge_color)
	_draw_bottom_bar(fill_color, edge_color, pulse)

func _draw_shell(center: Vector2, radius: float, edge_color: Color, pulse: float) -> void:
	var panel_rect := Rect2(Vector2(7.0, 7.0), Vector2(size.x - 14.0, size.y - 14.0))
	draw_rect(panel_rect, BACK_FILL, true)
	draw_rect(panel_rect, Color(edge_color.r, edge_color.g, edge_color.b, 0.42 + pulse * 0.28), false, 1.2 + pulse)
	if pulse > 0.0 or _hit_pulse > 0.0:
		var glow_alpha := 0.10 + pulse * 0.18 + _hit_pulse * 0.12
		draw_circle(center, radius + 8.0, Color(edge_color.r, edge_color.g, edge_color.b, glow_alpha))

func _draw_progress_ring(center: Vector2, radius: float, fill_color: Color, edge_color: Color, pulse: float) -> void:
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, 56, Color(BACK_EDGE.r, BACK_EDGE.g, BACK_EDGE.b, 0.62), 5.0, true)
	var end_angle := -PI * 0.5 + TAU * _ratio
	if _ratio > 0.0:
		draw_arc(center, radius, -PI * 0.5, end_angle, 56, fill_color, 5.4 + pulse, true)
	draw_arc(center, radius + 4.5, -PI * 0.5, PI * 1.5, 64, Color(edge_color.r, edge_color.g, edge_color.b, 0.28 + pulse * 0.2), 1.0, true)

func _draw_tick_marks(center: Vector2, radius: float, edge_color: Color) -> void:
	for index in range(12):
		var angle := -PI * 0.5 + TAU * (float(index) / 12.0)
		var from_point := center + Vector2(cos(angle), sin(angle)) * (radius - 3.0)
		var to_point := center + Vector2(cos(angle), sin(angle)) * radius
		var active := float(index) / 12.0 <= _ratio
		var color := edge_color if active else INACTIVE_EDGE
		draw_line(from_point, to_point, color, 1.2)

func _draw_bottom_bar(fill_color: Color, edge_color: Color, pulse: float) -> void:
	var bar_rect := Rect2(Vector2(18.0, size.y - 13.0), Vector2(size.x - 36.0, 4.0))
	draw_rect(bar_rect, Color(0.04, 0.06, 0.07, 0.90), true)
	draw_rect(bar_rect, Color(edge_color.r, edge_color.g, edge_color.b, 0.45 + pulse * 0.24), false, 1.0)
	if _ratio > 0.0:
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * _ratio, bar_rect.size.y)), fill_color, true)

func _ensure_digit_label() -> void:
	if _digit_label != null and is_instance_valid(_digit_label):
		return
	_digit_label = Label.new()
	_digit_label.name = "Digits"
	_digit_label.position = Vector2(22.0, 13.0)
	_digit_label.size = Vector2(72.0, 44.0)
	_digit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_digit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_digit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_digit_label.add_theme_font_size_override("font_size", 30)
	_digit_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	_digit_label.add_theme_constant_override("shadow_offset_x", 1)
	_digit_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_digit_label)
	_update_digit_label()

func _update_digit_label() -> void:
	if _digit_label == null or not is_instance_valid(_digit_label):
		return
	_digit_label.text = str(_remaining)
	_digit_label.add_theme_color_override("font_color", _edge_color())
	var scale_value := 1.0 + _hit_pulse * (0.18 if _state == &"critical" else 0.10)
	_digit_label.pivot_offset = _digit_label.size * 0.5
	_digit_label.scale = Vector2(scale_value, scale_value)

func _resolve_state() -> StringName:
	if _remaining <= 5:
		return &"critical"
	if _remaining <= 10:
		return &"warning"
	return &"normal"

func _fill_color() -> Color:
	if _state == &"critical":
		return CRITICAL_FILL
	if _state == &"warning":
		return WARNING_FILL
	return NORMAL_FILL

func _edge_color() -> Color:
	if _state == &"critical":
		return CRITICAL_EDGE
	if _state == &"warning":
		return WARNING_EDGE
	return NORMAL_EDGE

func _pulse_strength() -> float:
	if _state == &"critical":
		return (sin(_pulse_time * 10.0) + 1.0) * 0.5
	if _state == &"warning":
		return (sin(_pulse_time * 6.0) + 1.0) * 0.25
	return 0.0
