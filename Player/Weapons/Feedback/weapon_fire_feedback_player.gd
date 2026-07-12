extends RefCounted
class_name WeaponFireFeedbackPlayer

const MuzzleFlashVfxScript := preload("res://Player/Weapons/Feedback/muzzle_flash_vfx.gd")

var weapon: Node2D
var _last_feedback_msec: int = -1000000
var _last_hit_feedback_msec: int = -1000000
var _sprite_tween: Tween
var _fuse_tween: Tween
var _sprite_base_position := Vector2.ZERO
var _sprite_base_rotation: float = 0.0
var _sprite_base_cached: bool = false
var _fuse_base_position := Vector2.ZERO
var _fuse_base_rotation: float = 0.0
var _fuse_base_cached: bool = false


func setup(source_weapon: Node2D) -> void:
	weapon = source_weapon


func play(profile: Resource, direction: Vector2 = Vector2.ZERO, play_audio: bool = true) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if profile == null:
		return false
	var now := Time.get_ticks_msec()
	var cooldown_msec := int(round(maxf(float(profile.get("feedback_cooldown_sec")), 0.0) * 1000.0))
	if cooldown_msec > 0 and now - _last_feedback_msec < cooldown_msec:
		return false
	_last_feedback_msec = now
	var resolved_direction := _resolve_direction(direction)
	_spawn_muzzle_flash(profile, resolved_direction)
	_play_recoil(profile, resolved_direction)
	_request_camera_shake(profile)
	if play_audio:
		_play_fire_audio(profile)
	weapon.set_meta(&"_last_fire_feedback_msec", now)
	return true


func play_hit(profile: Resource, target: Node = null) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if profile == null:
		return false
	var stream := profile.get("hit_audio_stream") as AudioStream
	if stream == null:
		return false
	var now := Time.get_ticks_msec()
	var cooldown_msec := int(round(maxf(float(profile.get("hit_feedback_cooldown_sec")), 0.0) * 1000.0))
	if cooldown_msec > 0 and now - _last_hit_feedback_msec < cooldown_msec:
		return false
	_last_hit_feedback_msec = now
	var audio_position := weapon.global_position
	if target is Node2D and is_instance_valid(target):
		audio_position = (target as Node2D).global_position
	_play_audio_stream(
		stream,
		audio_position,
		float(profile.get("hit_audio_volume_db")),
		float(profile.get("hit_audio_pitch_scale")),
		float(profile.get("hit_audio_pitch_random")),
		float(profile.get("audio_max_distance")),
		float(profile.get("audio_attenuation"))
	)
	weapon.set_meta(&"_last_hit_feedback_msec", now)
	return true


func _resolve_direction(direction: Vector2) -> Vector2:
	if direction != Vector2.ZERO:
		return direction.normalized()
	if weapon != null and weapon.has_method("get_fire_feedback_direction"):
		var value: Variant = weapon.call("get_fire_feedback_direction")
		if value is Vector2 and value != Vector2.ZERO:
			return (value as Vector2).normalized()
	return Vector2.RIGHT.rotated(weapon.global_rotation)


func _spawn_muzzle_flash(profile: Resource, direction: Vector2) -> void:
	var muzzle_flash_scene := profile.get("muzzle_flash_scene") as PackedScene
	if muzzle_flash_scene == null:
		return
	var tree := weapon.get_tree()
	if tree == null:
		return
	var vfx := muzzle_flash_scene.instantiate() as Node2D
	if vfx == null:
		return
	tree.root.add_child(vfx)
	var muzzle_position := _get_muzzle_global_position(direction)
	var visual_position := muzzle_position
	var visual_direction := direction
	var hybrid_view := _get_hybrid_view()
	if hybrid_view != null:
		visual_position = hybrid_view.call("project_world_to_canvas", muzzle_position, weapon.get_viewport()) as Vector2
		visual_direction = hybrid_view.call("world_vector_to_screen", direction, muzzle_position) as Vector2
		if visual_direction != Vector2.ZERO:
			visual_direction = visual_direction.normalized()
	vfx.global_position = visual_position
	if vfx.has_method("setup"):
		vfx.call("setup", visual_direction)
	else:
		vfx.global_rotation = visual_direction.angle()


func _get_muzzle_global_position(direction: Vector2) -> Vector2:
	if weapon.has_method("get_muzzle_global_position"):
		var value: Variant = weapon.call("get_muzzle_global_position")
		if value is Vector2:
			return value as Vector2
	var muzzle := weapon.get_node_or_null("Muzzle") as Node2D
	if muzzle != null:
		return muzzle.global_position
	return weapon.global_position + direction.normalized() * 18.0


func _play_recoil(profile: Resource, direction: Vector2) -> void:
	var recoil_distance := float(profile.get("recoil_distance"))
	var recoil_rotation_deg := float(profile.get("recoil_rotation_deg"))
	if recoil_distance <= 0.0 and is_zero_approx(recoil_rotation_deg):
		return
	var sprite := weapon.get("sprite") as Node2D
	_play_node_recoil(sprite, true, profile, direction)
	var fuse_holder := weapon.get("fuse_sprite_holder") as Node2D
	if fuse_holder != null:
		_play_node_recoil(fuse_holder, false, profile, direction)


func _play_node_recoil(node: Node2D, is_primary_sprite: bool, profile: Resource, direction: Vector2) -> void:
	if node == null or not is_instance_valid(node):
		return
	if is_primary_sprite:
		_cache_sprite_base(node)
		if _sprite_tween != null:
			_sprite_tween.kill()
			_sprite_tween = null
	else:
		_cache_fuse_base(node)
		if _fuse_tween != null:
			_fuse_tween.kill()
			_fuse_tween = null
	var base_position := _sprite_base_position if is_primary_sprite else _fuse_base_position
	var base_rotation := _sprite_base_rotation if is_primary_sprite else _fuse_base_rotation
	var local_recoil := _global_delta_to_parent_space(node, -direction.normalized() * maxf(float(profile.get("recoil_distance")), 0.0))
	if local_recoil == Vector2.ZERO:
		local_recoil = Vector2(0.0, maxf(float(profile.get("recoil_distance")), 0.0))
	var rotation_recoil := deg_to_rad(float(profile.get("recoil_rotation_deg")))
	var tween := node.create_tween()
	tween.set_parallel(false)
	if node.has_method("world_direction_to_screen"):
		var screen_direction := node.call("world_direction_to_screen", direction) as Vector2
		if screen_direction == Vector2.ZERO:
			screen_direction = Vector2.RIGHT
		var screen_recoil := -screen_direction.normalized() * maxf(float(profile.get("recoil_distance")), 0.0)
		tween.tween_property(node, "screen_feedback_offset", screen_recoil, maxf(float(profile.get("recoil_duration")), 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(node, "screen_feedback_rotation", rotation_recoil, maxf(float(profile.get("recoil_duration")), 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "screen_feedback_offset", Vector2.ZERO, maxf(float(profile.get("recoil_recover_duration")), 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(node, "screen_feedback_rotation", 0.0, maxf(float(profile.get("recoil_recover_duration")), 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if is_primary_sprite:
			_sprite_tween = tween
		else:
			_fuse_tween = tween
		return
	tween.tween_property(node, "position", base_position + local_recoil, maxf(float(profile.get("recoil_duration")), 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "rotation", base_rotation + rotation_recoil, maxf(float(profile.get("recoil_duration")), 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", base_position, maxf(float(profile.get("recoil_recover_duration")), 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "rotation", base_rotation, maxf(float(profile.get("recoil_recover_duration")), 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_primary_sprite:
		_sprite_tween = tween
	else:
		_fuse_tween = tween


func _cache_sprite_base(node: Node2D) -> void:
	if _sprite_base_cached:
		return
	_sprite_base_position = node.position
	_sprite_base_rotation = node.rotation
	_sprite_base_cached = true


func _global_delta_to_parent_space(node: Node2D, global_delta: Vector2) -> Vector2:
	var parent_node := node.get_parent() as Node2D
	if parent_node == null:
		return global_delta
	var base_global := node.global_position
	return parent_node.to_local(base_global + global_delta) - parent_node.to_local(base_global)


func _cache_fuse_base(node: Node2D) -> void:
	if _fuse_base_cached:
		return
	_fuse_base_position = node.position
	_fuse_base_rotation = node.rotation
	_fuse_base_cached = true

func _get_hybrid_view() -> Node:
	if weapon == null or not weapon.is_inside_tree():
		return null
	var views := weapon.get_tree().get_nodes_in_group(&"hybrid_ground_view_3d")
	return views[0] as Node if not views.is_empty() else null


func _request_camera_shake(profile: Resource) -> void:
	var camera_trauma := float(profile.get("camera_trauma"))
	if camera_trauma <= 0.0:
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	if not PlayerData.player.has_method("request_camera_shake"):
		return
	PlayerData.player.call("request_camera_shake", camera_trauma, weapon.global_position, float(profile.get("camera_max_distance")))


func _play_fire_audio(profile: Resource) -> void:
	var stream := profile.get("fire_audio_stream") as AudioStream
	if stream == null:
		return
	_play_audio_stream(
		stream,
		_get_muzzle_global_position(_resolve_direction(Vector2.ZERO)),
		float(profile.get("fire_audio_volume_db")),
		float(profile.get("fire_audio_pitch_scale")),
		float(profile.get("fire_audio_pitch_random")),
		float(profile.get("audio_max_distance")),
		float(profile.get("audio_attenuation"))
	)


func _play_audio_stream(
	stream: AudioStream,
	audio_position: Vector2,
	volume_db: float,
	pitch_scale: float,
	pitch_random: float,
	max_distance: float,
	attenuation: float
) -> void:
	if stream == null:
		return
	var tree := weapon.get_tree()
	if tree == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = audio_position
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch_scale + randf_range(-absf(pitch_random), absf(pitch_random)), 0.05)
	player.max_distance = maxf(max_distance, 1.0)
	player.attenuation = maxf(attenuation, 0.0)
	player.bus = "Master"
	tree.root.add_child(player)
	player.finished.connect(Callable(player, "queue_free"))
	player.play()
