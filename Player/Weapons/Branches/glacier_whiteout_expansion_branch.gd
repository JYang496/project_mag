extends WeaponBranchBehavior
class_name GlacierWhiteoutExpansionBranch

@export var cone_half_angle_multiplier: float = 1.50

func get_cone_half_angle_multiplier() -> float:
	return maxf(cone_half_angle_multiplier, 1.0)
