extends Node


#func _on_over_charge():
	#print(self,"OVER CHARGE")
	#Engine.time_scale = 0.333
	#PlayerData.player_bonus_speed += PlayerData.player_speed * 2
	#justAttacked = true
	#speed = 800
	#var wait_time = (get_random_target() - self.global_position).length() / speed
	#var wait_unit_list = [3, 2, 1, 2, 3, 0]
	#for i in range(6):
		#var spawn_bullet = bullet.instantiate()
		#var bullet_direction = global_position.direction_to(get_random_target()).normalized()
		#spawn_bullet.damage = damage
		#spawn_bullet.expire_time = 6.6
		#spawn_bullet.hp = 66
		#spawn_bullet.global_position = global_position
		#spawn_bullet.blt_texture = bul_texture
		#apply_linear(spawn_bullet, bullet_direction, speed)
		#apply_hexagon_attack(spawn_bullet, i, wait_time)
		#get_tree().root.call_deferred("add_child",spawn_bullet)
		#await get_tree().create_timer(wait_time *  wait_unit_list[i]).timeout
	#PlayerData.player_bonus_speed -= PlayerData.player_speed * 2
	#Engine.time_scale = 1
