extends Control
class_name PlayerStatusHud

const HUD_SIZE := Vector2(344.0, 76.0)
const BAR_RECT := Rect2(Vector2(29.0, 39.0), Vector2(286.0, 18.0))
const SHIELD_RECT := Rect2(Vector2(29.0, 61.0), Vector2(286.0, 5.0))
const ENERGY_Y := 8.0
const ENERGY_PER_BEAN := 50.0
const ENERGY_BEAN_SIZE := Vector2(34.0, 9.0)
const ENERGY_BEAN_GAP := 6.0
const COOLDOWN_TRACK_HEIGHT := 3.0
const COOLDOWN_TRACK_GAP := 3.0
const PANEL_PADDING := 4.0
const CUT_SIZE := 5.0
const HP_VALUE_HOLD_SECONDS := 0.8
const HP_VALUE_FADE_SECONDS := 0.25
const HP_GHOST_HOLD_SECONDS := 0.22
const HP_GHOST_CATCHUP_SECONDS := 0.65
const DAMAGE_FLASH_DURATION := 0.32
const HP_WARNING_RATIO := 0.35
const HP_CRITICAL_RATIO := 0.18
const HP_WARNING_PULSE_HZ := 1.8
const HP_CRITICAL_PULSE_HZ := 3.0
const HP_CRITICAL_CROSS_FLASH_SECONDS := 0.18

const HP_TRACK := Color(0.018, 0.075, 0.070, 0.96)
const HP_FILL := Color(0.21, 0.81, 0.91, 0.98)
const HP_DAMAGE_GHOST := Color(1.0, 0.28, 0.20, 0.86)
const HP_HEAL_GHOST := Color(0.30, 1.0, 0.66, 0.82)
const SHIELD_TRACK := Color(0.025, 0.10, 0.15, 0.96)
const SHIELD_COLOR := Color(0.20, 0.76, 1.0, 1.0)
const ENERGY_EMPTY := Color(0.105, 0.065, 0.018, 0.94)
const ENERGY_FILL := Color(1.0, 0.55, 0.04, 0.98)
const ENERGY_EDGE := Color(1.0, 0.76, 0.22, 1.0)
const ENERGY_FULL_EDGE := Color(1.0, 0.90, 0.38, 1.0)
const ENERGY_READY_EDGE := Color(1.0, 0.96, 0.68, 1.0)
const COOLDOWN_TRACK := Color(0.20, 0.29, 0.34, 0.78)
const COOLDOWN_FILL := Color(0.34, 0.78, 0.88, 1.0)

var _current_hp := 0
var _max_hp := 1
var _current_shield := 0
var _max_shield := 0
var _current_energy := 0.0
var _max_energy := 100.0
var _skill_cost := 0.0
var _cooldown_ratio := 0.0
var _cooldown_remaining := 0.0
var _cooldown_total := 0.0
var _cooldown_has_duration := false
var _skill_available := false
var _has_health_sample := false
var _target_hp_ratio := 0.0
var _display_hp_ratio := 0.0
var _ghost_hp_ratio := 0.0
var _hp_animation_start_ratio := 0.0
var _hp_animation_elapsed := 0.0
var _hp_animation_mode: StringName = &"none"
var _hp_value_elapsed := 0.0
var _hp_label: Label
var _skill_state_label: Label
var _damage_delta_label: Label
var _damage_flash_strength := 0.0
var _damage_flash_elapsed := DAMAGE_FLASH_DURATION
var _damage_punch_tween: Tween
var _damage_label_tween: Tween
var _health_pulse_elapsed := 0.0
var _critical_cross_flash_elapsed := HP_CRITICAL_CROSS_FLASH_SECONDS

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = HUD_SIZE
	size = HUD_SIZE
	pivot_offset = HUD_SIZE * 0.5
	_build_hp_label()
	_build_skill_state_label()
	_build_damage_delta_label()
	if PlayerData != null and not PlayerData.player_damage_received.is_connected(_on_player_damage_received):
		PlayerData.player_damage_received.connect(_on_player_damage_received)
	set_process(true)
	queue_redraw()

func set_health(current_hp: int, max_hp: int, current_shield: int = 0, max_shield: int = 0) -> void:
	var next_max_hp := maxi(max_hp, 1)
	var next_current_hp := clampi(current_hp, 0, next_max_hp)
	var next_ratio := clampf(float(next_current_hp) / float(next_max_hp), 0.0, 1.0)
	var health_changed := _has_health_sample and (
		next_current_hp != _current_hp or next_max_hp != _max_hp
	)
	var previous_ratio := _target_hp_ratio
	if not _has_health_sample:
		_has_health_sample = true
		_target_hp_ratio = next_ratio
		_display_hp_ratio = next_ratio
		_ghost_hp_ratio = next_ratio
	elif health_changed:
		_begin_hp_animation(next_ratio)
		_show_hp_value()
		if previous_ratio > HP_CRITICAL_RATIO and next_ratio <= HP_CRITICAL_RATIO and next_current_hp > 0:
			_critical_cross_flash_elapsed = 0.0
	_max_hp = next_max_hp
	_current_hp = next_current_hp
	_current_shield = maxi(current_shield, 0)
	_max_shield = maxi(max_shield, _current_shield)
	_hp_label.text = "%d / %d" % [_current_hp, _max_hp]
	if next_current_hp <= 0 or next_ratio > HP_WARNING_RATIO:
		_health_pulse_elapsed = 0.0
		_critical_cross_flash_elapsed = HP_CRITICAL_CROSS_FLASH_SECONDS
	queue_redraw()

func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_update_damage_feedback(safe_delta)
	_update_hp_value_visibility(safe_delta)
	_update_health_danger_feedback(safe_delta)
	if _hp_animation_mode == &"none":
		return
	_hp_animation_elapsed += safe_delta
	if _hp_animation_elapsed <= HP_GHOST_HOLD_SECONDS:
		return
	var catchup_elapsed := _hp_animation_elapsed - HP_GHOST_HOLD_SECONDS
	var progress := clampf(catchup_elapsed / HP_GHOST_CATCHUP_SECONDS, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, progress)
	if _hp_animation_mode == &"damage":
		_ghost_hp_ratio = lerpf(_hp_animation_start_ratio, _target_hp_ratio, eased)
	else:
		_display_hp_ratio = lerpf(_hp_animation_start_ratio, _target_hp_ratio, eased)
	if progress >= 1.0:
		_display_hp_ratio = _target_hp_ratio
		_ghost_hp_ratio = _target_hp_ratio
		_hp_animation_mode = &"none"
	queue_redraw()

func _update_health_danger_feedback(delta: float) -> void:
	if _current_hp <= 0 or _target_hp_ratio > HP_WARNING_RATIO:
		return
	_health_pulse_elapsed += delta
	if _critical_cross_flash_elapsed < HP_CRITICAL_CROSS_FLASH_SECONDS:
		_critical_cross_flash_elapsed = minf(
			HP_CRITICAL_CROSS_FLASH_SECONDS,
			_critical_cross_flash_elapsed + delta
		)
	queue_redraw()

func is_hp_value_visible() -> bool:
	return _hp_label != null and _hp_label.visible

func has_health_ghost() -> bool:
	return _hp_animation_mode != &"none" and not is_equal_approx(
		_display_hp_ratio,
		_ghost_hp_ratio
	)

func get_display_health_ratio() -> float:
	return _display_hp_ratio

func get_ghost_health_ratio() -> float:
	return _ghost_hp_ratio

func get_damage_flash_strength() -> float:
	return _damage_flash_strength

func play_damage_feedback(feedback: Dictionary) -> void:
	var damage := maxi(0, int(feedback.get("final_damage", 0)))
	if damage <= 0:
		return
	var severity := clampf(float(feedback.get("severity", 0.0)), 0.0, 1.0)
	var is_periodic := bool(feedback.get("is_periodic", false))
	var is_heavy := bool(feedback.get("is_heavy", false))
	var current_hp := maxi(0, int(feedback.get("current_hp", _current_hp)))
	var previous_hp := maxi(current_hp, int(feedback.get("previous_hp", current_hp + damage)))
	var max_hp := maxi(1, int(feedback.get("max_hp", _max_hp)))
	var crossed_warning := float(previous_hp) / float(max_hp) > 0.35 and float(current_hp) / float(max_hp) <= 0.35
	var crossed_critical := float(previous_hp) / float(max_hp) > 0.18 and float(current_hp) / float(max_hp) <= 0.18
	_damage_flash_strength = maxf(
		_damage_flash_strength,
		0.42 if is_periodic else clampf(0.68 + severity * 0.32, 0.0, 1.0)
	)
	if crossed_warning or crossed_critical:
		_damage_flash_strength = 1.0
	_damage_flash_elapsed = 0.0
	_play_hud_punch(is_periodic, is_heavy or crossed_warning or crossed_critical)
	_show_damage_delta(
		damage,
		StringName(str(feedback.get("damage_type", Attack.TYPE_PHYSICAL))),
		is_periodic,
		is_heavy or crossed_critical
	)
	queue_redraw()

func _on_player_damage_received(feedback: Dictionary) -> void:
	play_damage_feedback(feedback)

func _update_damage_feedback(delta: float) -> void:
	if _damage_flash_elapsed >= DAMAGE_FLASH_DURATION:
		return
	_damage_flash_elapsed = minf(DAMAGE_FLASH_DURATION, _damage_flash_elapsed + delta)
	var progress := _damage_flash_elapsed / DAMAGE_FLASH_DURATION
	_damage_flash_strength = maxf(0.0, _damage_flash_strength * (1.0 - clampf(delta * 8.0, 0.0, 1.0)))
	if progress >= 1.0:
		_damage_flash_strength = 0.0
	queue_redraw()

func _play_hud_punch(is_periodic: bool, is_heavy: bool) -> void:
	if _damage_punch_tween != null and is_instance_valid(_damage_punch_tween):
		_damage_punch_tween.kill()
	scale = Vector2.ONE
	var peak := 1.018 if is_periodic else (1.065 if is_heavy else 1.04)
	_damage_punch_tween = create_tween()
	_damage_punch_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_damage_punch_tween.tween_property(self, "scale", Vector2.ONE * peak, 0.055) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_damage_punch_tween.tween_property(self, "scale", Vector2.ONE, 0.13) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_damage_delta(
	damage: int,
	damage_type: StringName,
	is_periodic: bool,
	emphasized: bool
) -> void:
	if _damage_delta_label == null:
		return
	if _damage_label_tween != null and is_instance_valid(_damage_label_tween):
		_damage_label_tween.kill()
	_damage_delta_label.text = "-%d%s" % [damage, "!" if emphasized else ""]
	_damage_delta_label.add_theme_font_size_override("font_size", 24 if emphasized else 12)
	_damage_delta_label.add_theme_color_override("font_color", _damage_color(damage_type, is_periodic))
	_damage_delta_label.position = Vector2(BAR_RECT.end.x - 86.0, BAR_RECT.position.y - 23.0)
	_damage_delta_label.modulate = Color.WHITE
	_damage_delta_label.visible = true
	_damage_label_tween = create_tween()
	_damage_label_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_damage_label_tween.set_parallel(true)
	_damage_label_tween.tween_property(
		_damage_delta_label,
		"position:y",
		_damage_delta_label.position.y - 12.0,
		0.55 if not is_periodic else 0.38
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_damage_label_tween.tween_property(
		_damage_delta_label,
		"modulate:a",
		0.0,
		0.55 if not is_periodic else 0.38
	).set_delay(0.16 if not is_periodic else 0.08)
	_damage_label_tween.chain().tween_callback(_damage_delta_label.hide)

func _begin_hp_animation(next_ratio: float) -> void:
	var previous_target := _target_hp_ratio
	_target_hp_ratio = next_ratio
	_hp_animation_elapsed = 0.0
	if next_ratio < previous_target:
		_hp_animation_mode = &"damage"
		_display_hp_ratio = next_ratio
		_ghost_hp_ratio = maxf(_ghost_hp_ratio, previous_target)
		_hp_animation_start_ratio = _ghost_hp_ratio
	elif next_ratio > previous_target:
		_hp_animation_mode = &"heal"
		_hp_animation_start_ratio = _display_hp_ratio
		_ghost_hp_ratio = next_ratio
	else:
		_hp_animation_mode = &"none"
		_display_hp_ratio = next_ratio
		_ghost_hp_ratio = next_ratio

func _show_hp_value() -> void:
	if _hp_label == null:
		return
	_hp_value_elapsed = 0.0
	_hp_label.visible = true
	_hp_label.modulate.a = 1.0

func _update_hp_value_visibility(delta: float) -> void:
	if _hp_label == null or not _hp_label.visible:
		return
	_hp_value_elapsed += delta
	if _hp_value_elapsed <= HP_VALUE_HOLD_SECONDS:
		_hp_label.modulate.a = 1.0
		return
	var fade_progress := clampf(
		(_hp_value_elapsed - HP_VALUE_HOLD_SECONDS) / HP_VALUE_FADE_SECONDS,
		0.0,
		1.0
	)
	_hp_label.modulate.a = 1.0 - fade_progress
	if fade_progress >= 1.0:
		_hp_label.visible = false

func set_energy(current: float, max_value: float) -> void:
	_max_energy = maxf(max_value, 1.0)
	_current_energy = clampf(current, 0.0, _max_energy)
	_refresh_skill_state_label()
	queue_redraw()

func set_skill_cost(cost: float) -> void:
	_skill_cost = maxf(cost, 0.0)
	_refresh_skill_state_label()
	queue_redraw()

func set_skill_available(available: bool) -> void:
	_skill_available = available
	if not _skill_available:
		_cooldown_ratio = 0.0
		_cooldown_remaining = 0.0
		_cooldown_total = 0.0
		_cooldown_has_duration = false
	_refresh_skill_state_label()
	queue_redraw()

func is_skill_rail_visible() -> bool:
	return _skill_available

func set_cooldown_ratio(ratio: float) -> void:
	_cooldown_ratio = clampf(ratio, 0.0, 1.0)
	_cooldown_remaining = _cooldown_ratio
	_cooldown_total = 1.0 if _cooldown_ratio > 0.0 else 0.0
	_cooldown_has_duration = false
	_refresh_skill_state_label()
	queue_redraw()

func set_cooldown(remaining_seconds: float, total_seconds: float) -> void:
	_cooldown_remaining = maxf(remaining_seconds, 0.0)
	_cooldown_total = maxf(total_seconds, 0.0)
	_cooldown_ratio = (
		clampf(_cooldown_remaining / _cooldown_total, 0.0, 1.0)
		if _cooldown_total > 0.0
		else 0.0
	)
	_cooldown_has_duration = _cooldown_total > 0.0
	_refresh_skill_state_label()
	queue_redraw()

func is_skill_ready() -> bool:
	return _skill_available and _has_enough_skill_energy() and _cooldown_remaining <= 0.0

func get_skill_state() -> StringName:
	if not _skill_available:
		return &"inactive"
	if _cooldown_remaining > 0.0:
		return &"cooldown"
	if _skill_cost <= 0.0:
		return &"inactive"
	if _has_enough_skill_energy():
		return &"ready"
	return &"charging"

func get_full_energy_bean_count() -> int:
	if not _skill_available:
		return 0
	var full_count := 0
	var bean_count := maxi(1, int(ceil(_max_energy / ENERGY_PER_BEAN)))
	for index in range(bean_count):
		var bean_capacity := minf(ENERGY_PER_BEAN, _max_energy - float(index) * ENERGY_PER_BEAN)
		var bean_energy := clampf(
			_current_energy - float(index) * ENERGY_PER_BEAN,
			0.0,
			bean_capacity
		)
		if bean_energy >= bean_capacity - 0.0001:
			full_count += 1
	return full_count

func get_cooldown_remaining() -> float:
	return _cooldown_remaining

func get_cooldown_progress() -> float:
	if not _skill_available or _skill_cost <= 0.0:
		return 0.0
	return clampf(1.0 - _cooldown_ratio, 0.0, 1.0)

func get_energy_plate_rect() -> Rect2:
	var row_width := _get_energy_row_width()
	var origin_x := (size.x - row_width) * 0.5
	return Rect2(
		Vector2(origin_x - PANEL_PADDING, ENERGY_Y - PANEL_PADDING),
		Vector2(
			row_width + PANEL_PADDING * 2.0,
			ENERGY_BEAN_SIZE.y
				+ COOLDOWN_TRACK_GAP
				+ COOLDOWN_TRACK_HEIGHT
				+ PANEL_PADDING * 2.0
		)
	)

func get_energy_segments_rect() -> Rect2:
	var row_width := _get_energy_row_width()
	return Rect2(
		Vector2((size.x - row_width) * 0.5, ENERGY_Y),
		Vector2(row_width, ENERGY_BEAN_SIZE.y)
	)

func get_cooldown_track_rect() -> Rect2:
	var row_width := _get_energy_row_width()
	var origin_x := (size.x - row_width) * 0.5
	return Rect2(
		Vector2(origin_x, ENERGY_Y + ENERGY_BEAN_SIZE.y + COOLDOWN_TRACK_GAP),
		Vector2(row_width, COOLDOWN_TRACK_HEIGHT)
	)

# Kept as a compatibility endpoint for HudPresenter. Ammo deliberately has no HUD.
func set_ammo(_current: int, _maximum: int, _enabled: bool = true, _state: StringName = &"normal", _tooltip: String = "") -> void:
	pass

func _draw() -> void:
	_draw_skill_rail()
	_draw_health_bar()

func _draw_skill_rail() -> void:
	if not _skill_available:
		return
	var bean_count := maxi(1, int(ceil(_max_energy / ENERGY_PER_BEAN)))
	var row_width := _get_energy_row_width()
	var origin_x := (size.x - row_width) * 0.5
	var plate := get_energy_plate_rect()
	_draw_cut_panel(plate, Color(0.008, 0.024, 0.030, 0.92), Color(0.12, 0.40, 0.45, 0.82), CUT_SIZE, 1.0)
	for index in range(bean_count):
		var rect := Rect2(
			Vector2(origin_x + float(index) * (ENERGY_BEAN_SIZE.x + ENERGY_BEAN_GAP), ENERGY_Y),
			ENERGY_BEAN_SIZE
		)
		var bean_capacity := minf(ENERGY_PER_BEAN, _max_energy - float(index) * ENERGY_PER_BEAN)
		var bean_energy := clampf(_current_energy - float(index) * ENERGY_PER_BEAN, 0.0, bean_capacity)
		var fill_ratio := bean_energy / maxf(bean_capacity, 1.0)
		_draw_cut_panel(rect, ENERGY_EMPTY, Color(ENERGY_EDGE, 0.45), 3.0, 1.0)
		if fill_ratio > 0.0:
			var fill_rect := Rect2(rect.position + Vector2(2.0, 2.0), Vector2((rect.size.x - 4.0) * fill_ratio, rect.size.y - 4.0))
			if fill_rect.size.x >= 1.0:
				_draw_cut_panel(fill_rect, ENERGY_FILL, Color(ENERGY_EDGE, 0.82), minf(2.0, fill_rect.size.x * 0.4), 1.0)
				draw_line(fill_rect.position + Vector2(3.0, 1.0), Vector2(fill_rect.end.x - 2.0, fill_rect.position.y + 1.0), Color(ENERGY_READY_EDGE, 0.38), 1.0, true)
		if fill_ratio >= 0.999:
			_draw_cut_outline(rect, ENERGY_FULL_EDGE, 2.0, 3.0)
			var marker_center := rect.position + Vector2(rect.size.x * 0.5, 2.5)
			draw_colored_polygon(PackedVector2Array([
				marker_center + Vector2(0.0, -2.5),
				marker_center + Vector2(2.5, 0.0),
				marker_center + Vector2(0.0, 2.5),
				marker_center + Vector2(-2.5, 0.0),
			]), ENERGY_FULL_EDGE)
		var accent_x := rect.end.x - 2.0
		draw_line(Vector2(accent_x, rect.position.y + 4.0), Vector2(accent_x, rect.end.y - 4.0), ENERGY_EDGE, 1.0, true)
	if is_skill_ready():
		_draw_cut_outline(plate.grow(1.5), ENERGY_READY_EDGE, 2.0, CUT_SIZE)
	_draw_skill_cooldown()

func _draw_skill_cooldown() -> void:
	var track := get_cooldown_track_rect()
	if _skill_cost <= 0.0:
		return
	draw_rect(track, COOLDOWN_TRACK, true)
	var cooldown_progress := get_cooldown_progress()
	if cooldown_progress <= 0.0:
		return
	draw_rect(
		Rect2(track.position, Vector2(track.size.x * cooldown_progress, track.size.y)),
		COOLDOWN_FILL,
		true
	)
	if cooldown_progress >= 0.999:
		var cap_x := track.end.x
		draw_line(
			Vector2(cap_x, track.position.y - 1.0),
			Vector2(cap_x, track.end.y + 1.0),
			ENERGY_READY_EDGE,
			2.0
		)

func _draw_health_bar() -> void:
	var danger_pulse := _get_health_danger_pulse()
	var danger_edge := Color(0.42, 0.94, 1.0, 0.86 + danger_pulse * 0.14)
	var danger_width := 1.0 + danger_pulse * 0.75
	var plate := BAR_RECT.grow(PANEL_PADDING)
	_draw_cut_panel(plate, Color(0.006, 0.026, 0.032, 0.94), danger_edge if danger_pulse > 0.0 else Color(0.11, 0.42, 0.48, 0.86), CUT_SIZE, danger_width)
	_draw_cut_panel(BAR_RECT, HP_TRACK, Color(0.10, 0.38, 0.30, 0.95), 4.0, 1.0)
	var inner_origin := BAR_RECT.position + Vector2(2.0, 2.0)
	var inner_size := BAR_RECT.size - Vector2(4.0, 4.0)
	if has_health_ghost():
		var ghost_rect := Rect2(
			inner_origin,
			Vector2(inner_size.x * _ghost_hp_ratio, inner_size.y)
		)
		var ghost_color := HP_DAMAGE_GHOST if _hp_animation_mode == &"damage" else HP_HEAL_GHOST
		_draw_cut_panel(
			ghost_rect,
			ghost_color,
			Color(1.0, 0.86, 0.68, 0.72),
			minf(3.0, ghost_rect.size.x * 0.35),
			1.0
		)
	if _display_hp_ratio > 0.0:
		var fill_rect := Rect2(inner_origin, Vector2(inner_size.x * _display_hp_ratio, inner_size.y))
		_draw_cut_panel(fill_rect, _health_color(_target_hp_ratio), Color(0.52, 1.0, 0.72, 0.78 + danger_pulse * 0.16), minf(3.0, fill_rect.size.x * 0.35), 1.0)
		draw_line(fill_rect.position + Vector2(4.0, 1.0), Vector2(fill_rect.end.x - 2.0, fill_rect.position.y + 1.0), Color(0.90, 1.0, 0.94, 0.34), 1.0, true)
	_draw_cut_panel(SHIELD_RECT, SHIELD_TRACK, Color(0.12, 0.42, 0.55, 0.90), 2.0, 1.0)
	var shield_denominator := float(_max_shield if _max_shield > 0 else _max_hp)
	var shield_ratio := clampf(float(_current_shield) / maxf(shield_denominator, 1.0), 0.0, 1.0)
	if shield_ratio > 0.0:
		var shield_fill := Rect2(SHIELD_RECT.position + Vector2(1.0, 1.0), Vector2((SHIELD_RECT.size.x - 2.0) * shield_ratio, SHIELD_RECT.size.y - 2.0))
		_draw_cut_panel(shield_fill, SHIELD_COLOR, Color(0.72, 0.96, 1.0, 0.92), minf(1.5, shield_fill.size.x * 0.35), 1.0)
	if _damage_flash_strength > 0.001:
		var flash_color := Color(1.0, 0.16, 0.10, 0.24 + _damage_flash_strength * 0.64)
		_draw_cut_outline(
			BAR_RECT.grow(3.0 + _damage_flash_strength * 2.0),
			flash_color,
			1.5 + _damage_flash_strength * 2.0,
			CUT_SIZE
		)
	if _critical_cross_flash_elapsed < HP_CRITICAL_CROSS_FLASH_SECONDS:
		var flash_progress := 1.0 - _critical_cross_flash_elapsed / HP_CRITICAL_CROSS_FLASH_SECONDS
		_draw_cut_outline(BAR_RECT.grow(4.0), Color(0.58, 0.98, 1.0, flash_progress * 0.82), 2.5, CUT_SIZE)

func _draw_cut_panel(rect: Rect2, fill_color: Color, edge_color: Color, cut: float, line_width: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var points := _cut_rect_points(rect, cut)
	draw_colored_polygon(points, fill_color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, edge_color, line_width, true)

func _draw_cut_outline(rect: Rect2, color: Color, line_width: float, cut: float) -> void:
	var points := _cut_rect_points(rect, cut)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, color, line_width, true)

func _cut_rect_points(rect: Rect2, requested_cut: float) -> PackedVector2Array:
	var cut := minf(requested_cut, minf(rect.size.x, rect.size.y) * 0.45)
	return PackedVector2Array([
		rect.position + Vector2(cut, 0.0),
		Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut),
		rect.end - Vector2(0.0, cut),
		rect.end - Vector2(cut, 0.0),
		Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut),
		rect.position + Vector2(0.0, cut),
	])

func _build_hp_label() -> void:
	_hp_label = Label.new()
	_hp_label.name = "HpValue"
	_hp_label.position = BAR_RECT.position
	_hp_label.size = BAR_RECT.size
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.add_theme_color_override("font_color", Color(0.94, 1.0, 0.96))
	_hp_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_hp_label)
	_hp_label.text = "0/1"
	_hp_label.visible = false

func _build_skill_state_label() -> void:
	_skill_state_label = Label.new()
	_skill_state_label.name = "SkillState"
	_skill_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_skill_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill_state_label.add_theme_font_size_override("font_size", 12)
	_skill_state_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.94))
	_skill_state_label.add_theme_constant_override("shadow_offset_x", 1)
	_skill_state_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_skill_state_label)
	_refresh_skill_state_label()

func _build_damage_delta_label() -> void:
	_damage_delta_label = Label.new()
	_damage_delta_label.name = "DamageDelta"
	_damage_delta_label.size = Vector2(82.0, 24.0)
	_damage_delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_damage_delta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_damage_delta_label.add_theme_font_size_override("font_size", 12)
	_damage_delta_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.22, 1.0))
	_damage_delta_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	_damage_delta_label.add_theme_constant_override("shadow_offset_x", 1)
	_damage_delta_label.add_theme_constant_override("shadow_offset_y", 1)
	_damage_delta_label.visible = false
	add_child(_damage_delta_label)

func _damage_color(damage_type: StringName, is_periodic: bool) -> Color:
	var color := Color(1.0, 0.30, 0.22, 1.0)
	match Attack.normalize_damage_type(damage_type):
		Attack.TYPE_FIRE:
			color = Color(1.0, 0.42, 0.10, 1.0)
		Attack.TYPE_FREEZE:
			color = Color(0.35, 0.90, 1.0, 1.0)
		Attack.TYPE_ENERGY:
			color = Color(0.78, 0.52, 1.0, 1.0)
	if is_periodic:
		color.a = 0.78
	return color

func _exit_tree() -> void:
	if PlayerData != null and PlayerData.player_damage_received.is_connected(_on_player_damage_received):
		PlayerData.player_damage_received.disconnect(_on_player_damage_received)
	if _damage_punch_tween != null and is_instance_valid(_damage_punch_tween):
		_damage_punch_tween.kill()
	if _damage_label_tween != null and is_instance_valid(_damage_label_tween):
		_damage_label_tween.kill()
	_damage_punch_tween = null
	_damage_label_tween = null
	_health_pulse_elapsed = 0.0
	_critical_cross_flash_elapsed = HP_CRITICAL_CROSS_FLASH_SECONDS
	scale = Vector2.ONE

func _refresh_skill_state_label() -> void:
	if _skill_state_label == null:
		return
	var bean_count := maxi(1, int(ceil(_max_energy / ENERGY_PER_BEAN)))
	var row_width := float(bean_count) * ENERGY_BEAN_SIZE.x + float(bean_count - 1) * ENERGY_BEAN_GAP
	var origin_x := (size.x - row_width) * 0.5
	_skill_state_label.position = Vector2(origin_x + row_width + 8.0, ENERGY_Y - 1.0)
	_skill_state_label.size = Vector2(maxf(size.x - _skill_state_label.position.x, 0.0), ENERGY_BEAN_SIZE.y + 2.0)
	match get_skill_state():
		&"cooldown":
			_skill_state_label.text = _format_cooldown_time() if _cooldown_has_duration else "CD"
			_skill_state_label.add_theme_color_override("font_color", COOLDOWN_FILL)
		&"ready":
			_skill_state_label.text = LocalizationManager.tr_key("ui.hud.skill.ready", "READY")
			_skill_state_label.add_theme_color_override("font_color", ENERGY_READY_EDGE)
		_:
			_skill_state_label.text = ""

func _format_cooldown_time() -> String:
	if _cooldown_remaining >= 10.0:
		return "%.0fs" % ceil(_cooldown_remaining)
	return "%.1fs" % _cooldown_remaining

func _has_enough_skill_energy() -> bool:
	return _skill_available and _skill_cost > 0.0 and _current_energy >= _skill_cost

func _get_energy_row_width() -> float:
	var bean_count := maxi(1, int(ceil(_max_energy / ENERGY_PER_BEAN)))
	return float(bean_count) * ENERGY_BEAN_SIZE.x + float(bean_count - 1) * ENERGY_BEAN_GAP

func _health_color(_ratio: float) -> Color:
	return HP_FILL

func _get_health_danger_pulse() -> float:
	if _current_hp <= 0 or _target_hp_ratio > HP_WARNING_RATIO:
		return 0.0
	var frequency := HP_CRITICAL_PULSE_HZ if _target_hp_ratio <= HP_CRITICAL_RATIO else HP_WARNING_PULSE_HZ
	var amplitude := 1.0 if _target_hp_ratio <= HP_CRITICAL_RATIO else 0.58
	return (sin(_health_pulse_elapsed * TAU * frequency) * 0.5 + 0.5) * amplitude
