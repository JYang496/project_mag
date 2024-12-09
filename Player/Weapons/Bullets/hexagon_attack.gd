extends Node2D

@onready var module_parent = self.get_parent() # Bullet root is parent
@onready var rotate_timer: Timer = $RotateTimer
var linear_module : LinearMovement

var unit_of_time : int = 0
# Rotate when travel with 2, 3, 5, 6, 8, 9
var rotate_when : Array[int] = [2,3,5,6,8,9]
# Reverse when time is unit of 11, 8, 5
var reverse_when : int = -1

func _ready() -> void:
	if not module_parent:
		print("Error: module does not have owner")
		return
	for module in module_parent.module_list:
		if module is LinearMovement:
			linear_module = module


func _on_rotate_timer_timeout() -> void:
	unit_of_time += 1
	if unit_of_time == reverse_when:
		reverse()
	elif unit_of_time in rotate_when:
		rotate_by_degree(120)


func reverse() -> void:
	if linear_module == null:
		return
	rotate_timer.stop()
	linear_module.direction = - linear_module.direction
	linear_module.set_base_displacement()
	
	
func rotate_by_degree(degree : float) -> void:
	if linear_module == null:
		return
	linear_module.direction = linear_module.direction.rotated(deg_to_rad(degree))
	linear_module.set_base_displacement()
