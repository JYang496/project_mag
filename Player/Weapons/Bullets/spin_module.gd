extends Node2D
class_name SpinModule

@onready var module_parent = self.get_parent() # Bullet root is parent


func _ready() -> void:
	if not module_parent:
		print("Error: spin module does not have owner")
		return

func _physics_process(delta: float) -> void:
	if not module_parent:
		print("Error: spin module does not have owner")
		return
	module_parent.bullet.rotation += 40 * delta
	if module_parent.bullet.rotation > 1000:
		module_parent.bullet.rotation -= 1000
