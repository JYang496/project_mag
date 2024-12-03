extends Node2D
class_name ReturnOnTimeout

@onready var module_parent = self.get_parent() # Bullet root is parent
var destination : Vector2

@onready var return_timer: Timer = $ReturnTimer
@onready var stop_timer: Timer = $StopTimer

var return_time : float = 1.0
var stop_time : float = 0.5

var is_return : bool = false
var is_stopped : bool = false

func _ready() -> void:
	if not module_parent:
		print("Error: spin module does not have owner")
		return
	stop_timer.wait_time = stop_time
	stop_timer.start()


func _on_return_timer_timeout() -> void:
	is_return = true
	module_parent.base_displacement = module_parent.base_displacement * -100


func _on_stop_timer_timeout() -> void:
	is_stopped = true
	module_parent.base_displacement = module_parent.base_displacement / 100
	return_timer.wait_time = return_time
	return_timer.start()
