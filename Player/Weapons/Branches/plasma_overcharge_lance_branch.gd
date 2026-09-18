extends WeaponBranchBehavior
class_name PlasmaOverchargeLanceBranch

@export_range(0.0, 1.0, 0.05) var overcharge_heat_ratio_threshold: float = 0.5
@export var overcharge_damage_bonus: float = 0.5

func get_overcharge_lance_config() -> Dictionary:
	return {
		"heat_ratio_threshold": clampf(overcharge_heat_ratio_threshold, 0.0, 1.0),
		"flat_damage_bonus": maxf(overcharge_damage_bonus, 0.0),
	}
