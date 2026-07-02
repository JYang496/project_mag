extends RefCounted
class_name MovementFrameResult

var next_velocity: Vector2 = Vector2.ZERO
var reached_target: bool = false
var should_snap_position: bool = false
var snap_position: Vector2 = Vector2.ZERO
var auto_navigation_completed: bool = false

func reset(current_velocity: Vector2) -> void:
	next_velocity = current_velocity
	reached_target = false
	should_snap_position = false
	snap_position = Vector2.ZERO
	auto_navigation_completed = false
