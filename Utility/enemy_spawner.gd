extends Node2D
class_name EnemySpawner

@onready var timer = $Timer
@onready var x_min = $TopLeft.global_position.x
@onready var y_min = $TopLeft.global_position.y
@onready var x_max = $BottomRight.global_position.x
@onready var y_max = $BottomRight.global_position.y

var instance_list : Array
var time_out_list : Array

func _ready():
	GlobalVariables.enemy_spawner = self
	for i in SpawnData.level_list:
		var ins : LevelSpawnConfig = i.instantiate()
		instance_list.append(ins.spawns)
		time_out_list.append(ins.time_out)

func start_timer() -> void:
	PhaseManager.battle_time = 0
	timer.start()

func _on_timer_timeout():
	PhaseManager.battle_time += 1
	var enemy_spawns = instance_list[PhaseManager.current_level]
	var wave_clear = true
	for e : SpawnInfo in enemy_spawns:
		if e.wave < e.max_wave or e.alive_enemy_number > 0:
			wave_clear = false
	if PhaseManager.battle_time >= time_out_list[PhaseManager.current_level] or wave_clear or PhaseManager.phase == PhaseManager.REWARD:
		timer.stop()
		erase_all_enemies()
		PhaseManager.enter_reward()
		return
	for i : SpawnInfo in enemy_spawns:
		if PhaseManager.battle_time >= i.time_start and i.wave < i.max_wave:
			if i.interval_counter > 1:
				i.interval_counter -= 1
			else:
				if i.alive_enemy_number >= i.max_enemy_number:
					continue
				i.wave += 1
				i.interval_counter = i.interval
				var new_enemy = i.enemy
				var counter = 0
				var random_position_center = get_random_position()
				while counter < i.number:
					var enemy_spawn = new_enemy.instantiate()
					enemy_spawn.hp = i.hp
					enemy_spawn.damage = i.damage
					enemy_spawn.global_position = get_nearby_position(random_position_center)
					self.call_deferred("add_child",enemy_spawn)
					i.add_enemy_with_signal(enemy_spawn)
					counter += 1

func get_random_position() -> Vector2:
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

func get_nearby_position(A: Vector2, min_distance: float = 0.0, max_distance: float = 100.0) -> Vector2:
	var angle = randf() * 2 * PI
	var distance = randf_range(min_distance, max_distance)
	var nearby_pos = A + Vector2(cos(angle), sin(angle)) * distance
	return clamp_position(nearby_pos.x, nearby_pos.y)

func clamp_position(x_value :float, y_value :float) -> Vector2:
	return Vector2(clampf(x_value,x_min,x_max),clampf(y_value,y_min,y_max))

func erase_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e : BaseEnemy in enemies:
		e.erase()
