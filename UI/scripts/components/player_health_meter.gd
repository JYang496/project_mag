extends Control
class_name PlayerHealthMeter

const METER_SIZE := Vector2(310.0, 64.0)
const ICON_CENTER := Vector2(32.0, 32.0)
const ICON_RADIUS := 14.0
const BAR_RECT := Rect2(Vector2(58.0, 22.0), Vector2(190.0, 14.0))
const VALUE_OFFSET := Vector2(254.0, 18.0)
const VALUE_SIZE := Vector2(54.0, 22.0)
const WARNING_RATIO := 0.35
const CRITICAL_RATIO := 0.18
const RECENT_CHANGE_DURATION := 0.85
const DISPLAY_LERP_SPEED := 12.0
const GHOST_LERP_SPEED := 4.5

const SAFE_FILL := Color(0.20, 0.84, 0.52, 0.96)
const SAFE_EDGE := Color(0.58, 1.0, 0.78, 1.0)
const WARNING_FILL := Color(1.0, 0.66, 0.24, 0.98)
const WARNING_EDGE := Color(1.0, 0.86, 0.42, 1.0)
const CRITICAL_FILL := Color(1.0, 0.20, 0.20, 1.0)
const CRITICAL_EDGE := Color(1.0, 0.48, 0.42, 1.0)
const GHOST_FILL := Color(0.48, 0.06, 0.10, 0.72)
const BACK_FILL := Color(0.03, 0.05, 0.06, 0.82)
const BACK_EDGE := Color(0.20, 0.26, 0.27, 0.84)
const EMPTY_CORE := Color(0.05, 0.08, 0.09, 0.88)

var _current_hp: int = 0
var _max_hp: int = 1
var _target_ratio: float = 1.0
var _display_ratio: float = 1.0
var _ghost_ratio: float = 1.0
var _recent_change_timer: float = 0.0
var _pulse_time: float = 0.0
var _health_value_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = METER_SIZE
	size = METER_SIZE
	_ensure_value_label()
	set_process(true)

func set_health(current_hp: int, max_hp: int) -> void:
	var safe_max: int = maxi(1, max_hp)
	var safe_current: int = clampi(current_hp, 0, safe_max)
	var previous_ratio: float = _target_ratio
	_current_hp = safe_current
	_max_hp = safe_max
	_target_ratio = clampf(float(_current_hp) / float(_max_hp), 0.0, 1.0)
	if _target_ratio < previous_ratio:
		_ghost_ratio = maxf(_ghost_ratio, previous_ratio)
	if not is_equal_approx(_target_ratio, previous_ratio):
		_recent_change_timer = RECENT_CHANGE_DURATION
	_update_value_label()
	queue_redraw()

func is_warning() -> bool:
	return _target_ratio <= WARNING_RATIO and _target_ratio > CRITICAL_RATIO

func is_critical() -> bool:
	return _target_ratio <= CRITICAL_RATIO

func is_value_visible() -> bool:
	return _should_show_value()

func get_health_ratio() -> float:
	return _target_ratio

func has_damage_ghost() -> bool:
	return _ghost_ratio > _display_ratio

func _process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	if _recent_change_timer > 0.0:
		_recent_change_timer = maxf(0.0, _recent_change_timer - safe_delta)
	_update_value_label()
	_display_ratio = _approach(_display_ratio, _target_ratio, DISPLAY_LERP_SPEED * safe_delta)
	_ghost_ratio = _approach(_ghost_ratio, _target_ratio, GHOST_LERP_SPEED * safe_delta)
	if _target_ratio <= WARNING_RATIO:
		_pulse_time += safe_delta
		queue_redraw()
	elif not is_equal_approx(_display_ratio, _target_ratio) or not is_equal_approx(_ghost_ratio, _target_ratio):
		queue_redraw()

func _draw() -> void:
	var fill_color: Color = _status_fill_color()
	var edge_color: Color = _status_edge_color()
	var pulse: float = _pulse_strength()
	_draw_core(fill_color, edge_color, pulse)
	_draw_bar(fill_color, edge_color, pulse)

func _draw_core(fill_color: Color, edge_color: Color, pulse: float) -> void:
	var glow_radius: float = ICON_RADIUS + 5.0 + pulse * 5.0
	if pulse > 0.0:
		draw_circle(ICON_CENTER, glow_radius, Color(edge_color.r, edge_color.g, edge_color.b, 0.12 + pulse * 0.20))
	var points := PackedVector2Array([
		ICON_CENTER + Vector2(0.0, -ICON_RADIUS),
		ICON_CENTER + Vector2(ICON_RADIUS, 0.0),
		ICON_CENTER + Vector2(0.0, ICON_RADIUS),
		ICON_CENTER + Vector2(-ICON_RADIUS, 0.0)
	])
	draw_colored_polygon(points, EMPTY_CORE)
	var inner_radius: float = ICON_RADIUS * 0.62
	var inner_points := PackedVector2Array([
		ICON_CENTER + Vector2(0.0, -inner_radius),
		ICON_CENTER + Vector2(inner_radius, 0.0),
		ICON_CENTER + Vector2(0.0, inner_radius),
		ICON_CENTER + Vector2(-inner_radius, 0.0)
	])
	draw_colored_polygon(inner_points, fill_color)
	var border_points := PackedVector2Array([
		points[0],
		points[1],
		points[2],
		points[3],
		points[0]
	])
	draw_polyline(border_points, edge_color, 2.0 + pulse)

func _draw_bar(fill_color: Color, edge_color: Color, pulse: float) -> void:
	# A dark outer rail keeps the value readable over bright battle backgrounds.
	draw_rect(BAR_RECT.grow(2.0), Color(0.01, 0.025, 0.03, 0.92), true)
	draw_rect(BAR_RECT, BACK_FILL, true)
	draw_rect(BAR_RECT, Color(edge_color.r, edge_color.g, edge_color.b, 0.62 + pulse * 0.32), false, 1.5 + pulse)
	if _ghost_ratio > _display_ratio:
		var ghost_rect := Rect2(BAR_RECT.position, Vector2(BAR_RECT.size.x * _ghost_ratio, BAR_RECT.size.y))
		draw_rect(ghost_rect, GHOST_FILL, true)
	if _display_ratio > 0.0:
		var fill_rect := Rect2(BAR_RECT.position, Vector2(BAR_RECT.size.x * _display_ratio, BAR_RECT.size.y))
		draw_rect(fill_rect, fill_color, true)
		var shine_rect := Rect2(fill_rect.position, Vector2(fill_rect.size.x, maxf(2.0, fill_rect.size.y * 0.28)))
		draw_rect(shine_rect, Color(1.0, 1.0, 1.0, 0.16), true)
		draw_line(fill_rect.position + Vector2(1.0, fill_rect.size.y - 1.0), fill_rect.end - Vector2(1.0, 1.0), Color(0.0, 0.0, 0.0, 0.18), 1.0)
	if pulse > 0.0:
		draw_rect(BAR_RECT.grow(3.0), Color(edge_color.r, edge_color.g, edge_color.b, 0.08 + pulse * 0.18), false, 2.0)

func _ensure_value_label() -> void:
	if _health_value_label != null and is_instance_valid(_health_value_label):
		return
	_health_value_label = Label.new()
	_health_value_label.name = "HealthValue"
	_health_value_label.position = VALUE_OFFSET
	_health_value_label.size = VALUE_SIZE
	_health_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_health_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_value_label.add_theme_font_size_override("font_size", 12)
	_health_value_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_health_value_label.add_theme_constant_override("shadow_offset_x", 1)
	_health_value_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_health_value_label)
	_update_value_label()

func _update_value_label() -> void:
	if _health_value_label == null or not is_instance_valid(_health_value_label):
		return
	_health_value_label.text = "%d/%d" % [_current_hp, _max_hp]
	_health_value_label.visible = true
	_health_value_label.add_theme_color_override("font_color", _status_edge_color())

func _should_show_value() -> bool:
	return _target_ratio <= WARNING_RATIO or _recent_change_timer > 0.0

func _status_fill_color() -> Color:
	if _target_ratio <= CRITICAL_RATIO:
		return CRITICAL_FILL
	if _target_ratio <= WARNING_RATIO:
		return WARNING_FILL
	return SAFE_FILL

func _status_edge_color() -> Color:
	if _target_ratio <= CRITICAL_RATIO:
		return CRITICAL_EDGE
	if _target_ratio <= WARNING_RATIO:
		return WARNING_EDGE
	return SAFE_EDGE

func _pulse_strength() -> float:
	if _target_ratio > WARNING_RATIO:
		return 0.0
	var speed: float = 7.5 if _target_ratio <= CRITICAL_RATIO else 4.5
	var base: float = (sin(_pulse_time * speed) + 1.0) * 0.5
	return base * (1.0 if _target_ratio <= CRITICAL_RATIO else 0.55)

func _approach(current: float, target: float, amount: float) -> float:
	if amount <= 0.0:
		return current
	return lerpf(current, target, clampf(amount, 0.0, 1.0))
