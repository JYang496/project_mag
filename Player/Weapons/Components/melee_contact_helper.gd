extends RefCounted
class_name MeleeContactHelper

var weapon: Node2D

func setup(source_weapon: Node2D) -> void:
	weapon = source_weapon

func get_range_center() -> Vector2:
	if PlayerData.player and is_instance_valid(PlayerData.player):
		return PlayerData.player.global_position
	return weapon.global_position

func setup_attack_range_area(area: Area2D) -> void:
	if not area:
		return
	area.top_level = true
	area.global_position = get_range_center()

func center_attack_range_area(area: Area2D) -> void:
	if not area:
		return
	area.global_position = get_range_center()
