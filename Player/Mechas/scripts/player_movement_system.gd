extends RefCounted
class_name PlayerMovementSystem

const MovementFrameInputType := preload("res://Player/Mechas/scripts/movement_frame_input.gd")
const MovementFrameResultType := preload("res://Player/Mechas/scripts/movement_frame_result.gd")

const MODE_IDLE: StringName = &"idle"
const MODE_MANUAL_MOVE: StringName = &"manual_move"
const MODE_BRAKE: StringName = &"brake"
const MODE_TURN: StringName = &"turn"
const MODE_AUTO_NAV: StringName = &"auto_nav"
const MODE_DASH: StringName = &"dash"
const MODE_IMMOBILIZED: StringName = &"immobilized"

var _auto_nav_speed_mul: float = 1.0
var _dash_active: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_target_position: Vector2 = Vector2.ZERO
var _dash_duration_sec: float = 0.0
var _dash_remaining_sec: float = 0.0
var _dash_speed: float = 0.0
var _dash_source_id: StringName = StringName()
var _status := {
	"mode": MODE_IDLE,
	"velocity": Vector2.ZERO,
	"input_direction": Vector2.ZERO,
	"speed_ratio": 0.0,
	"is_turning": false,
	"action_source_id": StringName(),
	"dash_remaining_sec": 0.0,
}

func tick(frame_input: MovementFrameInputType, frame_result: MovementFrameResultType) -> void:
	frame_result.reset(frame_input.current_velocity)
	if _dash_active:
		_update_dash(frame_input, frame_result)
	elif frame_input.auto_navigation_enabled:
		_update_auto_navigation(frame_input, frame_result)
	elif frame_input.movement_enabled:
		_update_manual_movement(frame_input, frame_result)
	else:
		frame_result.next_velocity = _decelerate(frame_input)
		_set_status(MODE_IMMOBILIZED, frame_result.next_velocity, frame_input, false, StringName())

func reset_auto_nav_speed_mul() -> void:
	_auto_nav_speed_mul = 1.0

func configure_auto_nav_speed_mul(speed_mul: float) -> void:
	_auto_nav_speed_mul = maxf(speed_mul, 0.05)

func request_dash(start_position: Vector2, target_position: Vector2, duration_sec: float, source_id: StringName = StringName()) -> bool:
	if _dash_active:
		return false
	var delta := target_position - start_position
	var distance := delta.length()
	if distance <= 0.5:
		return false
	_dash_active = true
	_dash_direction = delta / distance
	_dash_target_position = target_position
	_dash_duration_sec = maxf(duration_sec, 0.01)
	_dash_remaining_sec = _dash_duration_sec
	_dash_speed = distance / _dash_duration_sec
	_dash_source_id = source_id
	_status["mode"] = MODE_DASH
	_status["action_source_id"] = source_id
	_status["dash_remaining_sec"] = _dash_remaining_sec
	return true

func cancel_dash() -> void:
	_dash_active = false
	_dash_direction = Vector2.ZERO
	_dash_target_position = Vector2.ZERO
	_dash_duration_sec = 0.0
	_dash_remaining_sec = 0.0
	_dash_speed = 0.0
	_dash_source_id = StringName()
	_status["mode"] = MODE_IDLE
	_status["action_source_id"] = StringName()
	_status["dash_remaining_sec"] = 0.0

func get_status() -> Dictionary:
	return _status.duplicate()

func _update_manual_movement(frame_input: MovementFrameInputType, frame_result: MovementFrameResultType) -> void:
	if frame_input.manual_input_allowed:
		var target_velocity := Vector2.ZERO
		if frame_input.manual_direction.length_squared() > 0.0001:
			target_velocity = frame_input.manual_direction.normalized() * frame_input.move_speed
		var is_turning := (
			frame_input.current_velocity.length_squared() > 1.0
			and target_velocity.length_squared() > 1.0
			and frame_input.current_velocity.dot(target_velocity) < 0.0
		)
		var accel := frame_input.move_accel if target_velocity.length_squared() > 0.0 else frame_input.move_decel
		if is_turning:
			accel *= 1.0 - clampf(frame_input.move_turn_penalty, 0.0, 0.9)
		frame_result.next_velocity = frame_input.current_velocity.move_toward(
			target_velocity,
			maxf(accel, 0.0) * maxf(frame_input.delta, 0.0)
		)
		var mode := MODE_IDLE
		if is_turning:
			mode = MODE_TURN
		elif target_velocity.length_squared() > 0.0:
			mode = MODE_MANUAL_MOVE
		elif frame_result.next_velocity.length_squared() > 1.0:
			mode = MODE_BRAKE
		_set_status(mode, frame_result.next_velocity, frame_input, is_turning, StringName())
	else:
		frame_result.next_velocity = _decelerate(frame_input)
		var mode := MODE_BRAKE if frame_result.next_velocity.length_squared() > 1.0 else MODE_IDLE
		_set_status(mode, frame_result.next_velocity, frame_input, false, StringName())

func _update_auto_navigation(frame_input: MovementFrameInputType, frame_result: MovementFrameResultType) -> void:
	var to_dest := frame_input.auto_navigation_destination - frame_input.current_position
	var distance_to_dest := to_dest.length()
	var reach_distance := maxf(3.0, frame_input.current_velocity.length() * 0.03)
	if distance_to_dest <= reach_distance:
		frame_result.next_velocity = Vector2.ZERO
		frame_result.reached_target = true
		frame_result.should_snap_position = true
		frame_result.snap_position = frame_input.auto_navigation_destination
		frame_result.auto_navigation_completed = true
		_set_status(MODE_IDLE, frame_result.next_velocity, frame_input, false, StringName())
		return
	var target_velocity := to_dest.normalized() * frame_input.move_speed * _auto_nav_speed_mul
	frame_result.next_velocity = frame_input.current_velocity.move_toward(
		target_velocity,
		maxf(frame_input.move_accel, 0.0) * maxf(frame_input.delta, 0.0)
	)
	_set_status(MODE_AUTO_NAV, frame_result.next_velocity, frame_input, false, StringName())

func _decelerate(frame_input: MovementFrameInputType) -> Vector2:
	return frame_input.current_velocity.move_toward(
		Vector2.ZERO,
		maxf(frame_input.move_decel, 0.0) * maxf(frame_input.delta, 0.0)
	)

func _update_dash(frame_input: MovementFrameInputType, frame_result: MovementFrameResultType) -> void:
	_dash_remaining_sec -= maxf(frame_input.delta, 0.0)
	if _dash_remaining_sec <= 0.0:
		frame_result.next_velocity = Vector2.ZERO
		frame_result.should_snap_position = true
		frame_result.snap_position = _dash_target_position
		cancel_dash()
		_set_status(MODE_IDLE, frame_result.next_velocity, frame_input, false, StringName())
		return
	frame_result.next_velocity = _dash_direction * _dash_speed
	_set_status(MODE_DASH, frame_result.next_velocity, frame_input, false, _dash_source_id)

func _set_status(mode: StringName, next_velocity: Vector2, frame_input: MovementFrameInputType, is_turning: bool, action_source_id: StringName) -> void:
	var move_speed := maxf(frame_input.move_speed, 1.0)
	_status["mode"] = mode
	_status["velocity"] = next_velocity
	_status["input_direction"] = frame_input.manual_direction.normalized() if frame_input.manual_direction.length_squared() > 0.0001 else Vector2.ZERO
	_status["speed_ratio"] = clampf(next_velocity.length() / move_speed, 0.0, 8.0)
	_status["is_turning"] = is_turning
	_status["action_source_id"] = action_source_id
	_status["dash_remaining_sec"] = maxf(_dash_remaining_sec, 0.0) if _dash_active else 0.0
