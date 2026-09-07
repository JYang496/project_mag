extends WeaponBranchBehavior
class_name GlacierWhiteoutExpansionBranch

@export var trail_width_multiplier: float = 1.50

func get_glacier_trail_width_multiplier() -> float:
	return maxf(trail_width_multiplier, 1.0)
