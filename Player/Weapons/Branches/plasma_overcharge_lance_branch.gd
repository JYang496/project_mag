extends WeaponBranchBehavior
class_name PlasmaOverchargeLanceBranch

@export var overcharge_stack_duration_sec: float = 5.0
@export_range(0.0, 1.0, 0.05) var overcharge_heat_ratio_threshold: float = 0.7
@export var overcharge_max_stacks: int = 3
@export var overcharge_damage_bonus_per_stack: float = 0.25

func get_overcharge_lance_config() -> Dictionary:
	return {
		"duration": maxf(overcharge_stack_duration_sec, 0.05),
		"heat_ratio_threshold": clampf(overcharge_heat_ratio_threshold, 0.0, 1.0),
		"max_stacks": maxi(overcharge_max_stacks, 1),
		"damage_bonus_per_stack": maxf(overcharge_damage_bonus_per_stack, 0.0),
	}
