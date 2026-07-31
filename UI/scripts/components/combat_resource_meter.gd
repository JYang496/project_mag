extends Control
class_name CombatResourceMeter

const MODE_AMMO := &"ammo"
const MODE_HEAT := &"heat"
const MODE_CHARGE := &"charge"
const MODE_ENERGY := &"energy"
const MODE_BATTERY := &"battery"
const MODE_PRESSURE := &"pressure"
const METER_SIZE := Vector2(250.0, 20.0)
const HEAT_GAUGE_SIZE := Vector2(152.0, 152.0)
const HEAT_GAUGE_PIVOT := HEAT_GAUGE_SIZE * 0.5
const HEAT_NEEDLE_MIN_DEGREES := -143.0
const HEAT_NEEDLE_MAX_DEGREES := 143.0
const HEAT_GAUGE_TEXTURE := preload("res://UI/themes/modern/heat_gauge.png")
const HEAT_NEEDLE_TEXTURE := preload("res://UI/themes/modern/heat_needle.png")
const ICON_RECT := Rect2(Vector2(0.0, 2.0), Vector2(22.0, 14.0))
const BAR_RECT := Rect2(Vector2(30.0, 5.0), Vector2(160.0, 10.0))
const LABEL_OFFSET := Vector2(196.0, 0.0)
const LABEL_SIZE := Vector2(52.0, 20.0)
const DISPLAY_LERP_SPEED := 14.0

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
const COLD_FILL := Color(0.30, 0.72, 1.0, 0.96)
const DEEP_COLD_FILL := Color(0.52, 0.90, 1.0, 1.0)
const NEUTRAL_HEAT_FILL := Color(0.72, 0.76, 0.80, 0.96)
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
var _display_ratio: float = 0.0
var _state: StringName = &"normal"
var _short_text: String = ""
var _status_label: Label
var _heat_gauge: TextureRect
var _heat_needle: TextureRect
var _heat_cold_icon: Label
var _heat_hot_icon: Label
var _heat_direction_label: Label
var _heat_zone_label: Label
var _heat_direction: StringName = &"stable"
var _pulse_time: float = 0.0
@export_range(0.1, 1.0, 0.05) var heat_gauge_opacity: float = 0.82:
	set(value):
		heat_gauge_opacity = clampf(value, 0.1, 1.0)
		_apply_heat_gauge_opacity()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = METER_SIZE
	size = METER_SIZE
	_ensure_status_label()
	_ensure_heat_gauge()
	set_process(true)

func set_resource(mode: StringName, ratio: float, state: StringName = &"normal", short_text: String = "", tooltip: String = "") -> void:
	var next_ratio := clampf(ratio, 0.0, 1.0)
	if mode == MODE_HEAT and _mode == MODE_HEAT:
		if next_ratio > _ratio + 0.0005:
			_heat_direction = &"rising"
		elif next_ratio < _ratio - 0.0005:
			_heat_direction = &"falling"
		else:
			_heat_direction = &"stable"
	elif mode == MODE_HEAT:
		_heat_direction = &"stable"
	_mode = mode
	_ratio = next_ratio
	_state = state
	_short_text = short_text
	tooltip_text = tooltip
	_update_heat_gauge()
	_update_status_label()
	_update_heat_accessibility()
	queue_redraw()

func is_status_visible() -> bool:
	return _short_text != ""

func get_ratio() -> float:
	return _ratio

func set_heat_gauge_opacity(opacity: float) -> void:
	heat_gauge_opacity = opacity

func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	var previous_display := _display_ratio
	_display_ratio = lerpf(_display_ratio, _ratio, 1.0 - exp(-DISPLAY_LERP_SPEED * safe_delta))
	if absf(_display_ratio - _ratio) <= 0.0005:
		_display_ratio = _ratio
	if not is_equal_approx(previous_display, _display_ratio):
		_update_heat_gauge()
		queue_redraw()
	if _state == &"extreme_heat" or _state == &"extreme_cold" or _state == &"warning" or _state == &"locked" or _state == &"reloading" or _state == &"charging" or _state == &"cooling":
		_pulse_time += safe_delta
		queue_redraw()

func _draw() -> void:
	if _mode == MODE_HEAT:
		return
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
	var filled_width: float = maxf(2.0, body.size.x * _display_ratio)
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
	var angle := lerpf(PI, TAU, _display_ratio)
	draw_line(center, center + Vector2(cos(angle), sin(angle)) * 6.0, fill_color, 2.0 + pulse)

func _draw_bar(fill_color: Color, edge_color: Color, pulse: float) -> void:
	draw_rect(BAR_RECT.grow(2.0), Color(0.01, 0.025, 0.03, 0.90), true)
	draw_rect(BAR_RECT, BACK_FILL, true)
	draw_rect(BAR_RECT, Color(edge_color.r, edge_color.g, edge_color.b, 0.48 + pulse * 0.30), false, 1.0 + pulse)
	if _display_ratio > 0.0:
		var fill_rect := Rect2(BAR_RECT.position, Vector2(BAR_RECT.size.x * _display_ratio, BAR_RECT.size.y))
		draw_rect(fill_rect, fill_color, true)
		draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, 2.0)), Color(1.0, 1.0, 1.0, 0.14), true)
		draw_line(fill_rect.position + Vector2(1.0, fill_rect.size.y - 1.0), fill_rect.end - Vector2(1.0, 1.0), Color(0.0, 0.0, 0.0, 0.20), 1.0)

func _ensure_status_label() -> void:
	if _status_label != null and is_instance_valid(_status_label):
		return
	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.position = LABEL_OFFSET
	_status_label.size = LABEL_SIZE
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_status_label)
	_update_status_label()

func _ensure_heat_gauge() -> void:
	if _heat_gauge != null and is_instance_valid(_heat_gauge):
		return
	_heat_gauge = TextureRect.new()
	_heat_gauge.name = "HeatGauge"
	_heat_gauge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_heat_gauge.texture = HEAT_GAUGE_TEXTURE
	_heat_gauge.size = HEAT_GAUGE_SIZE
	_heat_gauge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_heat_gauge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_heat_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heat_gauge)
	_heat_needle = TextureRect.new()
	_heat_needle.name = "HeatNeedle"
	_heat_needle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_heat_needle.texture = HEAT_NEEDLE_TEXTURE
	_heat_needle.size = HEAT_GAUGE_SIZE
	_heat_needle.pivot_offset = HEAT_GAUGE_PIVOT
	_heat_needle.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_heat_needle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_heat_needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heat_needle)
	_ensure_heat_accessibility_overlay()
	_apply_heat_gauge_opacity()
	_update_heat_gauge()

func _apply_heat_gauge_opacity() -> void:
	if _heat_gauge != null:
		_heat_gauge.modulate.a = heat_gauge_opacity
	if _heat_needle != null:
		_heat_needle.modulate.a = heat_gauge_opacity

func _update_heat_gauge() -> void:
	var is_heat := _mode == MODE_HEAT
	custom_minimum_size = HEAT_GAUGE_SIZE if is_heat else METER_SIZE
	size = custom_minimum_size
	if _heat_gauge == null or _heat_needle == null:
		return
	_heat_gauge.visible = is_heat
	_heat_needle.visible = is_heat
	if is_heat:
		_heat_needle.rotation = deg_to_rad(lerpf(HEAT_NEEDLE_MIN_DEGREES, HEAT_NEEDLE_MAX_DEGREES, _display_ratio))
		var tint := _heat_polarity_color()
		_heat_gauge.modulate = Color(tint.r, tint.g, tint.b, heat_gauge_opacity)
		_heat_needle.modulate = Color(tint.r, tint.g, tint.b, heat_gauge_opacity)
	_update_heat_accessibility()

func _update_status_label() -> void:
	if _status_label == null or not is_instance_valid(_status_label):
		return
	_status_label.text = _short_text
	if _mode == MODE_HEAT:
		_status_label.position = Vector2(50.0, 124.0)
		_status_label.size = Vector2(52.0, 20.0)
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	else:
		_status_label.position = LABEL_OFFSET
		_status_label.size = LABEL_SIZE
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_status_label.add_theme_color_override("font_color", _edge_color())
	_status_label.visible = _short_text != ""

func _ensure_heat_accessibility_overlay() -> void:
	if _heat_zone_label != null and is_instance_valid(_heat_zone_label):
		return
	_heat_cold_icon = _make_heat_overlay_label("ColdIcon", Vector2(4.0, 62.0), Vector2(34.0, 22.0), 16)
	_heat_cold_icon.text = "❄ C"
	_heat_cold_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_heat_hot_icon = _make_heat_overlay_label("HotIcon", Vector2(114.0, 62.0), Vector2(34.0, 22.0), 16)
	_heat_hot_icon.text = "H ♨"
	_heat_hot_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_heat_direction_label = _make_heat_overlay_label("Direction", Vector2(56.0, 24.0), Vector2(40.0, 22.0), 17)
	_heat_zone_label = _make_heat_overlay_label("Zone", Vector2(18.0, 103.0), Vector2(116.0, 18.0), 10)

func _make_heat_overlay_label(node_name: String, label_position: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = label_position
	label.size = label_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label

func _update_heat_accessibility() -> void:
	if _heat_zone_label == null or not is_instance_valid(_heat_zone_label):
		return
	var is_heat := _mode == MODE_HEAT
	_heat_cold_icon.visible = is_heat
	_heat_hot_icon.visible = is_heat
	_heat_direction_label.visible = is_heat
	_heat_zone_label.visible = is_heat
	if not is_heat:
		return
	_heat_direction_label.text = _get_heat_direction_symbol()
	_heat_zone_label.text = _get_accessible_heat_zone_text()

func _get_heat_direction_symbol() -> String:
	match _heat_direction:
		&"rising":
			return "▶"
		&"falling":
			return "◀"
		_:
			return "◆"

func _get_accessible_heat_zone_text() -> String:
	var key := "ui.hud.heat.zone.neutral"
	var fallback := "NEUTRAL"
	match _state:
		&"extreme_cold", &"deep_cold":
			key = "ui.hud.heat.zone.extreme_cold"
			fallback = "EXTREME COLD"
		&"cold":
			key = "ui.hud.heat.zone.cold"
			fallback = "COLD"
		&"hot":
			key = "ui.hud.heat.zone.hot"
			fallback = "HOT"
		&"high_heat", &"extreme_heat":
			key = "ui.hud.heat.zone.extreme_hot"
			fallback = "EXTREME HOT"
	if LocalizationManager != null:
		return LocalizationManager.tr_key(key, fallback)
	return fallback

func get_heat_accessibility_state() -> Dictionary:
	return {
		"cold_icon": _heat_cold_icon.text if _heat_cold_icon != null else "",
		"hot_icon": _heat_hot_icon.text if _heat_hot_icon != null else "",
		"direction": _get_heat_direction_symbol(),
		"zone": _get_accessible_heat_zone_text(),
	}

func _fill_color() -> Color:
	if _state == &"locked":
		return LOCKED_FILL
	if _mode == MODE_HEAT:
		return _heat_polarity_color()
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
		return _heat_polarity_color()
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

func _heat_polarity_color() -> Color:
	if _display_ratio < 0.20:
		return DEEP_COLD_FILL
	if _display_ratio < 0.50:
		return COLD_FILL
	if _display_ratio > 0.80:
		return HEAT_HIGH_FILL
	if _display_ratio > 0.50:
		return HEAT_FILL
	return NEUTRAL_HEAT_FILL

func _pulse_strength() -> float:
	if not (_state == &"extreme_heat" or _state == &"extreme_cold" or _state == &"warning" or _state == &"locked" or _state == &"reloading" or _state == &"charging" or _state == &"cooling"):
		return 0.0
	return (sin(_pulse_time * 6.0) + 1.0) * 0.35
