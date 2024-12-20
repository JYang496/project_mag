extends Area2D
class_name HurtBox

@onready var hurtbox_owner = get_owner()

@onready var collision = $CollisionShape2D


func _on_area_entered(_area):
	pass
