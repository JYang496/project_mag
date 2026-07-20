extends BaseEnemy
class_name EnemyRollingBall

func _physics_process(delta):
	var ai_delta := consume_ai_update_delta(float(delta))
	if ai_delta <= 0.0:
		continue_lod_movement(float(delta))
		return
	delta = ai_delta
	## direction to applied normalized
	if is_stunned():
		decay_knockback()
		move_enemy(Vector2.ZERO, delta)
		return
	var direction = global_position.direction_to(PlayerData.player.global_position)
	decay_knockback()
	move_enemy(direction * get_current_movement_speed(), delta)
