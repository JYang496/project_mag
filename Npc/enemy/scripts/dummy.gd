extends BaseEnemy

func _physics_process(_delta: float) -> void:
	var ai_delta := consume_ai_update_delta(_delta)
	if ai_delta <= 0.0:
		continue_lod_movement(_delta)
		return
	_delta = ai_delta
	if is_stunned():
		decay_knockback()
		move_enemy(Vector2.ZERO, _delta)
		return
	decay_knockback()
	move_enemy(Vector2.ZERO, _delta)
