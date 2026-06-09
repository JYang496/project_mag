extends RefCounted
class_name WeaponSpreadModel

var weapon: Node2D
var _external_spread_mul_modifiers: Dictionary = {}

func setup(source_weapon: Node2D) -> void:
	weapon = source_weapon

func set_external_spread_multiplier(multiplier: float) -> void:
	var source_id := StringName("ranger_spread_%s" % str(weapon.get_instance_id()))
	if is_equal_approx(multiplier, 1.0):
		remove_external_spread_mul(source_id)
	else:
		apply_external_spread_mul(source_id, multiplier)

func apply_external_spread_mul(source_id: StringName, multiplier: float) -> void:
	if source_id == StringName():
		return
	var clamped_mul := clampf(multiplier, 0.01, 10.0)
	var previous_mul := float(_external_spread_mul_modifiers.get(source_id, 1.0))
	if _external_spread_mul_modifiers.has(source_id) and is_equal_approx(previous_mul, clamped_mul):
		return
	_external_spread_mul_modifiers[source_id] = clamped_mul
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("notify_weapon_status_change"):
		PlayerData.player.call("notify_weapon_status_change", &"spread_down" if clamped_mul < 1.0 else &"spread_up", source_id, true)

func remove_external_spread_mul(source_id: StringName) -> void:
	if not _external_spread_mul_modifiers.has(source_id):
		return
	var previous_mul := float(_external_spread_mul_modifiers.get(source_id, 1.0))
	_external_spread_mul_modifiers.erase(source_id)
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("notify_weapon_status_change"):
		PlayerData.player.call("notify_weapon_status_change", &"spread_down" if previous_mul < 1.0 else &"spread_up", source_id, false)

func get_external_spread_multiplier() -> float:
	var total := 1.0
	for mul in _external_spread_mul_modifiers.values():
		total *= float(mul)
	return clampf(total, 0.01, 20.0)

func apply_distance_based_spread(direction: Vector2, shot_distance: float) -> Vector2:
	if direction == Vector2.ZERO:
		return direction
	var normalized_dir := direction.normalized()
	if not bool(weapon.get("spread_enabled")):
		return normalized_dir
	var spread_info := build_spread_runtime(shot_distance)
	if randf() > float(spread_info["miss_chance"]):
		return normalized_dir
	var base_target: Vector2 = weapon.global_position + normalized_dir * maxf(shot_distance, 1.0)
	var spread_target: Vector2 = sample_spread_target(base_target, float(spread_info["radius"]))
	var spreaded: Vector2 = weapon.global_position.direction_to(spread_target).normalized()
	if spreaded == Vector2.ZERO:
		return normalized_dir
	return spreaded

func apply_distance_spread_to_target(direction: Vector2, target_position: Vector2) -> Vector2:
	var shot_distance: float = weapon.global_position.distance_to(target_position)
	if direction == Vector2.ZERO:
		return direction
	var normalized_dir := direction.normalized()
	if not bool(weapon.get("spread_enabled")):
		return normalized_dir
	var spread_info := build_spread_runtime(shot_distance)
	if randf() > float(spread_info["miss_chance"]):
		return normalized_dir
	var spread_target: Vector2 = sample_spread_target(target_position, float(spread_info["radius"]))
	var spreaded: Vector2 = weapon.global_position.direction_to(spread_target).normalized()
	if spreaded == Vector2.ZERO:
		return normalized_dir
	return spreaded

func build_spread_runtime(shot_distance: float) -> Dictionary:
	var distance_ratio := get_spread_distance_ratio(shot_distance)
	if distance_ratio <= 0.0 and shot_distance <= maxf(float(weapon.get("spread_no_falloff_distance")), 0.0):
		return {"miss_chance": 0.0, "radius": 0.0}
	var miss_chance := lerpf(
		clampf(float(weapon.get("spread_close_range_miss_chance")), 0.0, 1.0),
		clampf(float(weapon.get("spread_long_range_miss_chance")), 0.0, 1.0),
		distance_ratio
	)
	var spread_mul := clampf(get_external_spread_multiplier(), 0.01, 20.0)
	var radius := lerpf(maxf(float(weapon.get("spread_min_radius")), 0.0), maxf(float(weapon.get("spread_max_radius")), 0.0), distance_ratio) * spread_mul
	return {"miss_chance": miss_chance, "radius": maxf(radius, 0.0)}

func sample_spread_target(base_target: Vector2, radius: float) -> Vector2:
	if radius <= 0.0:
		return base_target
	var theta := randf() * TAU
	var r := sqrt(randf()) * radius
	return base_target + Vector2(cos(theta), sin(theta)) * r

func get_spread_preview_radius_for_target(target_position: Vector2) -> float:
	var info := get_spread_preview_info_for_target(target_position)
	return maxf(float(info.get("max_radius", 0.0)), 0.0)

func get_spread_preview_info_for_target(target_position: Vector2) -> Dictionary:
	if target_position == Vector2.ZERO and weapon.global_position == Vector2.ZERO:
		return {
			"enabled": bool(weapon.get("spread_enabled")),
			"miss_chance": 0.0,
			"max_radius": 0.0,
			"distance_ratio": 0.0,
			"shot_distance": 0.0,
		}
	var shot_distance: float = weapon.global_position.distance_to(target_position)
	var distance_ratio := get_spread_distance_ratio(shot_distance)
	var no_falloff_active: bool = distance_ratio <= 0.0 and shot_distance <= maxf(float(weapon.get("spread_no_falloff_distance")), 0.0)
	var miss_chance := 0.0
	if not no_falloff_active:
		miss_chance = lerpf(
			clampf(float(weapon.get("spread_close_range_miss_chance")), 0.0, 1.0),
			clampf(float(weapon.get("spread_long_range_miss_chance")), 0.0, 1.0),
			distance_ratio
		)
	var spread_mul := clampf(get_external_spread_multiplier(), 0.01, 20.0)
	var max_radius := 0.0
	if not no_falloff_active:
		max_radius = lerpf(maxf(float(weapon.get("spread_min_radius")), 0.0), maxf(float(weapon.get("spread_max_radius")), 0.0), distance_ratio) * spread_mul
	var enabled := bool(weapon.get("spread_enabled"))
	return {
		"enabled": enabled,
		"miss_chance": miss_chance if enabled else 0.0,
		"max_radius": maxf(max_radius, 0.0) if enabled else 0.0,
		"distance_ratio": distance_ratio,
		"shot_distance": shot_distance,
	}

func get_spread_distance_ratio(shot_distance: float) -> float:
	var near_distance := maxf(float(weapon.get("spread_no_falloff_distance")), 0.0)
	var full_distance := maxf(float(weapon.get("spread_full_distance")), 0.0)
	if full_distance <= near_distance:
		return 0.0
	var clamped_distance := maxf(shot_distance, 0.0)
	if clamped_distance <= near_distance:
		return 0.0
	return clampf((clamped_distance - near_distance) / (full_distance - near_distance), 0.0, 1.0)
