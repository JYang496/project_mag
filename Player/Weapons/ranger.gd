extends Node2D
class_name Ranger

@onready var player = get_tree().get_first_node_in_group("player")
var linear_movement = preload("res://Player/Weapons/Bullets/linear_movement.tscn")
var spiral_movement = preload("res://Player/Weapons/Bullets/spiral_movement.tscn")
var ricochet_module = preload("res://Player/Weapons/Bullets/ricochet_module.tscn")

var justAttacked = false
var module_list = []
# object that needs to be overwrited in child class
var object

# Enemy realted
var target_close = []

signal shoot()

func _physics_process(_delta):
	if not justAttacked and Input.is_action_pressed("ATTACK"):
		emit_signal("shoot")

func _on_cooldown_timer_timeout():
	justAttacked = false

func _input(event: InputEvent) -> void:
	pass


func _on_shoot():
	justAttacked = true
	var spawn_object = object.instantiate()
	spawn_object.target = get_random_target()
	spawn_object.global_position = global_position
	player.add_sibling(spawn_object)

func get_random_target():
	if target_close.size() > 0:
		var target = target_close.pick_random()
		return target.global_position
	else: 
		return get_global_mouse_position()

func enable_linear(blt_node : Node2D, direction : Vector2 = Vector2.UP, blt_speed : float = 400.0) -> void:
	var linear_movement_ins = linear_movement.instantiate()
	linear_movement_ins.direction = direction
	linear_movement_ins.speed = blt_speed
	blt_node.call_deferred("add_child",linear_movement_ins)
	blt_node.module_list.append(linear_movement_ins)
	module_list.append(linear_movement_ins)

func enable_spiral(blt_node : Node2D, blt_spin_rate : float = PI, blt_spin_speed : float = 100.0) -> void:
	var spiral_movement_ins = spiral_movement.instantiate()
	spiral_movement_ins.spin_rate = blt_spin_rate
	spiral_movement_ins.spin_speed = blt_spin_speed
	blt_node.call_deferred("add_child",spiral_movement_ins)
	blt_node.module_list.append(spiral_movement_ins)
	module_list.append(spiral_movement_ins)

func enable_ricochet(blt_node : Node2D) -> void:
	var ricochet_module_ins = ricochet_module.instantiate()
	blt_node.call_deferred("add_child",ricochet_module_ins)
	blt_node.module_list.append(ricochet_module_ins)
	module_list.append(ricochet_module_ins)

func _on_detect_area_body_entered(body):
	if not target_close.has(body) and body.is_in_group("enemy"):
		target_close.append(body)

func _on_detect_area_body_exited(body):
	if target_close.has(body):
		target_close.erase(body)
