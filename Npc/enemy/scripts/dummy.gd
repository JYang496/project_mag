extends BaseEnemy

func _physics_process(_delta: float) -> void:
	if is_stunned():
		decay_knockback()
		move_with_body_push(Vector2.ZERO, _delta)
		return
	decay_knockback()
	move_with_body_push(Vector2.ZERO, _delta)
