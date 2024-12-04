extends Node2D
class_name ReturnOnTimeout

@onready var module_parent = self.get_parent() # Bullet root is parent
@onready var player = get_tree().get_first_node_in_group("player")
var destination : Vector2

@onready var return_timer: Timer = $ReturnTimer
@onready var stop_timer: Timer = $StopTimer

var return_time : float = 1.0
var stop_time : float = 0.5

var is_return : bool = false
var is_stopped : bool = false
var saved_displacement : Vector2

func _ready() -> void:
	if not module_parent:
		print("Error: spin module does not have owner")
		return
	stop_timer.wait_time = stop_time
	stop_timer.start()


func _on_return_timer_timeout() -> void:
	is_return = true
	module_parent.base_displacement = module_parent.global_position.direction_to(player.global_position)


func _on_stop_timer_timeout() -> void:
	is_stopped = true
	saved_displacement = module_parent.base_displacement
	module_parent.base_displacement = Vector2.ZERO
	return_timer.wait_time = return_time
	return_timer.start()
