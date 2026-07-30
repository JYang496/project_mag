extends WeaponBranchBehavior
class_name PistolArcBranch

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.ENERGY]

func get_damage_type_override() -> StringName:
	return Attack.TYPE_ENERGY

func get_energy_gain_per_damage_event() -> float:
	return 12.0

func get_energy_release_bonus_at_full() -> float:
	return 0.35

@export var trail_color: Color = Color(0.55, 0.75, 1.0, 0.9)
@export var trail_width: float = 2.5
@export var trail_max_points: int = 16
@export var trail_sample_interval_sec: float = 0.010
@export var trail_fade_sec: float = 0.2

func get_projectile_trail_config() -> Dictionary:
	return {
		"trail_color": trail_color,
		"trail_width": trail_width,
		"max_points": max(3, trail_max_points),
		"sample_interval_sec": maxf(trail_sample_interval_sec, 0.004),
		"trail_fade_sec": maxf(trail_fade_sec, 0.05),
	}

func get_energy_full_fire_passive_id() -> StringName:
	return &"pistol_arc_energy_cycle"

func get_energy_full_fire_display_name() -> String:
	return "Arc Discharge"
