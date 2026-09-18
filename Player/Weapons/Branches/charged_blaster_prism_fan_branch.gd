extends WeaponBranchBehavior
class_name ChargedBlasterPrismFanBranch

@export var side_angle_deg: float = 30.0
@export var beam_damage_multiplier: float = 0.65

func modify_charged_network_profile(profile: Dictionary) -> void:
	profile["beam_tag"] = "prism_chain_network"

func get_charged_beam_profiles(base_profile: Dictionary) -> Array[Dictionary]:
	var main_profile := base_profile.duplicate(true)
	var base_tag := str(base_profile.get("beam_tag", "main"))
	main_profile["damage_multiplier"] = maxf(float(main_profile.get("damage_multiplier", 1.0)) * beam_damage_multiplier, 0.05)
	main_profile["angle_offset_deg"] = 0.0
	main_profile["max_chain_count"] = 0
	main_profile["beam_tag"] = "prism_main" if base_tag != "focus_main" else "focus_prism_main"

	var left_profile := base_profile.duplicate(true)
	_configure_side_profile(left_profile)
	left_profile["angle_offset_deg"] = -absf(side_angle_deg)
	left_profile["beam_tag"] = "focus_prism_side" if base_tag == "focus_main" else "prism_side"

	var right_profile := base_profile.duplicate(true)
	_configure_side_profile(right_profile)
	right_profile["angle_offset_deg"] = absf(side_angle_deg)
	right_profile["beam_tag"] = "focus_prism_side" if base_tag == "focus_main" else "prism_side"

	return [main_profile, left_profile, right_profile]

func _configure_side_profile(profile: Dictionary) -> void:
	profile["damage_multiplier"] = maxf(float(profile.get("damage_multiplier", 1.0)) * beam_damage_multiplier, 0.05)
	profile["clip_to_nearest_target"] = false
	profile["target_lock_mode"] = "none"
	profile["max_chain_count"] = 0
