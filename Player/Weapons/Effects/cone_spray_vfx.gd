extends Node2D
class_name ConeSprayVfx

const AFTERIMAGE_SCRIPT := preload("res://Player/Weapons/Effects/cone_spray_afterimage_vfx.gd")
const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")

@export var sprite_frames: SpriteFrames = preload("res://asset/images/effects/flame_spray/flame_spray_frames.tres")
@export var animation_name: StringName = &"spray"
@export var linger_sec: float = 0.16
@export var fade_out_sec: float = 0.1
@export var muzzle_offset_px: float = 20.0
@export var base_range_px: float = 256.0
@export var base_half_angle_deg: float = 40.0
@export var min_width_scale: float = 0.45
@export var max_width_scale: float = 1.35
@export var visual_width_multiplier: float = 1.08
@export var playback_speed: float = 1.0
@export var visible_modulate: Color = Color(1.0, 1.0, 1.0, 0.88)
@export_group("Readability Layers")
@export_range(0.0, 1.0, 0.01) var body_opacity := 0.68
@export_range(0.0, 1.0, 0.01) var range_cue_opacity := 0.24
@export_range(0.0, 1.0, 0.01) var core_highlight_strength := 0.34
@export var range_cue_color := PALETTE.FIRE
@export var core_highlight_color := PALETTE.FIRE_CORE
@export_group("Directional Trail")
@export var trail_enabled := true
@export_range(1, 12, 1) var trail_max_afterimages := 5
@export_range(0.02, 0.3, 0.01) var trail_min_sample_interval_sec := 0.07
@export_range(1.0, 30.0, 0.5) var trail_slow_turn_threshold_deg := 9.0
@export_range(1.0, 30.0, 0.5) var trail_fast_turn_threshold_deg := 5.0
@export_range(30.0, 1080.0, 10.0) var trail_fast_turn_speed_deg_sec := 300.0
@export_range(1.0, 64.0, 1.0) var trail_position_threshold_px := 15.0
@export_range(0.05, 1.5, 0.01) var trail_lifetime_sec := 0.34
@export_range(0.0, 30.0, 0.5) var trail_drift_px := 8.0
@export_range(0.2, 1.5, 0.01) var trail_end_scale := 0.80
@export_range(0.5, 2.0, 0.01) var trail_spread_scale := 1.08
@export_range(0.0, 1.0, 0.05) var trail_sparkle_strength := 0.65
@export var trail_cold_style := false
@export var trail_modulate: Color = Color(PALETTE.FIRE, 0.42)

@onready var spray_root: Node2D = $SprayRoot
@onready var sprite: AnimatedSprite2D = $SprayRoot/Sprite

var _linger_remaining_sec: float = 0.0
var _fade_remaining_sec: float = 0.0
var _last_direction: Vector2 = Vector2.RIGHT
var _last_range: float = 1.0
var _last_half_angle_deg: float = 1.0
var _ground_rays: Array[Line2D] = []
var _hybrid_registered: bool = false
var _hybrid_config: Dictionary = {}
var _hybrid_visual_version := 0
var _trail_afterimages: Array[Node] = []
var _trail_cursor := 0
var _trail_sample_elapsed_sec := 0.0
var _trail_has_sample := false
var _trail_sample_origin := Vector2.ZERO
var _trail_sample_direction := Vector2.RIGHT
var _restart_pending := false


func _ready() -> void:
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	_configure_sprite()
	_ensure_ground_rays()
	_hide_now()

func cleanup_for_battle_end() -> void:
	_hide_now()
	_clear_trail()
	_restart_pending = false


func start_or_refresh(source_global_position: Vector2, direction: Vector2, spray_range: float, half_angle_deg: float) -> void:
	if _restart_pending:
		_clear_trail()
		_restart_pending = false
	# Board rebuilds clear the 3D ground-effect cache while this weapon-owned
	# node survives between battles. Re-registering is idempotent and restores
	# the cone after the cache has been rebuilt.
	_hybrid_registered = HybridGroundRegistration.register(self, &"register_ground_cone_effect")
	if not _hybrid_registered:
		set_meta(&"hybrid_ground_registered", false)
	if direction == Vector2.ZERO:
		direction = _last_direction
	_consider_trail_sample(source_global_position, direction.normalized(), spray_range, half_angle_deg)
	_last_direction = direction.normalized()
	_last_range = maxf(spray_range, 1.0)
	_last_half_angle_deg = maxf(half_angle_deg, 1.0)
	_linger_remaining_sec = maxf(linger_sec, 0.01)
	_fade_remaining_sec = maxf(fade_out_sec, 0.01)
	visible = true
	modulate = visible_modulate
	_update_transform(source_global_position)
	_update_ground_rays()
	if sprite != null and not sprite.is_playing():
		sprite.play()


func update_aim(source_global_position: Vector2, direction: Vector2, spray_range: float, half_angle_deg: float) -> void:
	if not is_visible_or_fading():
		return
	if direction != Vector2.ZERO:
		_consider_trail_sample(source_global_position, direction.normalized(), spray_range, half_angle_deg)
		_last_direction = direction.normalized()
	_last_range = maxf(spray_range, 1.0)
	_last_half_angle_deg = maxf(half_angle_deg, 1.0)
	_update_transform(source_global_position)
	_update_ground_rays()


func is_visible_or_fading() -> bool:
	return visible and (_linger_remaining_sec > 0.0 or _fade_remaining_sec > 0.0)


func stop() -> void:
	_restart_pending = true
	if not visible:
		return
	if _linger_remaining_sec <= 0.0 and _fade_remaining_sec > 0.0:
		return
	_linger_remaining_sec = 0.0
	_fade_remaining_sec = maxf(fade_out_sec, 0.01)
	_trail_has_sample = false


func _physics_process(delta: float) -> void:
	_trail_sample_elapsed_sec += maxf(delta, 0.0)
	if not visible:
		return
	var step: float = maxf(delta, 0.0)
	if _linger_remaining_sec > 0.0:
		_linger_remaining_sec = maxf(_linger_remaining_sec - step, 0.0)
		modulate = visible_modulate
		return
	_fade_remaining_sec = maxf(_fade_remaining_sec - step, 0.0)
	var fade_duration: float = maxf(fade_out_sec, 0.001)
	var alpha_ratio: float = clampf(_fade_remaining_sec / fade_duration, 0.0, 1.0)
	var next_modulate: Color = visible_modulate
	next_modulate.a *= alpha_ratio
	modulate = next_modulate
	if _fade_remaining_sec <= 0.0:
		_hide_now()


func _configure_sprite() -> void:
	if sprite == null:
		return
	sprite.sprite_frames = sprite_frames
	sprite.speed_scale = maxf(playback_speed, 0.01)
	var resolved_animation := _resolve_animation_name()
	if resolved_animation != StringName():
		sprite.animation = resolved_animation
		sprite.play()


func _resolve_animation_name() -> StringName:
	if sprite_frames == null:
		return StringName()
	if sprite_frames.has_animation(animation_name):
		return animation_name
	var names: PackedStringArray = sprite_frames.get_animation_names()
	if names.is_empty():
		return StringName()
	return StringName(names[0])


func _update_transform(source_global_position: Vector2) -> void:
	global_position = source_global_position + _last_direction * muzzle_offset_px
	global_rotation = _last_direction.angle()
	var length_scale: float = _get_visual_range() / maxf(base_range_px, 1.0)
	var angle_scale: float = _last_half_angle_deg / maxf(base_half_angle_deg, 1.0)
	var width_scale: float = clampf(angle_scale * maxf(visual_width_multiplier, 0.01), min_width_scale, max_width_scale)
	spray_root.scale = Vector2(maxf(length_scale, 0.01), maxf(width_scale, 0.01))
	spray_root.visible = not bool(get_meta(&"hybrid_ground_registered", false))

func _ensure_ground_rays() -> void:
	add_to_group(&"hybrid_ground_cone_effect")
	_hybrid_registered = HybridGroundRegistration.register(self, &"register_ground_cone_effect")
	if _ground_rays.is_empty():
		for ray_index in range(3):
			var line := Line2D.new()
			line.name = "RangeCue%d" % ray_index
			line.width = 2.0
			line.antialiased = false
			line.z_index = -1
			add_child(line)
			_ground_rays.append(line)
	_update_ground_rays()

func _update_ground_rays() -> void:
	if _ground_rays.size() < 3:
		return
	var fallback_visible := visible and not bool(get_meta(&"hybrid_ground_registered", false))
	var cue := range_cue_color
	cue.a *= range_cue_opacity
	var visual_range := _get_visual_range()
	var left_edge := Vector2.RIGHT.rotated(deg_to_rad(-_last_half_angle_deg)) * visual_range
	var right_edge := Vector2.RIGHT.rotated(deg_to_rad(_last_half_angle_deg)) * visual_range
	_ground_rays[0].points = PackedVector2Array([Vector2.ZERO, left_edge])
	_ground_rays[1].points = PackedVector2Array([Vector2.ZERO, right_edge])
	var arc_points := PackedVector2Array()
	for index in range(9):
		var ratio := float(index) / 8.0
		arc_points.append(Vector2.RIGHT.rotated(deg_to_rad(lerpf(-_last_half_angle_deg, _last_half_angle_deg, ratio))) * visual_range)
	_ground_rays[2].points = arc_points
	for line in _ground_rays:
		line.default_color = cue
		line.visible = fallback_visible

func get_hybrid_ground_cone_visual() -> Dictionary:
	var color := modulate
	var changed := _set_hybrid_value(&"visible", visible)
	changed = _set_hybrid_value(&"origin", global_position) or changed
	changed = _set_hybrid_value(&"direction", _last_direction) or changed
	changed = _set_hybrid_value(&"range", _get_visual_range()) or changed
	changed = _set_hybrid_value(&"half_angle_degrees", _last_half_angle_deg) or changed
	changed = _set_hybrid_value(&"color", color) or changed
	changed = _set_hybrid_value(&"body_opacity", body_opacity) or changed
	changed = _set_hybrid_value(&"range_cue_opacity", range_cue_opacity) or changed
	changed = _set_hybrid_value(&"core_highlight_strength", core_highlight_strength) or changed
	changed = _set_hybrid_value(&"range_cue_color", range_cue_color) or changed
	changed = _set_hybrid_value(&"core_highlight_color", core_highlight_color) or changed
	changed = _set_hybrid_value(&"texture", _get_current_frame_texture()) or changed
	if changed:
		_hybrid_visual_version += 1
	_hybrid_config["visual_version"] = _hybrid_visual_version
	return _hybrid_config


func _set_hybrid_value(key: StringName, value: Variant) -> bool:
	if _hybrid_config.has(key) and _hybrid_config[key] == value:
		return false
	_hybrid_config[key] = value
	return true


func _get_current_frame_texture() -> Texture2D:
	if sprite == null or sprite.sprite_frames == null:
		return null
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return null
	var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if frame_count <= 0:
		return null
	return sprite.sprite_frames.get_frame_texture(sprite.animation, clampi(sprite.frame, 0, frame_count - 1))

func _get_visual_range() -> float:
	# The cone starts at the muzzle offset, so subtract that offset from its
	# rendered length. The visible tip then lands on the unchanged hit radius.
	return maxf(_last_range - maxf(muzzle_offset_px, 0.0), 1.0)

func _exit_tree() -> void:
	_clear_trail()
	HybridGroundRegistration.unregister(self)
	_hybrid_registered = false


func _hide_now() -> void:
	visible = false
	_linger_remaining_sec = 0.0
	_fade_remaining_sec = 0.0
	if sprite != null:
		sprite.stop()
	for line in _ground_rays:
		line.set_meta("hybrid_ground_visible", false)
		line.visible = false


func get_active_trail_afterimages() -> Array[Node]:
	var active: Array[Node] = []
	for afterimage in _trail_afterimages:
		if afterimage != null and is_instance_valid(afterimage) and bool(afterimage.call("is_active")):
			active.append(afterimage)
	return active


func _consider_trail_sample(source_position: Vector2, direction: Vector2, spray_range: float, half_angle_deg: float) -> void:
	if not trail_enabled or direction == Vector2.ZERO:
		return
	if not _trail_has_sample:
		_store_trail_sample(source_position, direction)
		return
	if _trail_sample_elapsed_sec < maxf(trail_min_sample_interval_sec, 0.01):
		return
	var angle_delta_deg := absf(rad_to_deg(_trail_sample_direction.angle_to(direction)))
	var turn_speed := angle_delta_deg / maxf(_trail_sample_elapsed_sec, 0.001)
	var speed_ratio := clampf(turn_speed / maxf(trail_fast_turn_speed_deg_sec, 1.0), 0.0, 1.0)
	var angle_threshold := lerpf(trail_slow_turn_threshold_deg, trail_fast_turn_threshold_deg, speed_ratio)
	var moved_far_enough := _trail_sample_origin.distance_to(source_position) >= maxf(trail_position_threshold_px, 1.0)
	if angle_delta_deg < angle_threshold and not moved_far_enough:
		return
	_spawn_trail_afterimage(_trail_sample_origin, _trail_sample_direction, spray_range, half_angle_deg)
	_store_trail_sample(source_position, direction)


func _store_trail_sample(source_position: Vector2, direction: Vector2) -> void:
	_trail_has_sample = true
	_trail_sample_origin = source_position
	_trail_sample_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_trail_sample_elapsed_sec = 0.0


func _spawn_trail_afterimage(origin: Vector2, direction: Vector2, spray_range: float, half_angle_deg: float) -> void:
	var afterimage: Node = _acquire_trail_afterimage()
	if afterimage == null:
		return
	afterimage.call("activate", {
		"sprite_frames": sprite_frames,
		"animation_name": animation_name,
		"start_frame": sprite.frame if sprite != null else 0,
		"origin": origin + direction * muzzle_offset_px,
		"direction": direction,
		"range": maxf(spray_range - maxf(muzzle_offset_px, 0.0), 1.0),
		"half_angle_degrees": maxf(half_angle_deg, 1.0),
		"color": trail_modulate,
		"lifetime_sec": trail_lifetime_sec,
		"drift_px": trail_drift_px,
		"end_scale": trail_end_scale,
		"spread_scale": trail_spread_scale,
		"sparkle_strength": trail_sparkle_strength,
		"cold_style": trail_cold_style,
		"base_range_px": base_range_px,
		"base_half_angle_deg": base_half_angle_deg,
		"min_width_scale": min_width_scale,
		"max_width_scale": max_width_scale,
		"visual_width_multiplier": visual_width_multiplier,
		"sprite_position": sprite.position if sprite != null else Vector2.ZERO,
	})


func _acquire_trail_afterimage() -> Node:
	var capacity := maxi(trail_max_afterimages, 1)
	if _trail_afterimages.size() < capacity:
		var afterimage: Node = AFTERIMAGE_SCRIPT.new()
		afterimage.name = "ConeSprayAfterimage%d" % _trail_afterimages.size()
		var host := _resolve_trail_host()
		host.add_child(afterimage)
		_trail_afterimages.append(afterimage)
		return afterimage
	var reused: Node = _trail_afterimages[_trail_cursor]
	_trail_cursor = (_trail_cursor + 1) % capacity
	if reused != null and is_instance_valid(reused):
		reused.call("deactivate")
	return reused


func _resolve_trail_host() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		return scene
	return get_tree().root


func _clear_trail() -> void:
	_trail_has_sample = false
	_trail_sample_elapsed_sec = 0.0
	for afterimage in _trail_afterimages:
		if afterimage == null or not is_instance_valid(afterimage):
			continue
		afterimage.call("deactivate")
		afterimage.queue_free()
	_trail_afterimages.clear()
	_trail_cursor = 0
