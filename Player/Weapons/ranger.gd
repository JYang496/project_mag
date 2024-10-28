extends Node2D
class_name Ranger

@onready var player = get_tree().get_first_node_in_group("player")
var justAttacked = false

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

func _on_detect_area_body_entered(body):
	if not target_close.has(body) and body.is_in_group("enemy"):
		target_close.append(body)

func _on_detect_area_body_exited(body):
	if target_close.has(body):
		target_close.erase(body)
