extends WeaponBranchBehavior
class_name PlasmaOverchargeLanceBranch

@export var overcharge_stack_duration_sec: float = 5.0
@export var overcharge_extra_heat_per_stack: float = 5.0
@export var overcharge_damage_bonus_per_stack: float = 0.25

func get_overcharge_lance_config() -> Dictionary:
	return {
		"duration": maxf(overcharge_stack_duration_sec, 0.05),
		"extra_heat_per_stack": maxf(overcharge_extra_heat_per_stack, 0.0),
		"damage_bonus_per_stack": maxf(overcharge_damage_bonus_per_stack, 0.0),
	}
