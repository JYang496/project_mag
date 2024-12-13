extends BaseEnemy

func _physics_process(_delta):
	## direction to applied normalized
	var direction = global_position.direction_to(player.global_position)
	velocity = direction * movement_speed
	move_and_slide()
