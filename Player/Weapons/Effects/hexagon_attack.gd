extends Node2D

@onready var module_parent = self.get_parent() # Bullet root is parent
@onready var rotate_timer: Timer = $RotateTimer
var linear_module : LinearMovement

var id : int
var wait_time : float = 0.2
var unit_of_period : int = 0

# Rotate when travel with 2, 3, 5, 6, 8, 9
var next_rotate_add : Array[int] = [1,2]
var next_rotate : int = 2
var next_rotate_index : int = 0

# Reverse when time is unit of 11, 8, 5
var reverse_when : int = -1

func _ready() -> void:
	if not module_parent:
		print("Error: module does not have owner")
		return
	for module in module_parent.module_list:
		if module is LinearMovement:
			linear_module = module
	rotate_timer.wait_time = wait_time
	rotate_timer.start()


func _on_rotate_timer_timeout() -> void:
	unit_of_period += 1
	if unit_of_period == reverse_when:
		reverse()
	elif unit_of_period == next_rotate:
		rotate_by_degree(120)
		next_rotate += next_rotate_add[next_rotate_index % 2]
		next_rotate_index += 1


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
