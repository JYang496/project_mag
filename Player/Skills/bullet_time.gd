extends Node2D

@export var time_scale = 0.5
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
	Engine.time_scale = time_scale
	
