extends WeaponBranchBehavior
class_name PlasmaPiercingLanceBranch

@export var pierce_damage_gain_per_hit: int = 4
@export var projectile_hits_by_level: Array[int] = [5, 6, 7, 8, 10, 11, 12]

func get_projectile_hit_override(current_hits: int) -> int:
	return max(max(1, current_hits), _get_level_projectile_hits())

func get_pierce_damage_gain_per_hit() -> int:
	return max(0, pierce_damage_gain_per_hit)

func _get_level_projectile_hits() -> int:
	if projectile_hits_by_level.is_empty():
		return 1
	var weapon_level := 1
	if weapon != null and is_instance_valid(weapon):
		weapon_level = int(weapon.level)
	var index := clampi(weapon_level - 1, 0, projectile_hits_by_level.size() - 1)
	return max(1, int(projectile_hits_by_level[index]))
