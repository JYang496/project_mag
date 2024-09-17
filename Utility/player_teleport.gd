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

func _physics_process(delta: float) -> void:
	if timeout and dest != null:
		player.set_collision_mask_value(6,false)
		player.move_to(dest.global_position)
		PlayerData.player_bonus_speed = 300.0
		if player.global_position.distance_to(dest.global_position) < 100:
			# Update signal with speed 30
			PlayerData.player_bonus_speed = 30.0
			pass
		if player.global_position.distance_to(dest.global_position) < 5:
			connect("enable_enemy_spawner",Callable(enemy_spawner,"start_timer"))
			player.arrived()
			player.set_collision_mask_value(6,true)
			PlayerData.player_bonus_speed = 0.0
			emit_signal("enable_enemy_spawner")
			PhaseManager.enter_battle()
			timeout = false
			return

func set_dest(node:Node2D) -> void:
	dest = node

func _on_timer_timeout() -> void:
	timeout = true

# This function is called by signal from prepare_zone_gate
func tp_to_battle_zone() -> void:
	pass


func _on_prepare_zone_gate_tp_to_battle_zone() -> void:
	timer.start()
	set_dest(dest1)
	pass # Replace with function body.
