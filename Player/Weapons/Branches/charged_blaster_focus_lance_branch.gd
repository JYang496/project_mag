extends WeaponBranchBehavior
class_name ChargedBlasterFocusLanceBranch

@export var damage_multiplier: float = 2.0

func modify_charged_network_profile(profile: Dictionary) -> void:
	profile["damage"] = maxi(1, int(round(float(profile.get("damage", 1)) * damage_multiplier)))
	profile["max_chain_count"] = 0
	profile["beam_tag"] = "focus_tether"

func get_charged_turn_speed_multiplier() -> float:
	return 1.0

func get_charged_beam_profiles(base_profile: Dictionary) -> Array[Dictionary]:
	var profile := base_profile.duplicate(true)
	profile["beam_tag"] = "focus_main"
	return [profile]
