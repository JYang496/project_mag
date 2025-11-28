extends Node2D

@onready var timer = $Timer
@onready var x_min = $TopLeft.global_position.x
@onready var y_min = $TopLeft.global_position.y
@onready var x_max = $BottomRight.global_position.x
@onready var y_max = $BottomRight.global_position.y

var instance_list : Array
var time_out_list : Array

func _ready():
	#GlobalVariables.enemy_spawner = self
	for level_config in SpawnData.level_list:
		if level_config == null:
			continue
		var ins : LevelSpawnConfig = level_config.duplicate(true)
		instance_list.append(ins.spawns)
		time_out_list.append(ins.time_out)

func start_timer() -> void:
	PhaseManager.battle_time = 0
	timer.start()

func _on_timer_timeout():
	PhaseManager.battle_time += 1
	# When time up, battle ends and bonus phase starts
	if PhaseManager.battle_time >= time_out_list[PhaseManager.current_level] or PhaseManager.phase == PhaseManager.REWARD:
		timer.stop()
		clear_all_enemies()
		PhaseManager.enter_reward()
		return
	var enemy_spawns = instance_list[PhaseManager.current_level]
	for i : SpawnInfo in enemy_spawns:
		if PhaseManager.battle_time >= i.time_start and PhaseManager.battle_time <= i.time_end:
			if i.spawn_delay_counter < i.delay - 1:
				i.spawn_delay_counter += 1
			else:
				i.spawn_delay_counter = 0
				var new_enemy = i.enemy
				var counter = 0
				while counter < i.number:
					var enemy_spawn = new_enemy.instantiate()
					_apply_level_scaling(i, enemy_spawn)
					enemy_spawn.global_position = get_random_position()
					self.call_deferred("add_child",enemy_spawn)
					counter += 1

func get_random_position():
	var player = PlayerData.player
	var vpr = get_viewport_rect().size * randf_range(0.5,1.1)
	
	var top_left = clamp_position(player.global_position.x - vpr.x/2, player.global_position.y - vpr.y/2)
	var top_right = clamp_position(player.global_position.x + vpr.x/2, player.global_position.y - vpr.y/2)
	var bottom_left = clamp_position(player.global_position.x - vpr.x/2, player.global_position.y + vpr.y/2)
	var bottom_right = clamp_position(player.global_position.x + vpr.x/2, player.global_position.y + vpr.y/2)
	var pos_side = ["up","down","right","left"].pick_random()
	var spawn_pos1 = Vector2.ZERO
	var spawn_pos2 = Vector2.ZERO
	
	match pos_side:
		"up":
			spawn_pos1 = top_left
			spawn_pos2 = top_right
		"down":
			spawn_pos1 = bottom_left
			spawn_pos2 = bottom_right
		"right":
			spawn_pos1 = top_right
			spawn_pos2 = bottom_right
		"left":
			spawn_pos1 = top_left
			spawn_pos2 = bottom_left
	var x_spawn = randf_range(spawn_pos1.x, spawn_pos2.x)
	var y_spawn = randf_range(spawn_pos1.y, spawn_pos2.y)
	return Vector2(x_spawn,y_spawn)

func clamp_position(x_value :float, y_value :float) -> Vector2:
	return Vector2(clampf(x_value,x_min,x_max),clampf(y_value,y_min,y_max))

func clear_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e : BaseEnemy in enemies:
		e.death()

func _apply_level_scaling(spawn_info: SpawnInfo, enemy_instance) -> void:
	if enemy_instance is BaseEnemy:
		var base_enemy : BaseEnemy = enemy_instance
		var level_index = max(PhaseManager.current_level, 0)
		base_enemy.hp = spawn_info.get_scaled_hp(level_index, base_enemy.hp)
		base_enemy.damage = spawn_info.get_scaled_damage(level_index, base_enemy.damage)
