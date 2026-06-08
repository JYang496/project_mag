extends WeaponBranchBehavior
class_name LaserTrackingLensBranch

@export var max_lock_angle_deg: float = 10.0
@export var search_range: float = 1600.0

func apply_laser_tracking_to_profile(base_profile: Dictionary) -> Dictionary:
	var output := base_profile.duplicate(true)
	if weapon == null or not is_instance_valid(weapon):
		return output
	var origin := (weapon as Node2D).global_position
	var base_direction: Vector2 = output.get("direction", Vector2.RIGHT)
	base_direction = base_direction.normalized().rotated(deg_to_rad(float(output.get("angle_offset_deg", 0.0))))
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT
	var target := _find_tracking_target(origin, base_direction)
	if target == null:
		output["tracking_applied"] = false
		return output
	output["direction"] = origin.direction_to(target.global_position).normalized()
	output["angle_offset_deg"] = 0.0
	output["tracking_applied"] = true
	output["tracking_target"] = target
	output["beam_tag"] = "%s_tracking" % str(output.get("beam_tag", "main"))
	return output

func _find_tracking_target(origin: Vector2, base_direction: Vector2) -> Node2D:
	var tree := weapon.get_tree() if weapon != null and is_instance_valid(weapon) else null
	if tree == null:
		return null
	var max_angle := deg_to_rad(maxf(max_lock_angle_deg, 0.0))
	var max_distance := maxf(search_range, 1.0)
	var max_distance_sq := max_distance * max_distance
	var best: Node2D = null
	var best_distance_sq := INF
	for enemy_ref in WeaponModuleRuntimeUtils.get_enemy_candidates(tree):
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_enemy := enemy.global_position - origin
		var distance_sq := to_enemy.length_squared()
		if distance_sq <= 0.0 or distance_sq > max_distance_sq:
			continue
		var enemy_direction := to_enemy.normalized()
		if absf(base_direction.angle_to(enemy_direction)) > max_angle:
			continue
		if distance_sq >= best_distance_sq:
			continue
		best = enemy
		best_distance_sq = distance_sq
	return best
