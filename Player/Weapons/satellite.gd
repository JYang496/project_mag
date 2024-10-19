extends Node2D

var radius : float = 40.0
var angle : float = 0.0
var spin_speed : float = 3.0
var angle_offset :float = 0.0

@onready var player = get_tree().get_first_node_in_group("player")
var damage = 7

func _physics_process(delta: float) -> void:
	angle += spin_speed * delta
	var x_pos = radius * cos(angle + angle_offset)
	var y_pos = radius * sin(angle + angle_offset)
	self.global_position = Vector2(x_pos,y_pos) + player.global_position
