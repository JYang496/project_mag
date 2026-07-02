extends RefCounted
class_name PlayerMovementSystem

const MovementFrameInputType := preload("res://Player/Mechas/scripts/movement_frame_input.gd")
const MovementFrameResultType := preload("res://Player/Mechas/scripts/movement_frame_result.gd")

var _auto_nav_speed_mul: float = 1.0

func tick(frame_input: MovementFrameInputType, frame_result: MovementFrameResultType) -> void:
	frame_result.reset(frame_input.current_velocity)
	if frame_input.auto_navigation_enabled:
		_update_auto_navigation(frame_input, frame_result)
	elif frame_input.movement_enabled:
		_update_manual_movement(frame_input, frame_result)
	else:
		frame_result.next_velocity = _decelerate(frame_input)

func reset_auto_nav_speed_mul() -> void:
	_auto_nav_speed_mul = 1.0

func configure_auto_nav_speed_mul(speed_mul: float) -> void:
	_auto_nav_speed_mul = maxf(speed_mul, 0.05)

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
	else:
		frame_result.next_velocity = _decelerate(frame_input)

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
		return
	var target_velocity := to_dest.normalized() * frame_input.move_speed * _auto_nav_speed_mul
	frame_result.next_velocity = frame_input.current_velocity.move_toward(
		target_velocity,
		maxf(frame_input.move_accel, 0.0) * maxf(frame_input.delta, 0.0)
	)

func _decelerate(frame_input: MovementFrameInputType) -> Vector2:
	return frame_input.current_velocity.move_toward(
		Vector2.ZERO,
		maxf(frame_input.move_decel, 0.0) * maxf(frame_input.delta, 0.0)
	)
