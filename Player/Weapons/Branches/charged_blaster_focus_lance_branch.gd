extends WeaponBranchBehavior
class_name ChargedBlasterFocusLanceBranch

@export var width_multiplier: float = 0.4
@export var range_multiplier: float = 1.35
@export var tick_damage_multiplier: float = 2.0
@export var hit_cd_multiplier: float = 0.5
@export var duration_multiplier: float = 1.6
@export var turn_speed_multiplier: float = 0.55

func get_charged_turn_speed_multiplier() -> float:
	return maxf(turn_speed_multiplier, 0.05)

func get_charged_beam_profiles(base_profile: Dictionary) -> Array[Dictionary]:
	var profile := base_profile.duplicate(true)
	profile["width_multiplier"] = maxf(float(profile.get("width_multiplier", 1.0)) * width_multiplier, 0.1)
	profile["range_multiplier"] = maxf(float(profile.get("range_multiplier", 1.0)) * range_multiplier, 0.1)
	profile["damage_multiplier"] = maxf(float(profile.get("damage_multiplier", 1.0)) * tick_damage_multiplier, 0.05)
	profile["hit_cd_multiplier"] = maxf(float(profile.get("hit_cd_multiplier", 1.0)) * hit_cd_multiplier, 0.05)
	profile["duration_multiplier"] = maxf(float(profile.get("duration_multiplier", 1.0)) * duration_multiplier, 0.05)
	profile["target_lock_mode"] = "none"
	profile["clip_to_nearest_target"] = true
	profile["fixed_width_no_charge"] = true
	profile["beam_tag"] = "focus_main"
	return [profile]
