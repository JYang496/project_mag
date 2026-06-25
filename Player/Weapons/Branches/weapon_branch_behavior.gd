extends Node
class_name WeaponBranchBehavior

var weapon: Weapon

func setup(target_weapon: Weapon) -> void:
	weapon = target_weapon
	_apply_runtime_classification()

func on_weapon_ready() -> void:
	pass

func on_level_applied(_level: int) -> void:
	pass

func on_weapon_shot(_base_direction: Vector2) -> void:
	pass

func on_target_hit(_target: Node) -> void:
	pass

func on_removed() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var source_id := get_runtime_classification_source_id()
	weapon.clear_runtime_weapon_traits(source_id)
	weapon.clear_runtime_delivery_types(source_id)
	weapon.clear_runtime_weapon_capabilities(source_id)

func get_runtime_classification_source_id() -> StringName:
	return StringName("branch:%s" % str(get_meta("branch_id", name)))

func get_added_weapon_traits() -> Array[StringName]:
	return []

func get_suppressed_weapon_traits() -> Array[StringName]:
	return []

func get_added_delivery_types() -> Array[StringName]:
	return []

func get_suppressed_delivery_types() -> Array[StringName]:
	return []

func get_added_weapon_capabilities() -> Array[StringName]:
	return []

func _apply_runtime_classification() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var source_id := get_runtime_classification_source_id()
	for trait_name in get_added_weapon_traits():
		weapon.add_runtime_weapon_trait(source_id, trait_name)
	for trait_name in get_suppressed_weapon_traits():
		weapon.suppress_runtime_weapon_trait(source_id, trait_name)
	for delivery_type in get_added_delivery_types():
		weapon.add_runtime_delivery_type(source_id, delivery_type)
	for delivery_type in get_suppressed_delivery_types():
		weapon.suppress_runtime_delivery_type(source_id, delivery_type)
	for capability in get_added_weapon_capabilities():
		weapon.add_runtime_weapon_capability(source_id, capability)

func get_shot_directions(_base_direction: Vector2, _shot_count: int = -1) -> Array[Vector2]:
	return [_base_direction]

func get_additional_shot_directions(_base_direction: Vector2, _shot_count: int = -1) -> Array[Vector2]:
	return []

static func build_centered_spread_directions(base_direction: Vector2, shot_count: int, spread_step_rad: float) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	var count := maxi(1, shot_count)
	var normalized_base := base_direction.normalized()
	if normalized_base == Vector2.ZERO:
		normalized_base = Vector2.UP
	dirs.append(normalized_base)
	var offset_distance := 1
	while dirs.size() < count:
		dirs.append(normalized_base.rotated(-spread_step_rad * float(offset_distance)).normalized())
		if dirs.size() >= count:
			break
		dirs.append(normalized_base.rotated(spread_step_rad * float(offset_distance)).normalized())
		offset_distance += 1
	return dirs

func get_cooldown_multiplier() -> float:
	return 1.0

func get_projectile_damage_multiplier() -> float:
	return 1.0

func get_damage_type_override() -> StringName:
	return Attack.TYPE_PHYSICAL

func get_damage_multiplier() -> float:
	return 1.0

func get_attack_range_multiplier() -> float:
	return 1.0

func get_dash_speed_multiplier() -> float:
	return 1.0

func get_return_speed_multiplier() -> float:
	return 1.0

func get_cone_or_spread_multiplier() -> float:
	return 1.0

func get_cone_half_angle_multiplier() -> float:
	return 1.0

func get_projectile_count_override(current_count: int) -> int:
	return max(1, current_count)

func get_projectile_hit_override(current_hits: int) -> int:
	return max(1, current_hits)

func get_extra_heat_shot_multiplier() -> float:
	return 1.0

func get_orbit_spin_speed_multiplier() -> float:
	return 1.0

func get_pierce_damage_gain_per_hit() -> int:
	return 0

func get_max_pierce_damage_stacks() -> int:
	return 0

func get_heat_spend_max_amount(base_max_amount: float) -> float:
	return maxf(base_max_amount, 0.0)

func disables_primary_fire() -> bool:
	return false

func get_projectile_trail_config() -> Dictionary:
	return {}

func modify_explosion_config(_config: ExplosionEffectConfig) -> void:
	pass

func get_charged_turn_speed_multiplier() -> float:
	return 1.0

func get_charged_beam_profiles(base_profile: Dictionary) -> Array[Dictionary]:
	return [base_profile]

func on_charged_beam_hit(_target: Node, _beam_profile: Dictionary, _hit_damage: int) -> void:
	pass

func get_laser_beam_profiles(base_profile: Dictionary) -> Array[Dictionary]:
	return [base_profile]

func apply_laser_tracking_to_profile(base_profile: Dictionary) -> Dictionary:
	return base_profile

func get_laser_focus_duration_sec() -> float:
	return 0.0

func get_laser_focus_damage_multiplier() -> float:
	return 1.0

func get_laser_focus_width_multiplier() -> float:
	return 1.0

func on_chainsaw_target_hit(_target: Node, _projectile: Projectile) -> void:
	pass

func on_passive_event(_event_name: StringName, _detail: Dictionary) -> void:
	pass
