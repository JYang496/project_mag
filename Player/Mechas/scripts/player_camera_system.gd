extends RefCounted
class_name PlayerCameraSystem

var _player
var _camera: Camera2D
var _base_zoom := Vector2.ONE
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

func has_camera_binding() -> bool:
	return _camera != null

func setup(player, camera: Camera2D) -> void:
	_player = player
	if _zoom_tween != null:
		_zoom_tween.kill()
		_zoom_tween = null
	_camera = camera
	if _camera != null:
		_base_zoom = _camera.zoom
		_zoom_target = _base_zoom
		if _restarea_control_enabled:
			_apply_restarea_control_enabled(_restarea_pending_snap_target, _restarea_pending_snap_now)
		else:
			_apply_restarea_control_disabled()
	_last_phase_is_prepare = _is_prepare_phase()
	_refresh_zoom_target_from_context()

func tick(delta: float) -> void:
	if _camera == null:
		return
	_sync_zoom_transition_phase_edge()
	if _restarea_control_enabled:
		_update_zoom(delta)
		_reset_offset_for_restarea(delta)
		_update_restarea_camera_move(delta)
		return
	_update_zoom(delta)
	_update_lookahead(delta)

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
	if _base_zoom == Vector2.ZERO:
		_base_zoom = Vector2.ONE
	var zoom_factor := 1.0 / maxf(vision_mul, 0.05)
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

func _get_phase_camera_zoom_factor() -> float:
	if PhaseManager != null and PhaseManager.has_method("current_state"):
		if str(PhaseManager.current_state()) == str(PhaseManager.PREPARE):
			return clampf(_player.rest_phase_camera_zoom_factor, 0.2, 2.0)
	return 1.0

func _update_zoom(delta: float) -> void:
	if _is_zoom_transition_enabled():
		if _zoom_tween == null and _camera.zoom.distance_to(_zoom_target) > 0.001:
			var duration := _get_zoom_transition_duration(_is_prepare_phase())
			_rebuild_zoom_transition(_zoom_target, duration)
		return
	var t := clampf(_player.camera_zoom_lerp_speed * delta, 0.0, 1.0)
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
	if _camera.zoom.distance_to(_zoom_target) <= 0.001:
		return
	var duration := _get_zoom_transition_duration(is_prepare)
	_rebuild_zoom_transition(_zoom_target, duration)

func _refresh_zoom_target_from_context() -> void:
	if _camera == null or _player == null:
		return
	var vision_mul := 1.0
	if _player.has_method("get_total_vision_mul"):
		vision_mul = maxf(float(_player.call("get_total_vision_mul")), 0.05)
	var zoom_factor := 1.0 / vision_mul
	_zoom_target = _base_zoom * zoom_factor * _get_phase_camera_zoom_factor()

func _is_zoom_transition_enabled() -> bool:
	if _player == null:
		return false
	return bool(_player.get("rest_camera_zoom_transition_enabled"))

func _is_prepare_phase() -> bool:
	if PhaseManager == null or not PhaseManager.has_method("current_state"):
		return false
	return str(PhaseManager.current_state()) == str(PhaseManager.PREPARE)

func _get_zoom_transition_duration(is_prepare: bool) -> float:
	if _player == null:
		return 0.01
	var value: float = 0.0
	if is_prepare:
		value = float(_player.get("rest_camera_zoom_enter_duration"))
	else:
		value = float(_player.get("rest_camera_zoom_exit_duration"))
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
	var t := clampf(maxf(_player.camera_lookahead_lerp_speed, 0.0) * maxf(delta, 0.0), 0.0, 1.0)
	_camera.offset = _camera.offset.lerp(_offset_target, t)

func _reset_offset_for_restarea(delta: float) -> void:
	var reset_t := clampf(maxf(_player.camera_lookahead_lerp_speed, 0.0) * maxf(delta, 0.0), 0.0, 1.0)
	_offset_target = Vector2.ZERO
	_camera.offset = _camera.offset.lerp(Vector2.ZERO, reset_t)

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
