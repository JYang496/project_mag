extends Node2D

@onready var module_parent = self.get_parent() # Bullet root is parent

func _ready() -> void:
	module_parent = self.get_parent()
	if not module_parent:
		print("Error: module does not have owner")
		return
	module_parent.tree_exiting.connect(_on_parent_exiting)
	module_parent.tree_exited.connect(_on_parent_exited)

func _on_parent_exiting() -> void:
	print(module_parent,"exiting")

func _on_parent_exited() -> void:
	print(module_parent,"exited")

func _physics_process(delta: float) -> void:
	pass
