extends Node2D

@onready var module_parent = self.get_parent() # Bullet root is parent
var target_close = []
var attemp := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not module_parent:
		print("Error: module does not have owner")
		return
	# Connect enemy hit with function
	if module_parent.has_signal("enemy_hit_signal"):
		module_parent.enemy_hit_signal.connect(change_direction)


func change_direction() -> void:
	for module in module_parent.module_list:
		if module is LinearMovement:
			module.direction = self.global_position.direction_to(get_random_target())
			module.set_base_displacement()


func get_random_target():
	if target_close.size() > 1:
		var target = target_close.pick_random()
		if target.global_position.distance_to(global_position) < 24 and attemp < 3:
			attemp += 1
			return get_random_target()
		attemp = 0
		return target.global_position
	else: 
		var random_position = global_position + Vector2(randi_range(-64,64),randi_range(-64,64))
		return random_position

func _on_range_body_entered(body: Node2D) -> void:
	if not target_close.has(body) and body.is_in_group("enemies"):
		target_close.append(body)


func _on_range_body_exited(body: Node2D) -> void:
	if target_close.has(body):
		target_close.erase(body)
