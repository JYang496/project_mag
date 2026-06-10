extends BaseEnemy
class_name EnemyRollingBall

func _physics_process(delta):
	## direction to applied normalized
	if is_stunned():
		decay_knockback()
		move_with_body_push(Vector2.ZERO, delta)
		return
	var direction = global_position.direction_to(PlayerData.player.global_position)
	decay_knockback()
	move_with_body_push(direction * get_current_movement_speed(), delta)
