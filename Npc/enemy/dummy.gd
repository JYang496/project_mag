extends BaseEnemy

func _physics_process(delta: float) -> void:
	knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
	velocity = knockback.amount * knockback.angle
	move_and_slide()
