extends Node2D
class_name Module

# Weapon -> Modules -> Module
@onready var weapon = self.get_parent().get_parent()
@export var cost : int
@onready var sprite: Sprite2D = %Sprite
@export var supports_melee: bool = true
@export var supports_ranged: bool = true

func _ready() -> void:
	pass

func can_apply_to_weapon(target_weapon: Weapon) -> bool:
	if not target_weapon:
		return false
	if target_weapon is Melee:
		return supports_melee
	if target_weapon is Ranger:
		return supports_ranged
	return true

func register_as_on_hit_plugin() -> void:
	if weapon and can_apply_to_weapon(weapon) and weapon.has_method("register_on_hit_plugin"):
		weapon.register_on_hit_plugin(self)

func unregister_as_on_hit_plugin() -> void:
	if weapon and weapon.has_method("unregister_on_hit_plugin"):
		weapon.unregister_on_hit_plugin(self)
