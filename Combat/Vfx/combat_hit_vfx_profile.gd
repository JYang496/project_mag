class_name CombatHitVfxProfile
extends Resource

enum HitType {
	KINETIC_LIGHT,
	KINETIC_HEAVY,
	ENERGY,
	SHIELD_IMPACT,
	CRITICAL_HIT,
	ARMOR_BREAK,
}

@export var hit_type: HitType = HitType.KINETIC_LIGHT
@export var impact_color: Color = Color.WHITE
@export_range(0.08, 0.24, 0.01) var duration_sec := 0.10
@export_range(0.5, 2.5, 0.05) var impact_scale := 1.0
@export_range(0, 2, 1) var texture_pattern := 0


static func from_damage_result(result: DamageResult, target_max_hp: int) -> Resource:
	if result == null:
		return create(HitType.KINETIC_LIGHT)
	if result.is_critical:
		return create(HitType.CRITICAL_HIT)
	if result.damage_type == Attack.TYPE_ENERGY or result.damage_type == Attack.TYPE_FIRE or result.damage_type == Attack.TYPE_FREEZE:
		return create(HitType.ENERGY)
	var damage_ratio := float(result.final_damage) / float(maxi(target_max_hp, 1))
	return create(HitType.KINETIC_HEAVY if damage_ratio >= 0.12 else HitType.KINETIC_LIGHT)


static func create(type: HitType) -> Resource:
	var profile = load("res://Combat/Vfx/combat_hit_vfx_profile.gd").new()
	profile.hit_type = type
	match type:
		HitType.KINETIC_HEAVY:
			profile.impact_color = Color(1.0, 0.87, 0.68, 1.0)
			profile.duration_sec = 0.18
			profile.impact_scale = 1.45
			profile.texture_pattern = 1
		HitType.ENERGY:
			profile.impact_color = Color(0.34, 0.88, 1.0, 1.0)
			profile.duration_sec = 0.15
			profile.impact_scale = 1.25
			profile.texture_pattern = 2
		HitType.SHIELD_IMPACT:
			profile.impact_color = Color(0.26, 0.76, 1.0, 1.0)
			profile.duration_sec = 0.16
			profile.impact_scale = 1.35
			profile.texture_pattern = 2
		HitType.CRITICAL_HIT:
			profile.impact_color = Color.WHITE
			profile.duration_sec = 0.20
			profile.impact_scale = 1.75
			profile.texture_pattern = 1
		HitType.ARMOR_BREAK:
			profile.impact_color = Color(1.0, 0.55, 0.18, 1.0)
			profile.duration_sec = 0.22
			profile.impact_scale = 1.65
			profile.texture_pattern = 1
		_:
			profile.impact_color = Color.WHITE
			profile.duration_sec = 0.10
			profile.impact_scale = 1.0
			profile.texture_pattern = 0
	return profile
