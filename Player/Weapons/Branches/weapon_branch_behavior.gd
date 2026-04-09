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

func get_projectile_trail_config() -> Dictionary:
	return {}
