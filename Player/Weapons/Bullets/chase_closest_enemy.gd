extends Node2D

@onready var module_parent : BulletBase = self.get_parent() # Bullet root is parent
@onready var detect_area: Area2D = $DetectArea


# This module applies after bullet created
func _ready() -> void:
	module_parent = self.get_parent()
	if not module_parent:
		print("Error: module does not have owner")
		return


func _physics_process(delta: float) -> void:
	# get closest enemy each frame:
	pass
