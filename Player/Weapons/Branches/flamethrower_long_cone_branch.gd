extends WeaponBranchBehavior
class_name FlamethrowerLongConeBranch

@export var attack_range_multiplier: float = 1.45
@export var cone_half_angle_multiplier: float = 0.5
@export var damage_multiplier: float = 1.28
@export var cooldown_multiplier: float = 0.82

func get_attack_range_multiplier() -> float:
	return maxf(attack_range_multiplier, 0.1)

func get_cone_half_angle_multiplier() -> float:
	return maxf(cone_half_angle_multiplier, 0.1)

func get_damage_multiplier() -> float:
	return maxf(damage_multiplier, 0.05)

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)
