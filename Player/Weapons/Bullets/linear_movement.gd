extends Node2D
class_name LinearMovement

@export var speed: float = 400.0
@export var direction: Vector2 = Vector2.ZERO

@onready var module_parent = self.get_parent() # Bullet root is parent


func _ready() -> void:
	if not module_parent:
		print("Error: module does not have owner")
		return
	adjust_base_displacement()

func adjust_base_displacement() -> void:
	module_parent.base_displacement = module_parent.base_displacement + direction * speed

func _physics_process(delta: float) -> void:
	pass
