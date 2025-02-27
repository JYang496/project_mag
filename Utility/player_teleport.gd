extends Node

var dest : Node2D
var timeout := false
@onready var dest1 = $Dest1
@onready var dest2 = $Dest2
@onready var timer = $Timer
@onready var player = get_tree().get_first_node_in_group("player")
@onready var enemy_spawner = get_tree().get_first_node_in_group("enemy_spawner")

@export var speed = 300

signal enable_enemy_spawner()

func _physics_process(_delta: float) -> void:
	if timeout and dest != null:
		player.set_collision_mask_value(6,false)
		player.move_to(dest.global_position)
		PlayerData.player_bonus_speed = 900.0
		if player.global_position.distance_to(dest.global_position) < 100:
			# Update signal with speed 30
			PlayerData.player_bonus_speed = 30.0
			pass
		if player.global_position.distance_to(dest.global_position) < 5:
			timeout = false
			player.arrived()
			player.set_collision_mask_value(6,true)
			PlayerData.player_bonus_speed = 0.0
			if PhaseManager.current_state() == PhaseManager.PREPARE:
				if not is_connected("enable_enemy_spawner",Callable(enemy_spawner,"start_timer")):
					connect("enable_enemy_spawner",Callable(enemy_spawner,"start_timer"))
				enable_enemy_spawner.emit()
				PhaseManager.enter_battle()
			if PhaseManager.current_state() == PhaseManager.REWARD:
				PhaseManager.enter_prepare()
			return

func set_dest(node:Node2D) -> void:
	dest = node

func _on_timer_timeout() -> void:
	timeout = true


func _on_prepare_zone_gate_tp_to_dest_1() -> void:
	timer.start()
	set_dest(dest1)
	pass # Replace with function body.


func _on_battle_zone_teleporter_tp_to_dest_1() -> void:
	timer.start()
	set_dest(dest1)
	pass # Replace with function body.
