extends WeaponBranchBehavior
class_name CannonThermalBranch

@export var heat_accumulation: float = 22.0
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 15.0
@export_range(0.0, 1.0, 0.05) var empowered_heat_ratio: float = 0.5
@export var empowered_damage_multiplier: float = 1.5

func on_weapon_ready() -> void:
	_apply_heat_params()

func on_level_applied(_level: int) -> void:
	_apply_heat_params()

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.HEAT, WeaponTrait.FIRE]

func get_damage_type_override() -> StringName:
	return Attack.TYPE_FIRE if _is_empowered() else Attack.TYPE_PHYSICAL

func get_projectile_damage_multiplier() -> float:
	if weapon == null or not is_instance_valid(weapon):
		return 1.0
	if not weapon.has_method("get_heat_ratio"):
		return 1.0
	return maxf(empowered_damage_multiplier, 1.0) if _is_empowered() else 1.0

func consume_heat_spend_multiplier() -> float:
	return 1.0

func _is_empowered() -> bool:
	return weapon != null and is_instance_valid(weapon) \
		and weapon.has_method("get_heat_ratio") \
		and float(weapon.call("get_heat_ratio")) >= clampf(empowered_heat_ratio, 0.0, 1.0)

func _apply_heat_params() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if weapon.has_method("configure_heat"):
		weapon.call(
			"configure_heat",
			maxf(heat_accumulation, 0.0),
			maxf(max_heat, 1.0),
			maxf(heat_cooldown_rate, 0.0)
		)
