extends Node2D
class_name Module

# Weapon -> Modules -> Module
@onready var weapon = self.get_parent().get_parent()
@export var cost : int
@onready var sprite: Sprite2D = %Sprite




func _ready() -> void:
	pass # Replace with function body.
