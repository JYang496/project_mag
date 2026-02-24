extends Node2D
class_name Effect

@onready var projectile: Projectile = self.find_parent("*") as Projectile
@onready var melee: Melee = self.find_parent("*") as Melee
@export var supports_ranged: bool = true
@export var supports_melee: bool = false

func _ready() -> void:
	if projectile:
		if not supports_ranged:
			queue_free()
			return
		projectile_effect_ready()
	elif melee:
		if not supports_melee:
			queue_free()
			return
		melee_effect_ready()
	
func projectile_effect_ready() -> void:
	pass

func melee_effect_ready() -> void:
	pass
