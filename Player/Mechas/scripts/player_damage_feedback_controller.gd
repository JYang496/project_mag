extends Node
class_name PlayerDamageFeedbackController

const SCREEN_OVERLAY_SCRIPT := preload("res://Player/Mechas/scripts/player_damage_screen_overlay.gd")
const IMPACT_RING_SCRIPT := preload("res://Player/Mechas/scripts/player_damage_impact_ring.gd")
const PROJECTED_UI := preload("res://Visual/Oblique/projected_world_ui_service.gd")
const HIT_TINY_SFX := preload("res://asset/sounds/01_enemy_hit_tiny.wav")
const HIT_LIGHT_SFX := preload("res://asset/sounds/02_enemy_hit_light.wav")
const HIT_MEDIUM_SFX := preload("res://asset/sounds/03_enemy_hit_medium.wav")
const HIT_HEAVY_SFX := preload("res://asset/sounds/04_enemy_hit_heavy.wav")
const DIRECT_FLASH_DURATION := 0.16
const PERIODIC_FLASH_DURATION := 0.10
const INVULN_PULSE_HZ := 7.0

var _player
var _screen_layer: CanvasLayer
var _screen_overlay: Control
var _audio_player: AudioStreamPlayer
var _heavy_audio_player: AudioStreamPlayer
var _warning_audio_player: AudioStreamPlayer
var _hit_elapsed: float = 99.0
var _hit_duration: float = DIRECT_FLASH_DURATION
var _hit_color := Color.WHITE
var _recoil_direction := Vector2.ZERO
var _recoil_pixels: float = 0.0
var _severity: float = 0.0
var _invulnerable: bool = false
var _invuln_elapsed: float = 0.0
var _cached_self_modulates: Dictionary = {}
var _cached_extra_scales: Dictionary = {}


func setup(player) -> void:
	_player = player
	_cache_visual_defaults()
	_ensure_screen_overlay()
	_ensure_audio_players()
	set_process(true)


func play_damage(result: DamageResult, attack: Attack) -> Dictionary:
	if _player == null or result == null or not result.applied:
		return {}
	var max_hp: int = max(1, int(_player.PlayerData.player_max_hp))
	var severity := clampf(float(result.final_damage) / float(max_hp), 0.0, 1.0)
	var source_direction := _resolve_source_direction(attack)
	var screen_direction := _world_to_screen_direction(source_direction)
	var is_heavy := not result.is_periodic and (
		severity >= 0.20 or _is_attack_from_elite_or_boss(attack)
	)
	var current_hp: int = max(0, int(_player.PlayerData.player_hp))
	var previous_hp := mini(max_hp, current_hp + result.final_damage)
	var crossed_warning := float(previous_hp) / float(max_hp) > 0.35 and float(current_hp) / float(max_hp) <= 0.35
	var crossed_critical := float(previous_hp) / float(max_hp) > 0.18 and float(current_hp) / float(max_hp) <= 0.18
	_hit_elapsed = 0.0
	_hit_duration = PERIODIC_FLASH_DURATION if result.is_periodic else DIRECT_FLASH_DURATION
	_hit_color = _flash_color(result.damage_type, result.is_periodic)
	_recoil_direction = -screen_direction
	_recoil_pixels = (1.5 if result.is_periodic else lerpf(2.5, 6.0, severity))
	_severity = severity
	_spawn_impact_ring(result.damage_type, severity, result.is_periodic)
	_spawn_world_damage_label(result.final_damage, result.damage_type, result.is_periodic, is_heavy)
	if _screen_overlay != null:
		_screen_overlay.play_hit(screen_direction, 0.45 + severity * 0.55, result.damage_type, result.is_periodic)
	_play_damage_audio(result.damage_type, severity, result.is_periodic, is_heavy)
	if crossed_warning or crossed_critical:
		_play_low_health_warning(crossed_critical)
	if is_heavy and _player.has_method("request_camera_shake"):
		var source_position := Vector2.ZERO
		if attack != null and attack.source_node != null and is_instance_valid(attack.source_node) and attack.source_node is Node2D:
			source_position = (attack.source_node as Node2D).global_position
		_player.call("request_camera_shake", lerpf(0.14, 0.28, severity), source_position)
		if TimeImpactController != null and TimeImpactController.has_method("trigger_player_damage_impact"):
			TimeImpactController.trigger_player_damage_impact(severity)
	return {
		"final_damage": result.final_damage,
		"damage_type": result.damage_type,
		"is_periodic": result.is_periodic,
		"is_heavy": is_heavy,
		"is_killing_blow": result.killed,
		"severity": severity,
		"direction": screen_direction,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"previous_hp": previous_hp,
	}


func set_invulnerable(active: bool) -> void:
	if _invulnerable == active:
		return
	_invulnerable = active
	_invuln_elapsed = 0.0
	if not active and _hit_elapsed >= _hit_duration:
		_restore_visuals()


func is_invulnerability_feedback_active() -> bool:
	return _invulnerable


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if _player != null and is_instance_valid(_player) and _player.has_method("is_invulnerable"):
		set_invulnerable(bool(_player.call("is_invulnerable")))
	_hit_elapsed += safe_delta
	_invuln_elapsed += safe_delta
	_update_player_visuals()


func _update_player_visuals() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var hit_active := _hit_elapsed < _hit_duration
	var hit_progress := clampf(_hit_elapsed / maxf(_hit_duration, 0.001), 0.0, 1.0)
	var flash_strength := sin(hit_progress * PI) if hit_active else 0.0
	var invuln_alpha := 1.0
	if _invulnerable:
		invuln_alpha = lerpf(0.66, 1.0, (sin(_invuln_elapsed * TAU * INVULN_PULSE_HZ) + 1.0) * 0.5)
	for visual in _get_player_visuals():
		if visual == null or not is_instance_valid(visual):
			continue
		var base_modulate: Color = _cached_self_modulates.get(visual.get_instance_id(), Color.WHITE)
		if hit_active:
			visual.self_modulate = base_modulate.lerp(_hit_color, flash_strength * (0.78 if _hit_duration == DIRECT_FLASH_DURATION else 0.48))
		else:
			visual.self_modulate = base_modulate
		visual.self_modulate.a = base_modulate.a * invuln_alpha
		if "screen_feedback_offset" in visual:
			var recoil_curve := sin(hit_progress * PI) if hit_active else 0.0
			visual.set("screen_feedback_offset", _recoil_direction * _recoil_pixels * recoil_curve)
		if "extra_scale" in visual:
			var base_extra: Vector2 = _cached_extra_scales.get(visual.get_instance_id(), Vector2.ONE)
			var squash := 1.0 - sin(hit_progress * PI) * lerpf(0.035, 0.085, _severity)
			visual.set("extra_scale", base_extra * squash if hit_active else base_extra)


func _cache_visual_defaults() -> void:
	for visual in _get_player_visuals():
		if visual == null or not is_instance_valid(visual):
			continue
		var id := visual.get_instance_id()
		if not _cached_self_modulates.has(id):
			_cached_self_modulates[id] = visual.self_modulate
		if "extra_scale" in visual and not _cached_extra_scales.has(id):
			_cached_extra_scales[id] = visual.get("extra_scale")


func _get_player_visuals() -> Array[CanvasItem]:
	var visuals: Array[CanvasItem] = []
	if _player == null or not is_instance_valid(_player):
		return visuals
	if _player.mecha_sprite != null and is_instance_valid(_player.mecha_sprite):
		visuals.append(_player.mecha_sprite)
	if _player.mecha_move_sprite != null and is_instance_valid(_player.mecha_move_sprite):
		visuals.append(_player.mecha_move_sprite)
	return visuals


func _restore_visuals() -> void:
	for visual in _get_player_visuals():
		if visual == null or not is_instance_valid(visual):
			continue
		var id := visual.get_instance_id()
		visual.self_modulate = _cached_self_modulates.get(id, Color.WHITE)
		if "screen_feedback_offset" in visual:
			visual.set("screen_feedback_offset", Vector2.ZERO)
		if "extra_scale" in visual:
			visual.set("extra_scale", _cached_extra_scales.get(id, Vector2.ONE))


func _ensure_screen_overlay() -> void:
	if _screen_overlay != null and is_instance_valid(_screen_overlay):
		return
	_screen_layer = CanvasLayer.new()
	_screen_layer.name = "PlayerDamageScreenLayer"
	_screen_layer.layer = 80
	add_child(_screen_layer)
	_screen_overlay = SCREEN_OVERLAY_SCRIPT.new() as Control
	_screen_overlay.name = "DamageVignette"
	_screen_layer.add_child(_screen_overlay)


func _ensure_audio_players() -> void:
	if _audio_player == null or not is_instance_valid(_audio_player):
		_audio_player = AudioStreamPlayer.new()
		_audio_player.name = "PlayerDamageAudio"
		_audio_player.bus = &"SFX"
		add_child(_audio_player)
	if _heavy_audio_player == null or not is_instance_valid(_heavy_audio_player):
		_heavy_audio_player = AudioStreamPlayer.new()
		_heavy_audio_player.name = "PlayerHeavyDamageAudio"
		_heavy_audio_player.bus = &"SFX"
		add_child(_heavy_audio_player)
	if _warning_audio_player == null or not is_instance_valid(_warning_audio_player):
		_warning_audio_player = AudioStreamPlayer.new()
		_warning_audio_player.name = "PlayerLowHealthAudio"
		_warning_audio_player.bus = &"SFX"
		add_child(_warning_audio_player)


func _play_damage_audio(
	damage_type: StringName,
	severity: float,
	is_periodic: bool,
	is_heavy: bool
) -> void:
	_ensure_audio_players()
	var frequency := 170.0
	match Attack.normalize_damage_type(damage_type):
		Attack.TYPE_FIRE:
			frequency = 0.90
		Attack.TYPE_FREEZE:
			frequency = 1.16
		Attack.TYPE_ENERGY:
			frequency = 1.06
		_:
			frequency = 1.0
	_audio_player.stream = HIT_TINY_SFX if is_periodic else (HIT_MEDIUM_SFX if severity >= 0.20 else HIT_LIGHT_SFX)
	_audio_player.volume_db = -10.0 if is_periodic else lerpf(-5.0, -1.0, severity)
	_audio_player.pitch_scale = frequency * (1.12 if is_periodic else 1.0)
	_audio_player.play()
	if is_heavy:
		_heavy_audio_player.stream = HIT_HEAVY_SFX
		_heavy_audio_player.volume_db = -1.5
		_heavy_audio_player.pitch_scale = 0.92
		_heavy_audio_player.play()


func _play_low_health_warning(critical: bool) -> void:
	_warning_audio_player.stream = HIT_MEDIUM_SFX
	_warning_audio_player.volume_db = -2.0 if critical else -4.0
	_warning_audio_player.pitch_scale = 1.42 if critical else 1.28
	_warning_audio_player.play()


func _spawn_impact_ring(damage_type: StringName, severity: float, is_periodic: bool) -> void:
	if _player == null or not is_instance_valid(_player) or _player.get_tree() == null:
		return
	var ring: Node2D = IMPACT_RING_SCRIPT.new() as Node2D
	ring.name = "DamageImpactRing"
	ring.setup(damage_type, severity, is_periodic)
	var fallback: Vector2 = _player.get_viewport().get_canvas_transform() * _player.global_position
	ring.position = PROJECTED_UI.project_to_screen(_player.get_tree(), _player.global_position, fallback)
	_ensure_screen_overlay()
	_screen_layer.add_child(ring)


func _spawn_world_damage_label(
	damage: int,
	damage_type: StringName,
	is_periodic: bool,
	is_heavy: bool
) -> void:
	if _player == null or not is_instance_valid(_player) or _player.get_tree() == null:
		return
	var label := Label.new()
	label.name = "PlayerDamageNumber"
	label.text = "-%d%s" % [damage, "!" if is_heavy else ""]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(86.0, 26.0)
	label.pivot_offset = label.size * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17 if is_heavy else (12 if is_periodic else 14))
	label.add_theme_color_override("font_color", _label_color(damage_type, is_periodic))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.01, 0.96))
	label.add_theme_constant_override("outline_size", 3)
	var fallback: Vector2 = _player.get_viewport().get_canvas_transform() * _player.global_position
	var screen_position: Vector2 = PROJECTED_UI.project_to_screen(
		_player.get_tree(),
		_player.global_position,
		fallback
	)
	label.position = (screen_position + Vector2(-43.0, -70.0)).round()
	_ensure_screen_overlay()
	_screen_layer.add_child(label)
	var tween := label.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - (22.0 if is_periodic else 34.0), 0.48)
	tween.tween_property(label, "modulate:a", 0.0, 0.48).set_delay(0.12 if not is_periodic else 0.04)
	tween.chain().tween_callback(label.queue_free)


func _label_color(damage_type: StringName, is_periodic: bool) -> Color:
	var color := Color(1.0, 0.32, 0.22, 1.0)
	match Attack.normalize_damage_type(damage_type):
		Attack.TYPE_FIRE:
			color = Color(1.0, 0.48, 0.10, 1.0)
		Attack.TYPE_FREEZE:
			color = Color(0.36, 0.92, 1.0, 1.0)
		Attack.TYPE_ENERGY:
			color = Color(0.82, 0.58, 1.0, 1.0)
	if is_periodic:
		color.a = 0.78
	return color


func _resolve_source_direction(attack: Attack) -> Vector2:
	if attack == null or _player == null:
		return Vector2.ZERO
	if attack.source_node != null and is_instance_valid(attack.source_node) and attack.source_node is Node2D:
		var direction: Vector2 = (attack.source_node as Node2D).global_position - _player.global_position
		if direction.length_squared() > 0.0001:
			return direction.normalized()
	var knockback_direction: Variant = attack.knock_back.get("angle", Vector2.ZERO)
	if knockback_direction is Vector2 and (knockback_direction as Vector2).length_squared() > 0.0001:
		return -(knockback_direction as Vector2).normalized()
	return Vector2.ZERO


func _world_to_screen_direction(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO or _player == null:
		return Vector2.ZERO
	var visual = _player.mecha_sprite
	if visual != null and is_instance_valid(visual) and visual.has_method("world_direction_to_screen"):
		return visual.call("world_direction_to_screen", direction) as Vector2
	return direction.normalized()


func _flash_color(damage_type: StringName, is_periodic: bool) -> Color:
	var color := Color(1.0, 0.86, 0.82, 1.0)
	match Attack.normalize_damage_type(damage_type):
		Attack.TYPE_FIRE:
			color = Color(1.0, 0.34, 0.10, 1.0)
		Attack.TYPE_FREEZE:
			color = Color(0.55, 0.92, 1.0, 1.0)
		Attack.TYPE_ENERGY:
			color = Color(0.82, 0.58, 1.0, 1.0)
	if is_periodic:
		color = color.lerp(Color.WHITE, 0.25)
	return color


func _is_attack_from_elite_or_boss(attack: Attack) -> bool:
	if attack == null or attack.source_node == null or not is_instance_valid(attack.source_node):
		return false
	var current: Node = attack.source_node
	while current != null:
		if current is EliteEnemy or current.is_in_group(&"boss"):
			return true
		var boss_value: Variant = current.get("is_boss")
		if boss_value != null and bool(boss_value):
			return true
		current = current.get_parent()
	return false


func shutdown() -> void:
	_restore_visuals()
	set_process(false)
	if _screen_overlay != null and is_instance_valid(_screen_overlay) and _screen_overlay.has_method("shutdown"):
		_screen_overlay.call("shutdown")
	for audio_player in [_audio_player, _heavy_audio_player, _warning_audio_player]:
		if audio_player != null and is_instance_valid(audio_player):
			audio_player.stop()
			audio_player.stream = null
	_player = null


func _exit_tree() -> void:
	shutdown()
