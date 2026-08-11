extends Control
class_name CombatResourceMeter

const MODE_AMMO := &"ammo"
const MODE_HEAT := &"heat"
const MODE_CHARGE := &"charge"
const MODE_ENERGY := &"energy"
const MODE_BATTERY := &"battery"
const MODE_PRESSURE := &"pressure"
const METER_SIZE := Vector2(250.0, 20.0)
const HEAT_RAIL_SIZE := Vector2(218.0, 78.0)
const HEAT_TRACK_RECT := Rect2(Vector2(43.0, 37.0), Vector2(132.0, 14.0))
const HEAT_COLD_CAP_RECT := Rect2(Vector2(4.0, 21.0), Vector2(29.0, 36.0))
const HEAT_HOT_CAP_RECT := Rect2(Vector2(185.0, 21.0), Vector2(29.0, 36.0))
const HEAT_NEUTRAL_X := HEAT_TRACK_RECT.position.x + HEAT_TRACK_RECT.size.x * 0.5
const HEAT_CELLS_PER_SIDE := 4
const HEAT_CELL_SIZE := Vector2(11.0, 11.0)
const HEAT_CELL_Y := 38.0
const HEAT_COLD_CELL_X := [89.0, 74.0, 59.0, 44.0]
const HEAT_HOT_CELL_X := [116.0, 131.0, 146.0, 161.0]
const HEAT_RAIL_TEXTURE := preload("res://UI/themes/modern/heat_rail_frame_generated_v4.png")
const HUD_EXPAND_DURATION := 0.18
const HUD_COLLAPSE_DURATION := 0.12
const HUD_COLLAPSED_SCALE := Vector2(0.12, 0.88)
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
const HEAT_LOW_FILL := Color(1.0, 0.82, 0.28, 0.98)
const COLD_FILL := Color(0.30, 0.72, 1.0, 0.96)
const DEEP_COLD_FILL := Color(0.52, 0.90, 1.0, 1.0)
const COLD_HIGH_FILL := Color(0.22, 0.48, 1.0, 1.0)
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
var _heat_direction: StringName = &"stable"
var _pulse_time: float = 0.0
var _has_heat_display_sample := false
var _visibility_tween: Tween
var _display_opacity := 1.0
var _is_collapsing := false
@export_range(0.1, 1.0, 0.05) var heat_gauge_opacity: float = 0.82:
	set(value):
		heat_gauge_opacity = clampf(value, 0.1, 1.0)
		_apply_heat_gauge_opacity()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = METER_SIZE
	size = METER_SIZE
	_ensure_status_label()
	_update_heat_gauge()
	set_process(true)

func set_resource(mode: StringName, ratio: float, state: StringName = &"normal", short_text: String = "", tooltip: String = "") -> void:
	var next_ratio := clampf(ratio, 0.0, 1.0)
	var entering_heat := mode == MODE_HEAT and (_mode != MODE_HEAT or not _has_heat_display_sample)
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
	if entering_heat:
		_display_ratio = next_ratio
		_has_heat_display_sample = true
	_state = state
	_short_text = short_text
	tooltip_text = tooltip
	_update_heat_gauge()
	_update_status_label()
	queue_redraw()

func is_status_visible() -> bool:
	return _short_text != ""

func get_ratio() -> float:
	return _ratio

func get_display_ratio() -> float:
	return _display_ratio

func set_heat_gauge_opacity(opacity: float) -> void:
	heat_gauge_opacity = opacity

func show_animated(opacity: float = 1.0) -> void:
	_display_opacity = clampf(opacity, 0.0, 1.0)
	_kill_visibility_tween()
	_is_collapsing = false
	_display_ratio = _ratio
	pivot_offset = size * 0.5
	scale = HUD_COLLAPSED_SCALE
	modulate.a = 0.0
	visible = true
	queue_redraw()
	_visibility_tween = create_tween()
	_visibility_tween.set_trans(Tween.TRANS_QUAD)
	_visibility_tween.set_ease(Tween.EASE_OUT)
	_visibility_tween.set_parallel(true)
	_visibility_tween.tween_property(self, "scale", Vector2.ONE, HUD_EXPAND_DURATION)
	_visibility_tween.tween_property(self, "modulate:a", _display_opacity, HUD_EXPAND_DURATION)

func hide_animated() -> void:
	if not visible or _is_collapsing:
		return
	_kill_visibility_tween()
	_is_collapsing = true
	pivot_offset = size * 0.5
	_visibility_tween = create_tween()
	_visibility_tween.set_trans(Tween.TRANS_QUAD)
	_visibility_tween.set_ease(Tween.EASE_IN)
	_visibility_tween.set_parallel(true)
	_visibility_tween.tween_property(self, "scale", HUD_COLLAPSED_SCALE, HUD_COLLAPSE_DURATION)
	_visibility_tween.tween_property(self, "modulate:a", 0.0, HUD_COLLAPSE_DURATION)
	_visibility_tween.chain().tween_callback(_finish_hide_animation)

func set_display_opacity(opacity: float) -> void:
	_display_opacity = clampf(opacity, 0.0, 1.0)
	if _visibility_tween == null or not _visibility_tween.is_running():
		modulate.a = _display_opacity

func is_hiding_animated() -> bool:
	return _is_collapsing

func _finish_hide_animation() -> void:
	visible = false
	_is_collapsing = false
	scale = Vector2.ONE
	modulate.a = _display_opacity
	_visibility_tween = null

func _kill_visibility_tween() -> void:
	if _visibility_tween != null and is_instance_valid(_visibility_tween):
		_visibility_tween.kill()
	_visibility_tween = null

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
		_draw_heat_rail()
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

func _draw_heat_rail() -> void:
	var pulse := _pulse_strength()
	draw_texture_rect(
		HEAT_RAIL_TEXTURE,
		Rect2(Vector2.ZERO, HEAT_RAIL_SIZE),
		false,
		Color(1.0, 1.0, 1.0, heat_gauge_opacity)
	)
	_draw_heat_track(pulse)
	_draw_heat_end_cap_pulse(pulse)

func _draw_heat_end_cap_pulse(pulse: float) -> void:
	var cold_edge := Color(DEEP_COLD_FILL.r, DEEP_COLD_FILL.g, DEEP_COLD_FILL.b, heat_gauge_opacity)
	var hot_edge := Color(HEAT_HIGH_FILL.r, HEAT_HIGH_FILL.g, HEAT_HIGH_FILL.b, heat_gauge_opacity)
	if _display_ratio <= 0.015:
		var cold_center := Vector2(20.0, 39.0)
		for spoke_index in range(6):
			var angle := float(spoke_index) * PI / 3.0
			var direction := Vector2(cos(angle), sin(angle))
			draw_line(cold_center + direction * 3.0, cold_center + direction * 10.0, Color(cold_edge.r, cold_edge.g, cold_edge.b, 0.34 + pulse * 0.34), 1.0 + pulse, true)
	if _display_ratio >= 0.985:
		for vent_index in range(5):
			var vent_y := 26.0 + float(vent_index) * 6.0
			var vent_alpha := 0.38 + pulse * 0.48
			draw_line(Vector2(185.0, vent_y), Vector2(205.0, vent_y), Color(1.0, 0.78, 0.42, vent_alpha * heat_gauge_opacity), 1.2 + pulse, true)

func _draw_heat_track(pulse: float) -> void:
	var track := HEAT_TRACK_RECT
	var value_x := lerpf(track.position.x, track.end.x, _display_ratio)
	var fill_color := _heat_polarity_color()
	var side_strength := absf(_display_ratio - 0.5) * 2.0
	if _display_ratio < 0.5:
		_draw_heat_cells(HEAT_COLD_CELL_X, side_strength, fill_color, true)
	elif _display_ratio > 0.5:
		_draw_heat_cells(HEAT_HOT_CELL_X, side_strength, fill_color, false)
	_draw_heat_direction_marker(value_x, track, fill_color, pulse)

func _draw_heat_cells(cell_positions: Array, side_strength: float, color: Color, fill_from_right: bool) -> void:
	var cell_progress := clampf(side_strength, 0.0, 1.0) * float(HEAT_CELLS_PER_SIDE)
	for cell_index in range(HEAT_CELLS_PER_SIDE):
		var progress := clampf(cell_progress - float(cell_index), 0.0, 1.0)
		if progress <= 0.0:
			continue
		var cell_rect := Rect2(Vector2(float(cell_positions[cell_index]), HEAT_CELL_Y), HEAT_CELL_SIZE)
		var fill_width := cell_rect.size.x * progress
		var fill_x := cell_rect.end.x - fill_width if fill_from_right else cell_rect.position.x
		var fill_rect := Rect2(Vector2(fill_x, cell_rect.position.y), Vector2(fill_width, cell_rect.size.y))
		draw_rect(fill_rect, Color(color.r, color.g, color.b, 0.90 * heat_gauge_opacity), true)
		draw_line(
			fill_rect.position + Vector2(0.0, 1.0),
			Vector2(fill_rect.end.x, fill_rect.position.y + 1.0),
			Color(1.0, 0.96, 0.86, 0.22 * heat_gauge_opacity),
			1.0
		)

func _draw_heat_direction_marker(value_x: float, track: Rect2, color: Color, pulse: float) -> void:
	if _heat_direction == &"stable":
		return
	var direction := 1.0 if _heat_direction == &"rising" else -1.0
	var marker_x := clampf(value_x, track.position.x + 6.0, track.end.x - 6.0)
	var center := Vector2(marker_x, track.get_center().y)
	var points := PackedVector2Array([
		center + Vector2(direction * 5.0, 0.0),
		center + Vector2(-direction * 3.0, -5.0),
		center + Vector2(-direction * 3.0, 5.0),
	])
	draw_colored_polygon(points, Color(color.r, color.g, color.b, minf(1.0, 0.9 + pulse * 0.1) * heat_gauge_opacity))

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

func _apply_heat_gauge_opacity() -> void:
	if _status_label != null:
		_status_label.modulate.a = heat_gauge_opacity if _mode == MODE_HEAT else 1.0
	queue_redraw()

func _update_heat_gauge() -> void:
	var is_heat := _mode == MODE_HEAT
	custom_minimum_size = HEAT_RAIL_SIZE if is_heat else METER_SIZE
	size = custom_minimum_size
	_apply_heat_gauge_opacity()
	queue_redraw()

func _update_status_label() -> void:
	if _status_label == null or not is_instance_valid(_status_label):
		return
	_status_label.text = _short_text
	if _mode == MODE_HEAT:
		_status_label.position = Vector2(82.0, 6.0)
		_status_label.size = Vector2(54.0, 21.0)
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status_label.add_theme_font_size_override("font_size", 17)
		_status_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	else:
		_status_label.position = LABEL_OFFSET
		_status_label.size = LABEL_SIZE
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_status_label.add_theme_font_size_override("font_size", 11)
		_status_label.add_theme_color_override("font_color", _edge_color())
	_status_label.visible = _short_text != ""

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
		"cold_icon": "COLD CRYSTAL END CAP",
		"hot_icon": "HOT VENT END CAP",
		"direction": _get_heat_direction_symbol(),
		"zone": _get_accessible_heat_zone_text(),
	}

func get_heat_layout_state() -> Dictionary:
	return {
		"layout": &"bipolar_rail",
		"uses_generated_texture": true,
		"texture_path": HEAT_RAIL_TEXTURE.resource_path,
		"slot_count": HEAT_CELLS_PER_SIDE * 2,
		"cell_size": HEAT_CELL_SIZE,
		"cell_y": HEAT_CELL_Y,
		"cold_cell_x": HEAT_COLD_CELL_X.duplicate(),
		"hot_cell_x": HEAT_HOT_CELL_X.duplicate(),
		"status_text_visible": false,
		"full_feedback": &"internal_vent_pulse",
		"size": HEAT_RAIL_SIZE,
		"track": HEAT_TRACK_RECT,
		"cold_end_cap": HEAT_COLD_CAP_RECT,
		"hot_end_cap": HEAT_HOT_CAP_RECT,
		"neutral_x": HEAT_NEUTRAL_X,
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
	if _display_ratio < 0.50:
		var cold_strength := (0.5 - _display_ratio) * 2.0
		if cold_strength >= 0.67:
			return COLD_HIGH_FILL
		if cold_strength >= 0.34:
			return COLD_FILL
		return DEEP_COLD_FILL
	if _display_ratio > 0.50:
		var heat_strength := (_display_ratio - 0.5) * 2.0
		if heat_strength >= 0.67:
			return HEAT_HIGH_FILL
		if heat_strength >= 0.34:
			return HEAT_FILL
		return HEAT_LOW_FILL
	return NEUTRAL_HEAT_FILL

func get_heat_visual_state() -> Dictionary:
	return {
		"color": _heat_polarity_color(),
		"display_ratio": _display_ratio,
		"status_text_visible": false,
	}

func _pulse_strength() -> float:
	if not (_state == &"extreme_heat" or _state == &"extreme_cold" or _state == &"warning" or _state == &"locked" or _state == &"reloading" or _state == &"charging" or _state == &"cooling"):
		return 0.0
	return (sin(_pulse_time * 6.0) + 1.0) * 0.35
