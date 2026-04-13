extends WeaponBranchBehavior
class_name ChargedBlasterPrismFanBranch

@export var side_angle_deg: float = 30.0
@export var main_damage_multiplier: float = 0.8
@export var side_damage_multiplier: float = 0.45

func get_charged_beam_profiles(base_profile: Dictionary) -> Array[Dictionary]:
	var main_profile := base_profile.duplicate(true)
	main_profile["damage_multiplier"] = maxf(float(main_profile.get("damage_multiplier", 1.0)) * main_damage_multiplier, 0.05)
	main_profile["angle_offset_deg"] = 0.0
	main_profile["beam_tag"] = "prism_main"

	var left_profile := base_profile.duplicate(true)
	left_profile["damage_multiplier"] = maxf(float(left_profile.get("damage_multiplier", 1.0)) * side_damage_multiplier, 0.05)
	left_profile["angle_offset_deg"] = -absf(side_angle_deg)
	left_profile["beam_tag"] = "prism_side"

	var right_profile := base_profile.duplicate(true)
	right_profile["damage_multiplier"] = maxf(float(right_profile.get("damage_multiplier", 1.0)) * side_damage_multiplier, 0.05)
	right_profile["angle_offset_deg"] = absf(side_angle_deg)
	right_profile["beam_tag"] = "prism_side"

	return [main_profile, left_profile, right_profile]
