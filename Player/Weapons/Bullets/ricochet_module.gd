extends Node2D

@onready var module_parent = self.get_parent() # Bullet root is parent
var target_close = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not module_parent:
		print("Error: module does not have owner")
		return
	# Connect enemy hit with function
	
func get_random_target():
	if target_close.size() > 0:
		var target = target_close.pick_random()
		return target.global_position
	else: 
		var random_position = global_position + Vector2(randi_range(-64,64),randi_range(-64,64))
		return random_position

func _on_range_body_entered(body: Node2D) -> void:
	if not target_close.has(body) and body.is_in_group("enemy"):
		target_close.append(body)


func _on_range_body_exited(body: Node2D) -> void:
	if target_close.has(body):
		target_close.erase(body)
