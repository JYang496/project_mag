extends BaseEnemy

@export var chase_acceleration: float = 25.0
@export var slowdown_deceleration: float = 180.0
@export var max_speed_multiplier: float = 3.0

@onready var final_speed: float = movement_speed
var slowdown_triggered: bool = false
var slowdown_speed: float = 0.0

func _physics_process(delta: float) -> void:
	if is_stunned():
		knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		return
	var current_base_speed: float = get_current_movement_speed()
	if slowdown_triggered:
		var target_slow_speed: float = min(slowdown_speed, current_base_speed * 0.5)
		final_speed = move_toward(final_speed, target_slow_speed, slowdown_deceleration * delta)
	else:
		var max_speed : float = current_base_speed * max_speed_multiplier
		final_speed = min(final_speed + chase_acceleration * delta, max_speed)

	## direction to applied normalized
	var direction = global_position.direction_to(PlayerData.player.global_position)
	velocity = direction * final_speed
	velocity += knockback.amount * knockback.angle
	move_and_slide()


# The last mile of diliverly is pain
func _on_slow_down_area_body_entered(body):
	if body is Player and not slowdown_triggered:
		slowdown_triggered = true
		slowdown_speed = get_current_movement_speed() * 0.5
