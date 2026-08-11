extends Node2D
class_name ConeSprayAfterimageVfx

var _sprite_frames: SpriteFrames
var _animation_name: StringName = &"spray"
var _origin := Vector2.ZERO
var _direction := Vector2.RIGHT
var _range := 1.0
var _half_angle_deg := 1.0
var _base_color := Color.WHITE
var _lifetime_sec := 0.35
var _remaining_sec := 0.0
var _drift_px := 0.0
var _end_scale := 0.82
var _spread_scale := 1.08
var _sparkle_strength := 0.0
var _cold_style := false
var _base_range_px := 256.0
var _base_half_angle_deg := 40.0
var _min_width_scale := 0.1
var _max_width_scale := 1.5
var _visual_width_multiplier := 1.0
var _sprite_position := Vector2.ZERO
var _visual_version := 0
var _hybrid_config: Dictionary = {}
var _hybrid_registered := false
var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	add_to_group(&"hybrid_ground_cone_effect")
	_ensure_sprite()
	visible = false
	set_physics_process(false)


func activate(config: Dictionary) -> void:
	_sprite_frames = config.get("sprite_frames") as SpriteFrames
	_animation_name = config.get("animation_name", &"spray") as StringName
	_origin = config.get("origin", Vector2.ZERO) as Vector2
	_direction = config.get("direction", Vector2.RIGHT) as Vector2
	_direction = _direction.normalized() if _direction != Vector2.ZERO else Vector2.RIGHT
	_range = maxf(float(config.get("range", 1.0)), 1.0)
	_half_angle_deg = maxf(float(config.get("half_angle_degrees", 1.0)), 1.0)
	_base_color = config.get("color", Color.WHITE) as Color
	_lifetime_sec = maxf(float(config.get("lifetime_sec", 0.35)), 0.05)
	_remaining_sec = _lifetime_sec
	_drift_px = maxf(float(config.get("drift_px", 0.0)), 0.0)
	_end_scale = clampf(float(config.get("end_scale", 0.82)), 0.2, 1.5)
	_spread_scale = clampf(float(config.get("spread_scale", 1.08)), 0.5, 2.0)
	_sparkle_strength = clampf(float(config.get("sparkle_strength", 0.0)), 0.0, 1.0)
	_cold_style = bool(config.get("cold_style", false))
	_base_range_px = maxf(float(config.get("base_range_px", 256.0)), 1.0)
	_base_half_angle_deg = maxf(float(config.get("base_half_angle_deg", 40.0)), 1.0)
	_min_width_scale = maxf(float(config.get("min_width_scale", 0.1)), 0.01)
	_max_width_scale = maxf(float(config.get("max_width_scale", 1.5)), _min_width_scale)
	_visual_width_multiplier = maxf(float(config.get("visual_width_multiplier", 1.0)), 0.01)
	_sprite_position = config.get("sprite_position", Vector2.ZERO) as Vector2
	global_position = _origin
	visible = true
	modulate = _base_color
	_configure_sprite(int(config.get("start_frame", 0)))
	_hybrid_registered = HybridGroundRegistration.register(self, &"register_ground_cone_effect")
	if not _hybrid_registered:
		set_meta(&"hybrid_ground_registered", false)
	_update_fallback_transform(0.0)
	_visual_version += 1
	set_physics_process(true)


func deactivate() -> void:
	visible = false
	_remaining_sec = 0.0
	set_physics_process(false)
	if _sprite != null:
		_sprite.stop()
	HybridGroundRegistration.unregister(self)
	_hybrid_registered = false
	set_meta(&"hybrid_ground_registered", false)


func cleanup_for_battle_end() -> void:
	deactivate()


func is_active() -> bool:
	return visible and _remaining_sec > 0.0


func get_remaining_ratio() -> float:
	return clampf(_remaining_sec / maxf(_lifetime_sec, 0.001), 0.0, 1.0)


func get_snapshot_origin() -> Vector2:
	return _origin


func get_snapshot_direction() -> Vector2:
	return _direction


func _physics_process(delta: float) -> void:
	if not is_active():
		return
	_remaining_sec = maxf(_remaining_sec - maxf(delta, 0.0), 0.0)
	var progress := 1.0 - get_remaining_ratio()
	var fade := pow(get_remaining_ratio(), 1.35 if _cold_style else 1.7)
	modulate = _base_color
	modulate.a *= fade
	_update_fallback_transform(progress)
	queue_redraw()
	_visual_version += 1
	if _remaining_sec <= 0.0:
		deactivate()


func get_hybrid_ground_cone_visual() -> Dictionary:
	var progress := 1.0 - get_remaining_ratio()
	var length_scale := lerpf(1.0, _end_scale, progress)
	var width_scale := lerpf(1.0, _spread_scale, progress)
	_hybrid_config["visible"] = is_active()
	_hybrid_config["origin"] = global_position
	_hybrid_config["direction"] = _direction
	_hybrid_config["range"] = _range * length_scale
	_hybrid_config["half_angle_degrees"] = _half_angle_deg * width_scale
	_hybrid_config["color"] = modulate
	_hybrid_config["body_opacity"] = 0.5
	_hybrid_config["range_cue_opacity"] = 0.0
	_hybrid_config["core_highlight_strength"] = 0.12
	_hybrid_config["texture"] = _get_current_frame_texture()
	_hybrid_config["visual_version"] = _visual_version
	return _hybrid_config


func _ensure_sprite() -> void:
	if _sprite != null:
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "AfterimageSprite"
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _configure_sprite(start_frame: int) -> void:
	_ensure_sprite()
	_sprite.sprite_frames = _sprite_frames
	if _sprite_frames == null:
		return
	if not _sprite_frames.has_animation(_animation_name):
		var names := _sprite_frames.get_animation_names()
		if names.is_empty():
			return
		_animation_name = StringName(names[0])
	_sprite.animation = _animation_name
	var frame_count := _sprite_frames.get_frame_count(_animation_name)
	_sprite.frame = clampi(start_frame, 0, maxi(frame_count - 1, 0))
	_sprite.play()


func _update_fallback_transform(progress: float) -> void:
	var side := _direction.orthogonal()
	var lift_direction := Vector2.UP if not _cold_style else side * (-1.0 if get_instance_id() % 2 == 0 else 1.0)
	global_position = _origin + lift_direction * _drift_px * progress
	global_rotation = _direction.angle()
	if _sprite == null:
		return
	var length_scale := (_range / _base_range_px) * lerpf(1.0, _end_scale, progress)
	var authored_width := (_half_angle_deg / _base_half_angle_deg) * _visual_width_multiplier
	var width_scale := clampf(authored_width, _min_width_scale, _max_width_scale) * lerpf(1.0, _spread_scale, progress)
	_sprite.position = _sprite_position
	_sprite.scale = Vector2(maxf(length_scale, 0.01), maxf(width_scale, 0.01))
	_sprite.visible = not bool(get_meta(&"hybrid_ground_registered", false))


func _draw() -> void:
	if not is_active() or bool(get_meta(&"hybrid_ground_registered", false)):
		return
	var progress := 1.0 - get_remaining_ratio()
	var particle_color := modulate
	particle_color.a *= 0.7
	var particle_count := 2 + int(round(_sparkle_strength * 4.0))
	for index in range(particle_count):
		var ratio := float(index + 1) / float(particle_count + 1)
		var edge_sign := -1.0 if index % 2 == 0 else 1.0
		var point := Vector2.RIGHT.rotated(deg_to_rad(_half_angle_deg * edge_sign)) * _range * ratio
		point += Vector2.UP * progress * (5.0 + float(index) * 2.0)
		var radius := 1.0 + _sparkle_strength * (2.0 if _cold_style else 1.4)
		draw_circle(point, radius, particle_color)


func _get_current_frame_texture() -> Texture2D:
	if _sprite == null or _sprite.sprite_frames == null:
		return null
	if not _sprite.sprite_frames.has_animation(_sprite.animation):
		return null
	var frame_count := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	if frame_count <= 0:
		return null
	return _sprite.sprite_frames.get_frame_texture(_sprite.animation, clampi(_sprite.frame, 0, frame_count - 1))


func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)
