extends Node2D
class_name Effect

@onready var bullet = self.find_parent("*") as BulletBase
@onready var melee = self.find_parent("*") as Melee

func _ready() -> void:
	if bullet:
		bullet_effect_ready()
	elif melee:
		melee_effect_ready()
	
func bullet_effect_ready() -> void:
	prints("Effect Bullet",bullet)

func melee_effect_ready() -> void:
	prints("Effect Melee")
