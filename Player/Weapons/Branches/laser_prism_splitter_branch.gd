extends WeaponBranchBehavior
class_name LaserPrismSplitterBranch

@export var side_angle_deg: float = 15.0
@export var beam_damage_multiplier: float = 0.65

func get_laser_beam_profiles(base_profile: Dictionary) -> Array[Dictionary]:
	var main_profile := base_profile.duplicate(true)
	main_profile["angle_offset_deg"] = 0.0
	main_profile["damage_multiplier"] = maxf(float(main_profile.get("damage_multiplier", 1.0)) * beam_damage_multiplier, 0.05)
	main_profile["beam_tag"] = "prism_main"

	var left_profile := base_profile.duplicate(true)
	_configure_side_profile(left_profile, -absf(side_angle_deg))

	var right_profile := base_profile.duplicate(true)
	_configure_side_profile(right_profile, absf(side_angle_deg))

	return [main_profile, left_profile, right_profile]

func _configure_side_profile(profile: Dictionary, angle_offset_deg: float) -> void:
	profile["angle_offset_deg"] = angle_offset_deg
	profile["damage_multiplier"] = maxf(float(profile.get("damage_multiplier", 1.0)) * beam_damage_multiplier, 0.05)
	profile["beam_tag"] = "prism_side"
