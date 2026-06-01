extends BaseEnemy
class_name EnemyRollingBall

func _physics_process(delta):
	## direction to applied normalized
	if is_stunned():
		knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
		move_with_body_push(Vector2.ZERO, delta)
		return
	var direction = global_position.direction_to(PlayerData.player.global_position)
	knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
	move_with_body_push(direction * get_current_movement_speed(), delta)
