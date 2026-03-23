extends WeaponBranchBehavior
class_name MachineGunTwinBranch

@export var cooldown_multiplier: float = 0.7
@export var extra_spread_deg: float = 4.0
@export var projectile_count: int = 2
@export_range(0.0, 1.0, 0.05) var extra_heat_shot_multiplier: float = 0.2

func get_shot_directions(base_direction: Vector2, shot_count: int = -1) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	var count: int = projectile_count if shot_count < 0 else shot_count
	count = clampi(count, 1, 32)
	var normalized_base := base_direction.normalized()
	if count <= 0:
		count = 1
	if count == 1:
		return [normalized_base]

	if count % 2 == 1:
		dirs.append(normalized_base)

	var half_pairs := count / 2
	var spread_rad := deg_to_rad(extra_spread_deg)
	for i in range(half_pairs):
		var angle := spread_rad * float(i + 1)
		dirs.append(normalized_base.rotated(-angle))
		dirs.append(normalized_base.rotated(angle))
	return dirs

func get_additional_shot_directions(base_direction: Vector2, _shot_count: int = 2) -> Array[Vector2]:
	return get_shot_directions(base_direction, 2)

func get_cooldown_multiplier() -> float:
	return cooldown_multiplier

func get_extra_heat_shot_multiplier() -> float:
	return clampf(extra_heat_shot_multiplier, 0.0, 1.0)
