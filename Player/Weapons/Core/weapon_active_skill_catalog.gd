extends RefCounted
class_name WeaponActiveSkillCatalog

const PROFILES := {
	&"machine_gun_infinite_chain": {"name_key": "ui.weapon.skill.machine_gun_infinite_chain.name", "description_key": "ui.weapon.skill.machine_gun_infinite_chain.description", "fallback_name": "Infinite Ammo Chain", "fallback_description": "For 3 seconds, shots consume no ammo and attack speed is multiplied by 5. Every 5 damaging hits grants +8% damage, up to 5 stacks.", "duration": 3.0},
	&"charged_blaster_prism_overload": {"name_key": "ui.weapon.skill.charged_blaster_prism_overload.name", "description_key": "ui.weapon.skill.charged_blaster_prism_overload.description", "fallback_name": "Prism Overload", "fallback_description": "The next charged beam splits into 6 homing energy bolts when it ends. Each bolt deals 35% weapon damage.", "duration": 0.0},
	&"spear_phalanx": {"name_key": "ui.weapon.skill.spear_phalanx.name", "description_key": "ui.weapon.skill.spear_phalanx.description", "fallback_name": "Spear Phalanx", "fallback_description": "Fire 8 returning spears in a 40-degree spread toward the target. Their hits apply a mark that increases subsequent spear damage by 35%.", "duration": 0.0},
	&"shotgun_double_discipline": {"name_key": "ui.weapon.skill.shotgun_double_discipline.name", "description_key": "ui.weapon.skill.shotgun_double_discipline.description", "fallback_name": "Double-Barrel Discipline", "fallback_description": "The next 2 attacks cost no ammo and fire twice as fast. Each attack still fires a second shot after 0.1 seconds for 60% damage.", "duration": 0.0},
	&"orbit_proliferation": {"name_key": "ui.weapon.skill.orbit_proliferation.name", "description_key": "ui.weapon.skill.orbit_proliferation.description", "fallback_name": "Orbital Proliferation", "fallback_description": "Deploy 3 temporary satellites for 8 seconds. Temporary satellites deal 70% normal damage.", "duration": 8.0},
	&"rocket_cluster_warhead": {"name_key": "ui.weapon.skill.rocket_cluster_warhead.name", "description_key": "ui.weapon.skill.rocket_cluster_warhead.description", "fallback_name": "Cluster Warhead", "fallback_description": "The next rocket splits into 8 bomblets on detonation. Each deals 30% weapon damage; repeated hits on one target diminish.", "duration": 0.0},
	&"laser_refraction_matrix": {"name_key": "ui.weapon.skill.laser_refraction_matrix.name", "description_key": "ui.weapon.skill.laser_refraction_matrix.description", "fallback_name": "Refraction Matrix", "fallback_description": "For 4 seconds, laser hits refract to up to 3 nearby enemies for 60%, 45%, and 30% damage.", "duration": 4.0},
	&"chainsaw_cage": {"name_key": "ui.weapon.skill.chainsaw_cage.name", "description_key": "ui.weapon.skill.chainsaw_cage.description", "fallback_name": "Chainsaw Cage", "fallback_description": "Electrify the boundary of your current cell for 4 seconds, continuously damaging enemies that touch it.", "duration": 0.0},
	&"dash_rift": {"name_key": "ui.weapon.skill.dash_rift.name", "description_key": "ui.weapon.skill.dash_rift.description", "fallback_name": "Dimensional Rift", "fallback_description": "Your next dash leaves a rift for 3 seconds, dealing 35% weapon damage every 0.4 seconds.", "duration": 0.0},
	&"flame_moving_inferno": {"name_key": "ui.weapon.skill.flame_moving_inferno.name", "description_key": "ui.weapon.skill.flame_moving_inferno.description", "fallback_name": "Moving Inferno", "fallback_description": "For 5 seconds, leave burning ground along your path and beneath enemies hit by the flamethrower.", "duration": 5.0},
	&"plasma_storm": {"name_key": "ui.weapon.skill.plasma_storm.name", "description_key": "ui.weapon.skill.plasma_storm.description", "fallback_name": "Plasma Storm", "fallback_description": "Create a 4-second plasma storm that pulls ordinary enemies inward and deals 45% weapon damage every 0.5 seconds.", "duration": 0.0},
	&"glacier_white_frost_domain": {"name_key": "ui.weapon.skill.glacier_white_frost_domain.name", "description_key": "ui.weapon.skill.glacier_white_frost_domain.description", "fallback_name": "White Frost Domain", "fallback_description": "Create a 6-second field around you. Enemies slow and freeze after 2 seconds; you move faster inside it.", "duration": 0.0},
	&"cannon_siege_trajectory": {"name_key": "ui.weapon.skill.cannon_siege_trajectory.name", "description_key": "ui.weapon.skill.cannon_siege_trajectory.description", "fallback_name": "Siege Trajectory", "fallback_description": "Fire a slow giant shell that pushes enemies aside and erupts three times for 60%, 90%, and 120% weapon damage.", "duration": 0.0},
	&"sniper_lethal_aim": {"name_key": "ui.weapon.skill.sniper_lethal_aim.name", "description_key": "ui.weapon.skill.sniper_lethal_aim.description", "fallback_name": "Lethal Aim", "fallback_description": "The next shot gains +250% damage, unlimited pierce, and up to +100% additional damage with distance.", "duration": 0.0},
}

static func get_profile(effect_id: StringName) -> Dictionary:
	return (PROFILES.get(effect_id, {}) as Dictionary).duplicate(true)

static func get_skill_name(effect_id: StringName) -> String:
	var profile := get_profile(effect_id)
	var fallback := str(profile.get("fallback_name", "Weapon Skill"))
	return _translate(str(profile.get("name_key", "")), fallback)

static func get_skill_description(effect_id: StringName) -> String:
	var profile := get_profile(effect_id)
	var fallback := str(profile.get("fallback_description", ""))
	return _translate(str(profile.get("description_key", "")), fallback)

static func get_duration(effect_id: StringName) -> float:
	return maxf(float(get_profile(effect_id).get("duration", 0.0)), 0.0)

static func _translate(key: String, fallback: String) -> String:
	if key != "" and LocalizationManager != null and LocalizationManager.has_method("tr_key"):
		return LocalizationManager.tr_key(key, fallback)
	return fallback
