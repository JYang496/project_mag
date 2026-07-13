extends RefCounted
class_name PlayerCameraSystem

const PlayerCameraConfigType := preload("res://Player/Mechas/scripts/player_camera_config.gd")
const FixedObliqueProjectionType := preload("res://Visual/Oblique/fixed_oblique_projection_2d.gd")

var _camera: Camera2D
var _config
var _current_vision_mul: float = 1.0
var _base_zoom := Vector2.ONE
var _initial_uniform_zoom: float = 1.0
var _zoom_target := Vector2.ONE
var _offset_target := Vector2.ZERO
var _zoom_tween: Tween
var _last_phase_is_prepare := false
var _restarea_control_enabled := false
var _restarea_pending_snap_target := Vector2.ZERO
var _restarea_pending_snap_now := false
var _restarea_camera_target := Vector2.ZERO
var _restarea_camera_moving := false
var _restarea_camera_speed_mul: float = 1.0
var _restarea_camera_min_speed: float = 900.0
var _restarea_camera_max_speed: float = 3200.0
var _restarea_camera_speed_curve: float = 4.2
var _shake_trauma: float = 0.0
var _shake_offset := Vector2.ZERO
var _shake_time: float = 0.0
var _shake_seed: float = 0.0
var _shake_max_trauma: float = 0.35
var _shake_decay_per_sec: float = 1.9
var _shake_max_offset := Vector2(14.0, 10.0)
var _hybrid_view: Node

func has_camera_binding() -> bool:
	return _camera != null

func setup(camera: Camera2D, config, vision_mul: float = 1.0) -> void:
	if _zoom_tween != null:
		_zoom_tween.kill()
		_zoom_tween = null
	_camera = camera
	_config = config
	_current_vision_mul = maxf(vision_mul, 0.05)
	if _camera != null:
		_initial_uniform_zoom = maxf(_camera.zoom.x, 0.001)
		_apply_fixed_oblique_configuration()
		_zoom_target = _base_zoom
		if _restarea_control_enabled:
			_apply_restarea_control_enabled(_restarea_pending_snap_target, _restarea_pending_snap_now)
		else:
			_apply_restarea_control_disabled()
	_last_phase_is_prepare = _is_prepare_phase()
	_refresh_zoom_target_from_context()

func _apply_fixed_oblique_configuration() -> void:
	var config = _get_config()
	var initial_uniform_zoom := _initial_uniform_zoom
	if config.hybrid_ground_enabled:
		_camera.rotation = 0.0
		_base_zoom = Vector2.ONE * initial_uniform_zoom
	elif config.fixed_oblique_enabled:
		_camera.rotation_degrees = config.fixed_camera_yaw_degrees
		# Camera2D zoom multiplies canvas axes. A smaller Y component compresses
		# the ground vertically in screen space while billboards compensate it.
		_base_zoom = Vector2(initial_uniform_zoom, initial_uniform_zoom * maxf(config.fixed_vertical_scale, 0.001)) * config.fixed_camera_overscan
	else:
		_camera.rotation = 0.0
		_base_zoom = Vector2.ONE * initial_uniform_zoom
	FixedObliqueProjectionType.configure(config.fixed_oblique_enabled and not config.hybrid_ground_enabled, config.fixed_camera_yaw_degrees, config.fixed_vertical_scale, config.billboard_scale)
	_zoom_target = _base_zoom

func reconfigure_oblique(config) -> void:
	if _camera == null:
		return
	_config = config
	if _zoom_tween != null:
		_zoom_tween.kill()
		_zoom_tween = null
	_apply_fixed_oblique_configuration()
	_refresh_zoom_target_from_context()
	_camera.zoom = _zoom_target

func tick(delta: float) -> void:
	if _camera == null:
		return
	_sync_zoom_transition_phase_edge()
	_resolve_hybrid_view()
	if _restarea_control_enabled:
		_update_zoom(delta)
		_reset_offset_for_restarea(delta)
		_update_restarea_camera_move(delta)
		return
	_update_zoom(delta)
	_update_lookahead(delta)

func request_camera_shake(amount: float, source_global_position: Vector2 = Vector2.ZERO, max_distance: float = 900.0) -> void:
	if _camera == null:
		return
	var distance_mul := 1.0
	if source_global_position != Vector2.ZERO and max_distance > 0.0:
		var distance := _camera.global_position.distance_to(source_global_position)
		distance_mul = 1.0 - clampf(distance / maxf(max_distance, 1.0), 0.0, 1.0)
	var scaled_amount := maxf(amount, 0.0) * distance_mul
	if scaled_amount <= 0.0:
		return
	_shake_trauma = minf(_shake_max_trauma, _shake_trauma + scaled_amount)

func get_camera_shake_trauma() -> float:
	return _shake_trauma

func configure_restarea_camera_motion(min_speed: float, max_speed: float, speed_curve: float) -> void:
	_restarea_camera_min_speed = maxf(min_speed, 1.0)
	_restarea_camera_max_speed = maxf(max_speed, _restarea_camera_min_speed)
	_restarea_camera_speed_curve = maxf(speed_curve, 0.1)

func set_restarea_control_enabled(enabled: bool, snap_target: Vector2 = Vector2.ZERO, snap_now: bool = false) -> void:
	_restarea_control_enabled = enabled
	_restarea_pending_snap_target = snap_target
	_restarea_pending_snap_now = snap_now
	if _camera == null:
		return
	if enabled:
		_apply_restarea_control_enabled(snap_target, snap_now)
		return
	_apply_restarea_control_disabled()

func _apply_restarea_control_enabled(snap_target: Vector2, snap_now: bool) -> void:
	if _camera == null:
		return
	var prev_global: Vector2 = _camera.global_position
	_camera.top_level = true
	_camera.offset = Vector2.ZERO
	if snap_now:
		_camera.global_position = snap_target
	else:
		# Preserve pre-toggle world pose; otherwise top_level switch may start from (0,0).
		_camera.global_position = prev_global
	_restarea_camera_target = snap_target
	_restarea_camera_moving = not snap_now
	_restarea_camera_speed_mul = 1.0

func _apply_restarea_control_disabled() -> void:
	if _camera == null:
		return
	_camera.top_level = false
	_camera.position = Vector2.ZERO
	_restarea_camera_moving = false
	_restarea_camera_speed_mul = 1.0

func move_restarea_camera_to(target_global: Vector2, speed_mul: float = 1.0) -> void:
	if not _restarea_control_enabled or _camera == null:
		return
	_restarea_camera_target = target_global
	_restarea_camera_moving = true
	_restarea_camera_speed_mul = maxf(speed_mul, 0.1)

func is_restarea_camera_close_to(target_global: Vector2, tolerance: float) -> bool:
	if _camera == null:
		return false
	return _camera.global_position.distance_to(target_global) <= maxf(tolerance, 0.0)

func get_camera_world_position() -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	return _camera.global_position

func update_zoom_target_by_vision(vision_mul: float) -> void:
	if _camera == null:
		return
	_current_vision_mul = maxf(vision_mul, 0.05)
	_sync_hybrid_view_multiplier(_get_zoom_transition_duration(_is_prepare_phase()) if _is_zoom_transition_enabled() else 0.0)
	if _get_config().hybrid_ground_enabled:
		_zoom_target = _base_zoom
		return
	if _base_zoom == Vector2.ZERO:
		_base_zoom = Vector2.ONE
	var zoom_factor := 1.0 / _get_effective_vision_mul(_current_vision_mul)
	_zoom_target = _base_zoom * zoom_factor * _get_phase_camera_zoom_factor()
	if _is_zoom_transition_enabled() and _camera.zoom.distance_to(_zoom_target) > 0.001:
		var is_prepare := _is_prepare_phase()
		var duration := _get_zoom_transition_duration(is_prepare)
		_rebuild_zoom_transition(_zoom_target, duration)

func force_zoom_now(target_zoom: Vector2) -> void:
	if _camera == null:
		return
	if _zoom_tween != null:
		_zoom_tween.kill()
		_zoom_tween = null
	_zoom_target = target_zoom
	_camera.zoom = target_zoom

func force_recover_battle_zoom(vision_mul: float) -> void:
	if _get_config().hybrid_ground_enabled:
		_current_vision_mul = maxf(vision_mul, 0.05)
		_sync_hybrid_view_multiplier(0.0)
		force_zoom_now(_base_zoom)
		return
	var zoom_factor := 1.0 / (maxf(vision_mul, 0.05) * maxf(_get_config().battle_camera_view_mul, 0.05))
	force_zoom_now(_base_zoom * zoom_factor)

func _get_phase_camera_zoom_factor() -> float:
	if PhaseManager != null and PhaseManager.has_method("current_state"):
		if str(PhaseManager.current_state()) == str(PhaseManager.PREPARE):
			# This setting is a view multiplier: values above one must reveal more
			# of the rest area, which means a smaller Camera2D zoom value.
			return 1.0 / clampf(_get_config().rest_phase_camera_zoom_factor, 0.2, 2.0)
	return 1.0

func _get_effective_vision_mul(vision_mul: float) -> float:
	var effective_mul := maxf(vision_mul, 0.05)
	if _is_prepare_phase():
		return effective_mul
	effective_mul *= maxf(_get_config().battle_camera_view_mul, 0.05)
	return effective_mul

func _update_zoom(delta: float) -> void:
	if _is_zoom_transition_enabled():
		if _zoom_tween == null and _camera.zoom.distance_to(_zoom_target) > 0.001:
			var duration := _get_zoom_transition_duration(_is_prepare_phase())
			_rebuild_zoom_transition(_zoom_target, duration)
		return
	var t := clampf(_get_config().camera_zoom_lerp_speed * delta, 0.0, 1.0)
	_camera.zoom = _camera.zoom.lerp(_zoom_target, t)

func _sync_zoom_transition_phase_edge() -> void:
	if not _is_zoom_transition_enabled():
		_last_phase_is_prepare = _is_prepare_phase()
		return
	var is_prepare := _is_prepare_phase()
	if is_prepare == _last_phase_is_prepare:
		return
	_last_phase_is_prepare = is_prepare
	var duration := _get_zoom_transition_duration(is_prepare)
	_sync_hybrid_view_multiplier(duration)
	if _get_config().hybrid_ground_enabled:
		return
	_rebuild_zoom_transition(_zoom_target, duration)

func on_phase_changed() -> void:
	if not _is_prepare_phase() and _restarea_control_enabled:
		set_restarea_control_enabled(false)
	_refresh_zoom_target_from_context()
	if _camera == null:
		return
	if not _is_zoom_transition_enabled():
		_last_phase_is_prepare = _is_prepare_phase()
		return
	var is_prepare := _is_prepare_phase()
	_last_phase_is_prepare = is_prepare
	_sync_hybrid_view_multiplier(_get_zoom_transition_duration(is_prepare))
	if _get_config().hybrid_ground_enabled:
		_camera.zoom = _base_zoom
		return
	if _camera.zoom.distance_to(_zoom_target) <= 0.001:
		return
	var duration := _get_zoom_transition_duration(is_prepare)
	_rebuild_zoom_transition(_zoom_target, duration)

func _refresh_zoom_target_from_context() -> void:
	if _camera == null:
		return
	if _get_config().hybrid_ground_enabled:
		_zoom_target = _base_zoom
		_sync_hybrid_view_multiplier(0.0)
		return
	var zoom_factor := 1.0 / _get_effective_vision_mul(_current_vision_mul)
	_zoom_target = _base_zoom * zoom_factor * _get_phase_camera_zoom_factor()

func _is_zoom_transition_enabled() -> bool:
	return _get_config().rest_camera_zoom_transition_enabled

func _is_prepare_phase() -> bool:
	if PhaseManager == null or not PhaseManager.has_method("current_state"):
		return false
	return str(PhaseManager.current_state()) == str(PhaseManager.PREPARE)

func _get_zoom_transition_duration(is_prepare: bool) -> float:
	var value: float = 0.0
	if is_prepare:
		value = _get_config().rest_camera_zoom_enter_duration
	else:
		value = _get_config().rest_camera_zoom_exit_duration
	return maxf(value, 0.01)

func _rebuild_zoom_transition(to_zoom: Vector2, duration: float) -> void:
	if _camera == null:
		return
	if _zoom_tween != null:
		_zoom_tween.kill()
		_zoom_tween = null
	_zoom_tween = _camera.create_tween()
	_zoom_tween.set_trans(Tween.TRANS_SINE)
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_camera, "zoom", to_zoom, maxf(duration, 0.01))
	_zoom_tween.finished.connect(_on_zoom_tween_finished, CONNECT_ONE_SHOT)

func _on_zoom_tween_finished() -> void:
	_zoom_tween = null

func _update_lookahead(delta: float) -> void:
	# Camera no longer uses movement-based lookahead/inertia offset.
	_offset_target = Vector2.ZERO
	_update_shake(delta)
	_camera.offset = _offset_target + _shake_offset

func _reset_offset_for_restarea(delta: float) -> void:
	var reset_t := clampf(maxf(_get_config().camera_lookahead_lerp_speed, 0.0) * maxf(delta, 0.0), 0.0, 1.0)
	_offset_target = Vector2.ZERO
	_shake_trauma = 0.0
	_shake_offset = Vector2.ZERO
	_sync_hybrid_shake()
	_camera.offset = _camera.offset.lerp(Vector2.ZERO, reset_t)

func _get_config():
	if _config == null:
		_config = PlayerCameraConfigType.new()
	return _config

func _update_shake(delta: float) -> void:
	if _shake_trauma <= 0.001:
		_shake_trauma = 0.0
		_shake_offset = Vector2.ZERO
		_sync_hybrid_shake()
		return
	_shake_time += maxf(delta, 0.0) * 48.0
	var strength := _shake_trauma * _shake_trauma
	_shake_offset = Vector2(
		sin(_shake_time + _shake_seed) * _shake_max_offset.x * strength,
		cos(_shake_time * 1.37 + _shake_seed) * _shake_max_offset.y * strength
	)
	_shake_trauma = maxf(0.0, _shake_trauma - _shake_decay_per_sec * maxf(delta, 0.0))
	_sync_hybrid_shake()

func _resolve_hybrid_view() -> void:
	if not _get_config().hybrid_ground_enabled or _camera == null or not _camera.is_inside_tree():
		_hybrid_view = null
		return
	if _hybrid_view != null and is_instance_valid(_hybrid_view) and _hybrid_view.is_inside_tree():
		return
	_hybrid_view = null
	var views := _camera.get_tree().get_nodes_in_group(&"hybrid_ground_view_3d")
	if not views.is_empty():
		_hybrid_view = views[0] as Node
		_sync_hybrid_view_multiplier(0.0)

func _sync_hybrid_view_multiplier(duration: float) -> void:
	_resolve_hybrid_view()
	if _hybrid_view == null or not _hybrid_view.has_method("set_view_multiplier"):
		return
	var view_multiplier := _get_effective_vision_mul(_current_vision_mul)
	if _is_prepare_phase():
		view_multiplier *= clampf(_get_config().rest_phase_camera_zoom_factor, 0.2, 2.0)
	_hybrid_view.call("set_view_multiplier", view_multiplier, duration)

func _sync_hybrid_shake() -> void:
	if _hybrid_view != null and is_instance_valid(_hybrid_view) and _hybrid_view.has_method("set_screen_shake_offset"):
		_hybrid_view.call("set_screen_shake_offset", _shake_offset)

func _update_restarea_camera_move(delta: float) -> void:
	if not _restarea_camera_moving or _camera == null:
		return
	var to_target := _restarea_camera_target - _camera.global_position
	var distance := to_target.length()
	var speed: float = clampf(
		distance * _restarea_camera_speed_curve,
		_restarea_camera_min_speed,
		_restarea_camera_max_speed
	) * _restarea_camera_speed_mul
	var reach := maxf(8.0, speed * 0.03)
	if distance <= reach:
		_camera.global_position = _restarea_camera_target
		_restarea_camera_moving = false
		_restarea_camera_speed_mul = 1.0
		return
	_camera.global_position = _camera.global_position.move_toward(_restarea_camera_target, speed * maxf(delta, 0.0))
