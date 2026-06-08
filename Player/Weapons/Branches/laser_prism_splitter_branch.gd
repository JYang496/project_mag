extends WeaponBranchBehavior
class_name LaserPrismSplitterBranch

@export var side_angle_deg: float = 15.0
@export var side_damage_multiplier: float = 0.55
@export var side_width_multiplier: float = 0.85

func get_laser_beam_profiles(base_profile: Dictionary) -> Array[Dictionary]:
	var main_profile := base_profile.duplicate(true)
	main_profile["angle_offset_deg"] = 0.0
	main_profile["beam_tag"] = "prism_main"

	var left_profile := base_profile.duplicate(true)
	_configure_side_profile(left_profile, -absf(side_angle_deg))

	var right_profile := base_profile.duplicate(true)
	_configure_side_profile(right_profile, absf(side_angle_deg))

	return [main_profile, left_profile, right_profile]

func _configure_side_profile(profile: Dictionary, angle_offset_deg: float) -> void:
	profile["angle_offset_deg"] = angle_offset_deg
	var damage_multiplier := 1.0 if _has_tracking_lens() else side_damage_multiplier
	profile["damage_multiplier"] = maxf(float(profile.get("damage_multiplier", 1.0)) * damage_multiplier, 0.05)
	profile["width_multiplier"] = maxf(float(profile.get("width_multiplier", 1.0)) * side_width_multiplier, 0.05)
	profile["beam_tag"] = "prism_side"

func _has_tracking_lens() -> bool:
	return weapon != null and is_instance_valid(weapon) and weapon.has_branch("laser_tracking_lens")
