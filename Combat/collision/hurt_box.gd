extends Area2D
class_name HurtBox

var hurtbox_owner: Node

@onready var collision = $CollisionShape2D

func _ready() -> void:
	hurtbox_owner = _resolve_damage_target()

func get_damage_target() -> Node:
	var target := hurtbox_owner
	if target == null or not is_instance_valid(target):
		target = _resolve_damage_target()
		hurtbox_owner = target
	return target

func _resolve_damage_target() -> Node:
	var target := get_owner()
	if target != null and is_instance_valid(target):
		return target
	target = get_parent()
	if target != null and is_instance_valid(target):
		return target
	return null

func _on_area_entered(_area):
	pass
