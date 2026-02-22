extends BaseEnemy

func _physics_process(_delta: float) -> void:
	if is_stunned():
		knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		return
	knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
	velocity = knockback.amount * knockback.angle
	move_and_slide()
