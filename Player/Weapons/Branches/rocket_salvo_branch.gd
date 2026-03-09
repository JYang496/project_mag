extends WeaponBranchBehavior
class_name RocketSalvoBranch

@export var cooldown_multiplier: float = 1.55
@export var projectile_damage_multiplier: float = 0.65
@export var projectile_count: int = 3
@export var spread_deg: float = 10.0

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_projectile_damage_multiplier() -> float:
	return maxf(projectile_damage_multiplier, 0.05)

# Splits one rocket shot into multiple directions for a salvo pattern.
func get_shot_directions(base_direction: Vector2, shot_count: int = -1) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	var count := projectile_count if shot_count < 0 else shot_count
	count = clampi(count, 1, 12)
	var normalized_base := base_direction.normalized()
	if count == 1:
		return [normalized_base]
	var spread_step := deg_to_rad(spread_deg)
	var center_offset := float(count - 1) * 0.5
	for i in range(count):
		var angle := (float(i) - center_offset) * spread_step
		dirs.append(normalized_base.rotated(angle))
	return dirs
