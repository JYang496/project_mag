extends BaseEnemy

@onready var final_speed = movement_speed

func _physics_process(_delta):
	## direction to applied normalized
	var direction = global_position.direction_to(player.global_position)
	velocity = direction * final_speed
	velocity += knockback
	move_and_slide()


# The last mile of diliverly is pain
func _on_slow_down_area_body_entered(body):
	if body is Player:
		final_speed = movement_speed * 0.2
