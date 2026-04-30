extends RefCounted
class_name PlayerCameraSystem

var _player
var _camera: Camera2D
var _base_zoom := Vector2.ONE
var _zoom_target := Vector2.ONE
var _offset_target := Vector2.ZERO
var _restarea_control_enabled := false
var _restarea_camera_target := Vector2.ZERO
var _restarea_camera_moving := false
var _restarea_camera_speed_mul: float = 1.0
var _restarea_camera_min_speed: float = 900.0
var _restarea_camera_max_speed: float = 3200.0
var _restarea_camera_speed_curve: float = 4.2

func setup(player, camera: Camera2D) -> void:
	_player = player
	_camera = camera
	if _camera != null:
		_base_zoom = _camera.zoom
		_zoom_target = _base_zoom

func tick(delta: float) -> void:
	if _camera == null:
		return
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
	if _camera == null:
		return
	_restarea_control_enabled = enabled
	if enabled:
		_camera.top_level = true
		if snap_now:
			_camera.global_position = snap_target
		_restarea_camera_target = _camera.global_position
		_restarea_camera_moving = false
		_restarea_camera_speed_mul = 1.0
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

func _get_phase_camera_zoom_factor() -> float:
	if PhaseManager != null and PhaseManager.has_method("current_state"):
		if str(PhaseManager.current_state()) == str(PhaseManager.PREPARE):
			return clampf(_player.rest_phase_camera_zoom_factor, 0.2, 2.0)
	return 1.0

func _update_zoom(delta: float) -> void:
	var t := clampf(_player.camera_zoom_lerp_speed * delta, 0.0, 1.0)
	_camera.zoom = _camera.zoom.lerp(_zoom_target, t)

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
