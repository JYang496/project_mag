extends WeaponBranchBehavior
class_name PlasmaPiercingLanceBranch

func get_plasma_wall_profile() -> Dictionary:
	return {
		"width_multiplier": 1.45,
		"travel_distance_multiplier": 1.18,
		"thickness_multiplier": 0.85,
	}
