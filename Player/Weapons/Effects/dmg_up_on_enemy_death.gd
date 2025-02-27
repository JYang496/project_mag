extends Node2D

@onready var module_parent = self.get_parent() # Bullet root is parent
@onready var detect_area: Area2D = $DetectArea
@export var dmg_up_per_kill : int = 2

func _ready() -> void:
	module_parent = self.get_parent()
	if not module_parent:
		print("Error: module does not have owner")
		return


func _on_detect_area_area_entered(area: Area2D) -> void:
	if area is HurtBox and area.hurtbox_owner.is_in_group("enemies"):
		# Check if the signal is already connected before attempting to connect
		if not area.hurtbox_owner.is_connected("enemy_death", Callable(self, "_on_enemy_death")):
			area.hurtbox_owner.connect("enemy_death", Callable(self, "_on_enemy_death"))

func _on_enemy_death() -> void:
	if "damage" in module_parent:
		module_parent.damage += dmg_up_per_kill

func _on_detect_area_area_exited(area: Area2D) -> void:
	if area is HurtBox and area.hurtbox_owner.is_in_group("enemies"):
		# Check if the signal is already connected before attempting to connect
		if area.hurtbox_owner.is_connected("enemy_death", Callable(self, "_on_enemy_death")):
			area.hurtbox_owner.disconnect("enemy_death", Callable(self, "_on_enemy_death"))
