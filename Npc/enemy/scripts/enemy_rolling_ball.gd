extends BaseEnemy
class_name EnemyRollingBall

func _physics_process(_delta):
	## direction to applied normalized
	if is_stunned():
		knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		return
	var direction = global_position.direction_to(PlayerData.player.global_position)
	knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
	velocity = direction * get_current_movement_speed()
	velocity += knockback.amount * knockback.angle
	move_and_slide()
