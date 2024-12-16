extends Node2D
class_name RotateAroundPlayer

var radius : float = 40.0
var angle : float = 0.0
var spin_speed : float = 3.0
var angle_offset :float = 0.0

@onready var player = get_tree().get_first_node_in_group("player")
@onready var module_parent = self.get_parent() # Bullet root is parent


func _ready() -> void:
	if not module_parent:
		print("Error: module does not have owner")
		return
	module_parent.base_displacement = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not module_parent:
		return
	angle += spin_speed * delta
	var x_pos = radius * cos(angle + angle_offset)
	var y_pos = radius * sin(angle + angle_offset)
	module_parent.global_position = Vector2(x_pos,y_pos) + player.global_position
