extends Node2D

@export var spawns: Array[Spawn_info] = []

@onready var player = get_tree().get_first_node_in_group("player")
@onready var timer = $Timer
@onready var x_min = $TopLeft.global_position.x
@onready var y_min = $TopLeft.global_position.y
@onready var x_max = $BottomRight.global_position.x
@onready var y_max = $BottomRight.global_position.y

var current_level := 0 :
	set(value):
		current_level = clampi(value,0,len(SpawnData.spawn_list) - 1)
var instant_list : Array

func _ready():
	for i in SpawnData.spawn_list:
		var ins = i.instantiate()
		instant_list.append(ins)


func start_timer() -> void:
	PhaseManager.battle_time = 0
	timer.start()

func _on_timer_timeout():
	PhaseManager.battle_time += 1
	# When time hit 20, battle ends and bonus phase starts
	if PhaseManager.battle_time >= 20 or PhaseManager.phase == PhaseManager.BONUS:
		current_level += 1
		timer.stop()
		PhaseManager.enter_bonus()
		return
	var enemy_spawns = instant_list[current_level].spawns
	for i in enemy_spawns:
		if PhaseManager.battle_time >= i.time_start and PhaseManager.battle_time <= i.time_end:
			if i.spawn_delay_counter < i.enemy_spawn_delay:
				i.spawn_delay_counter += 1
			else:
				i.spawn_delay_counter = 0
				var new_enemy = i.enemy
				var counter = 0
				while counter < i.enemy_num:
					var enemy_spawn = new_enemy.instantiate()
					enemy_spawn.global_position = get_random_position()
					add_child(enemy_spawn)
					counter += 1

func get_random_position():
	var vpr = get_viewport_rect().size * randf_range(0.5,1.1)
	var top_left = Vector2(player.global_position.x - vpr.x/2, player.global_position.y - vpr.y/2)
	var top_right = Vector2(player.global_position.x + vpr.x/2, player.global_position.y - vpr.y/2)
	var bottom_left = Vector2(player.global_position.x - vpr.x/2, player.global_position.y + vpr.y/2)
	var bottom_right = Vector2(player.global_position.x + vpr.x/2, player.global_position.y + vpr.y/2)
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
	var x_spawn = clampf(randf_range(spawn_pos1.x, spawn_pos2.x),x_min,x_max)
	var y_spawn = clampf(randf_range(spawn_pos1.y, spawn_pos2.y),y_min,y_max)
	return Vector2(x_spawn,y_spawn)
