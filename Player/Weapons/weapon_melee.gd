extends Weapon
class_name Melee

# Shared melee rule: attack-range queries should be centered on player.
func get_melee_range_center() -> Vector2:
	if PlayerData.player and is_instance_valid(PlayerData.player):
		return PlayerData.player.global_position
	return global_position

func setup_melee_attack_range_area(area: Area2D) -> void:
	if not area:
		return
	area.top_level = true
	area.global_position = get_melee_range_center()

func center_melee_attack_range_area(area: Area2D) -> void:
	if not area:
		return
	area.global_position = get_melee_range_center()
