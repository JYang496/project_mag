extends BaseEnemy

func _physics_process(_delta: float) -> void:
	if is_stunned():
		knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
		move_with_body_push(Vector2.ZERO, _delta)
		return
	knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
	move_with_body_push(Vector2.ZERO, _delta)
