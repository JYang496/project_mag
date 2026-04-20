extends Node
class_name WeaponBranchBehavior

var weapon: Weapon

func setup(target_weapon: Weapon) -> void:
	weapon = target_weapon

func on_weapon_ready() -> void:
	pass

func on_level_applied(_level: int) -> void:
	pass

func on_weapon_shot(_base_direction: Vector2) -> void:
	pass

func on_target_hit(_target: Node) -> void:
	pass

func on_removed() -> void:
	pass

func get_shot_directions(_base_direction: Vector2, _shot_count: int = 1) -> Array[Vector2]:
	return [_base_direction]

func get_additional_shot_directions(_base_direction: Vector2, _shot_count: int = 1) -> Array[Vector2]:
	return []

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

func get_extra_heat_shot_multiplier() -> float:
	return 1.0

func get_orbit_spin_speed_multiplier() -> float:
	return 1.0

func get_pierce_damage_gain_per_hit() -> int:
	return 0

func get_max_pierce_damage_stacks() -> int:
	return 0

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

func on_chainsaw_target_hit(_target: Node, _projectile: Projectile) -> void:
	pass

func on_passive_event(_event_name: StringName, _detail: Dictionary) -> void:
	pass
