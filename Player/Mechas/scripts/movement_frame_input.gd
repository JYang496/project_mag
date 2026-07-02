extends RefCounted
class_name MovementFrameInput

var delta: float = 0.0
var current_velocity: Vector2 = Vector2.ZERO
var current_position: Vector2 = Vector2.ZERO
var movement_enabled: bool = true
var auto_navigation_enabled: bool = false
var auto_navigation_destination: Vector2 = Vector2.ZERO
var manual_input_allowed: bool = true
var manual_direction: Vector2 = Vector2.ZERO
var move_speed: float = 0.0
var move_accel: float = 0.0
var move_decel: float = 0.0
var move_turn_penalty: float = 0.0
