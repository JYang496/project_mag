extends Control
class_name CombatResourceMeter

const MODE_AMMO := &"ammo"
const MODE_HEAT := &"heat"
const MODE_CHARGE := &"charge"
const MODE_ENERGY := &"energy"
const MODE_BATTERY := &"battery"
const MODE_PRESSURE := &"pressure"
const METER_SIZE := Vector2(190.0, 18.0)
const ICON_RECT := Rect2(Vector2(0.0, 2.0), Vector2(22.0, 14.0))
const BAR_RECT := Rect2(Vector2(30.0, 5.0), Vector2(112.0, 8.0))
const LABEL_OFFSET := Vector2(148.0, 0.0)
const LABEL_SIZE := Vector2(42.0, 18.0)

const BACK_FILL := Color(0.03, 0.05, 0.06, 0.80)
const BACK_EDGE := Color(0.18, 0.24, 0.27, 0.85)
const EMPTY_ICON_FILL := Color(0.05, 0.08, 0.09, 0.88)
const AMMO_FILL := Color(0.36, 0.76, 1.0, 0.96)
const AMMO_EDGE := Color(0.62, 0.90, 1.0, 1.0)
const AMMO_LOW_FILL := Color(1.0, 0.64, 0.24, 1.0)
const RELOAD_FILL := Color(0.60, 0.66, 1.0, 1.0)
const HEAT_FILL := Color(0.94, 0.58, 0.20, 0.96)
const HEAT_EDGE := Color(1.0, 0.76, 0.34, 1.0)
const HEAT_HIGH_FILL := Color(1.0, 0.34, 0.18, 1.0)
const LOCKED_FILL := Color(1.0, 0.16, 0.12, 1.0)
const CHARGE_FILL := Color(0.58, 0.86, 1.0, 0.98)
const CHARGE_EDGE := Color(0.86, 0.96, 1.0, 1.0)
const ENERGY_FILL := Color(0.58, 0.42, 1.0, 0.96)
const ENERGY_EDGE := Color(0.80, 0.92, 1.0, 1.0)
const BATTERY_FILL := Color(0.54, 0.96, 0.58, 0.96)
const BATTERY_EDGE := Color(0.76, 1.0, 0.72, 1.0)
const PRESSURE_FILL := Color(0.88, 0.78, 0.48, 0.96)
const PRESSURE_EDGE := Color(1.0, 0.92, 0.64, 1.0)

var _mode: StringName = MODE_AMMO
var _ratio: float = 0.0
var _state: StringName = &"normal"
var _short_text: String = ""
var _status_label: Label
var _pulse_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = METER_SIZE
	size = METER_SIZE
	_ensure_status_label()
	set_process(true)

func set_resource(mode: StringName, ratio: float, state: StringName = &"normal", short_text: String = "", tooltip: String = "") -> void:
	_mode = mode
	_ratio = clampf(ratio, 0.0, 1.0)
	_state = state
	_short_text = short_text
	tooltip_text = tooltip
	_update_status_label()
	queue_redraw()

func is_status_visible() -> bool:
	return _short_text != ""

func get_ratio() -> float:
	return _ratio

func _process(delta: float) -> void:
	if _state == &"warning" or _state == &"locked" or _state == &"reloading" or _state == &"charging" or _state == &"cooling":
		_pulse_time += maxf(delta, 0.0)
		queue_redraw()

func _draw() -> void:
	var fill_color: Color = _fill_color()
	var edge_color: Color = _edge_color()
	var pulse: float = _pulse_strength()
	_draw_icon(fill_color, edge_color, pulse)
	_draw_bar(fill_color, edge_color, pulse)

func _draw_icon(fill_color: Color, edge_color: Color, pulse: float) -> void:
	match _mode:
		MODE_HEAT:
			_draw_heat_icon(fill_color, edge_color, pulse)
		MODE_CHARGE, MODE_ENERGY:
			_draw_diamond_icon(fill_color, edge_color, pulse)
		MODE_PRESSURE:
			_draw_gauge_icon(fill_color, edge_color, pulse)
		_:
			_draw_ammo_icon(fill_color, edge_color, pulse)

func _draw_ammo_icon(fill_color: Color, edge_color: Color, pulse: float) -> void:
	var body := Rect2(ICON_RECT.position + Vector2(1.0, 1.0), ICON_RECT.size - Vector2(4.0, 2.0))
	var cap := Rect2(Vector2(ICON_RECT.position.x + ICON_RECT.size.x - 3.0, ICON_RECT.position.y + 5.0), Vector2(3.0, 4.0))
	draw_rect(body, EMPTY_ICON_FILL, true)
	draw_rect(cap, EMPTY_ICON_FILL, true)
	var filled_width: float = maxf(2.0, body.size.x * _ratio)
	draw_rect(Rect2(body.position, Vector2(filled_width, body.size.y)), fill_color, true)
	draw_rect(body, Color(edge_color.r, edge_color.g, edge_color.b, 0.75 + pulse * 0.25), false, 1.2 + pulse)
	draw_rect(cap, Color(edge_color.r, edge_color.g, edge_color.b, 0.75 + pulse * 0.25), false, 1.0)
	for index in range(3):
		var x: float = body.position.x + 4.0 + float(index) * 4.0
		draw_line(Vector2(x, body.position.y + 2.0), Vector2(x, body.position.y + body.size.y - 2.0), Color(1.0, 1.0, 1.0, 0.16), 1.0)

func _draw_heat_icon(fill_color: Color, edge_color: Color, pulse: float) -> void:
	var center := ICON_RECT.position + Vector2(11.0, 8.0)
	if pulse > 0.0:
		draw_circle(center, 9.0 + pulse * 4.0, Color(edge_color.r, edge_color.g, edge_color.b, 0.10 + pulse * 0.16))
	var flame := PackedVector2Array([
		center + Vector2(0.0, -8.0),
		center + Vector2(7.0, -1.0),
		center + Vector2(4.0, 7.0),
		center + Vector2(0.0, 9.0),
		center + Vector2(-5.0, 6.0),
		center + Vector2(-7.0, -1.0)
	])
	draw_colored_polygon(flame, EMPTY_ICON_FILL)
	var inner := PackedVector2Array([
		center + Vector2(0.0, -5.5),
		center + Vector2(4.0, 0.0),
		center + Vector2(2.0, 5.0),
		center + Vector2(-2.0, 5.0),
		center + Vector2(-4.0, 0.0)
	])
	draw_colored_polygon(inner, fill_color)
	var outline := PackedVector2Array([
		flame[0],
		flame[1],
		flame[2],
		flame[3],
		flame[4],
		flame[5],
		flame[0]
	])
	draw_polyline(outline, edge_color, 1.4 + pulse)

func _draw_diamond_icon(fill_color: Color, edge_color: Color, pulse: float) -> void:
	var center := ICON_RECT.position + Vector2(11.0, 8.0)
	if pulse > 0.0:
		draw_circle(center, 9.0 + pulse * 4.0, Color(edge_color.r, edge_color.g, edge_color.b, 0.10 + pulse * 0.16))
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -8.0),
		center + Vector2(8.0, 0.0),
		center + Vector2(0.0, 8.0),
		center + Vector2(-8.0, 0.0),
	])
	draw_colored_polygon(diamond, EMPTY_ICON_FILL)
	var inner := PackedVector2Array([
		center + Vector2(0.0, -5.0),
		center + Vector2(5.0, 0.0),
		center + Vector2(0.0, 5.0),
		center + Vector2(-5.0, 0.0),
	])
	draw_colored_polygon(inner, fill_color)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), edge_color, 1.4 + pulse)

func _draw_gauge_icon(fill_color: Color, edge_color: Color, pulse: float) -> void:
	var center := ICON_RECT.position + Vector2(11.0, 8.0)
	draw_circle(center, 8.0, EMPTY_ICON_FILL)
	draw_arc(center, 8.0, PI, TAU, 16, Color(edge_color.r, edge_color.g, edge_color.b, 0.75 + pulse * 0.25), 1.4 + pulse)
	var angle := lerpf(PI, TAU, _ratio)
	draw_line(center, center + Vector2(cos(angle), sin(angle)) * 6.0, fill_color, 2.0 + pulse)

func _draw_bar(fill_color: Color, edge_color: Color, pulse: float) -> void:
	draw_rect(BAR_RECT, BACK_FILL, true)
	draw_rect(BAR_RECT, Color(edge_color.r, edge_color.g, edge_color.b, 0.48 + pulse * 0.30), false, 1.0 + pulse)
	if _ratio > 0.0:
		var fill_rect := Rect2(BAR_RECT.position, Vector2(BAR_RECT.size.x * _ratio, BAR_RECT.size.y))
		draw_rect(fill_rect, fill_color, true)
		draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, 2.0)), Color(1.0, 1.0, 1.0, 0.14), true)

func _ensure_status_label() -> void:
	if _status_label != null and is_instance_valid(_status_label):
		return
	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.position = LABEL_OFFSET
	_status_label.size = LABEL_SIZE
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 10)
	add_child(_status_label)
	_update_status_label()

func _update_status_label() -> void:
	if _status_label == null or not is_instance_valid(_status_label):
		return
	_status_label.text = _short_text
	_status_label.visible = _short_text != ""
	_status_label.add_theme_color_override("font_color", _edge_color())

func _fill_color() -> Color:
	if _state == &"locked":
		return LOCKED_FILL
	if _mode == MODE_HEAT:
		return HEAT_HIGH_FILL if _state == &"warning" else HEAT_FILL
	if _mode == MODE_CHARGE:
		return CHARGE_FILL
	if _mode == MODE_ENERGY:
		return ENERGY_FILL
	if _mode == MODE_BATTERY:
		return BATTERY_FILL
	if _mode == MODE_PRESSURE:
		return PRESSURE_FILL
	if _state == &"reloading":
		return RELOAD_FILL
	if _state == &"warning":
		return AMMO_LOW_FILL
	return AMMO_FILL

func _edge_color() -> Color:
	if _state == &"locked":
		return LOCKED_FILL
	if _mode == MODE_HEAT:
		return HEAT_HIGH_FILL if _state == &"warning" else HEAT_EDGE
	if _mode == MODE_CHARGE:
		return CHARGE_EDGE
	if _mode == MODE_ENERGY:
		return ENERGY_EDGE
	if _mode == MODE_BATTERY:
		return BATTERY_EDGE
	if _mode == MODE_PRESSURE:
		return PRESSURE_EDGE
	if _state == &"reloading":
		return RELOAD_FILL
	if _state == &"warning":
		return AMMO_LOW_FILL
	return AMMO_EDGE

func _pulse_strength() -> float:
	if not (_state == &"warning" or _state == &"locked" or _state == &"reloading" or _state == &"charging" or _state == &"cooling"):
		return 0.0
	return (sin(_pulse_time * 6.0) + 1.0) * 0.35
