extends Player
class_name HeavyAssault

func custom_ready() -> void:
	create_weapon("1")
	_apply_heavy_assault_loadout()

func _apply_heavy_assault_loadout() -> void:
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if weapon.has_method("configure_heavy_assault_profile"):
			weapon.call("configure_heavy_assault_profile")
			return
