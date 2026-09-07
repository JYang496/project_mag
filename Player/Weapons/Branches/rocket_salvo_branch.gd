extends WeaponBranchBehavior
class_name RocketSalvoBranch

@export var cooldown_multiplier: float = 1.55
@export var projectile_damage_multiplier: float = 0.8
@export var projectile_count: int = 3
@export var spread_deg: float = 10.0
@export var seek_turn_rate_deg_per_sec: float = 82.5
@export var seek_search_radius: float = 480.0
@export var seek_max_lock_angle_deg: float = 62.0

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_projectile_damage_multiplier() -> float:
	return maxf(projectile_damage_multiplier, 0.05)

# Splits one rocket shot into multiple directions for a salvo pattern.
func get_shot_directions(base_direction: Vector2, shot_count: int = -1) -> Array[Vector2]:
	var count := projectile_count if shot_count < 0 else shot_count
	count = clampi(count, 1, 12)
	var spread_step := deg_to_rad(spread_deg)
	return build_centered_spread_directions(base_direction, count, spread_step)

func get_rocket_homing_profile() -> Dictionary:
	return {
		"turn_rate_deg_per_sec": maxf(seek_turn_rate_deg_per_sec, 0.1),
		"acquisition_radius": maxf(seek_search_radius, 1.0),
		"acquisition_half_angle_deg": clampf(seek_max_lock_angle_deg, 0.0, 180.0),
	}
