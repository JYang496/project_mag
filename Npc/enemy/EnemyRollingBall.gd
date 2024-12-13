extends BaseEnemy

func _physics_process(_delta):
	## direction to applied normalized
	var direction = global_position.direction_to(player.global_position)
	velocity = direction * movement_speed
	velocity += knockback.amount * knockback.angle
	knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
	move_and_slide()
