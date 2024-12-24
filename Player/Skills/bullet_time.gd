extends Node2D

@export var time_scale = 0.5
var saved_scale
var saved_speed
@onready var player = get_tree().get_first_node_in_group("player")
@onready var timer: Timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not player:
		print("Player does not exist")
		return
	player.connect("active_skill",Callable(self, "_on_active_skill"))
	
func _on_active_skill() -> void:
	timer.start()
	saved_scale = Engine.time_scale
	Engine.time_scale = time_scale
	saved_speed = PlayerData.player_speed * 3
	PlayerData.player_bonus_speed += saved_speed



func _on_timer_timeout() -> void:
	Engine.time_scale = saved_scale
	PlayerData.player_bonus_speed -= saved_speed
