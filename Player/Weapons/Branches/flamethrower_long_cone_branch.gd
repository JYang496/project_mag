extends WeaponBranchBehavior
class_name FlamethrowerLongConeBranch

@export var attack_range_multiplier: float = 2.0
@export var cone_half_angle_multiplier: float = 0.5

func get_attack_range_multiplier() -> float:
	return maxf(attack_range_multiplier, 0.1)

func get_cone_half_angle_multiplier() -> float:
	return maxf(cone_half_angle_multiplier, 0.1)

func get_damage_multiplier() -> float:
	return 1.0

func get_cooldown_multiplier() -> float:
	return 1.0
