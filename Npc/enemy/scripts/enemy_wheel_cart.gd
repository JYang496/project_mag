extends BaseEnemy

@export var chase_acceleration: float = 25.0
@export var slowdown_deceleration: float = 96.0
@export var max_speed_multiplier: float = 3.0

@onready var final_speed: float = movement_speed
var slowdown_triggered: bool = false

func _physics_process(delta: float) -> void:
	if is_stunned():
		set_crowd_breakthrough_active(false)
		knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
		move_with_body_push(Vector2.ZERO, delta)
		return
	var current_base_speed: float = get_current_movement_speed()
	if slowdown_triggered:
		set_crowd_breakthrough_active(false)
		final_speed = move_toward(final_speed, current_base_speed, slowdown_deceleration * delta)
	else:
		set_crowd_breakthrough_active(true)
		var max_speed : float = current_base_speed * max_speed_multiplier
		final_speed = min(final_speed + chase_acceleration * delta, max_speed)

	## direction to applied normalized
	var direction = global_position.direction_to(PlayerData.player.global_position)
	move_with_body_push(direction * final_speed, delta)


# The last mile of diliverly is pain
func _on_slow_down_area_body_entered(body):
	if body is Player and not slowdown_triggered:
		set_crowd_breakthrough_active(false)
		slowdown_triggered = true
