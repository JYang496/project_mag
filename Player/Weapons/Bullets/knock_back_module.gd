extends Node2D
class_name KnockBackModulde

@onready var module_parent = self.get_parent() # Bullet root is parent
var direction : Vector2 = Vector2.ZERO
var amount : float = 0.0


func _ready() -> void:
	if not module_parent:
		print("Error: module does not have owner")
		return
	if "knock_back" in module_parent:
		module_parent.knock_back = {"amount": amount, "angle": direction}

func _physics_process(delta: float) -> void:
	pass
