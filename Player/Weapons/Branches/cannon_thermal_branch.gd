extends WeaponBranchBehavior
class_name CannonThermalBranch

@export var heat_accumulation: float = 35.0
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 15.0
@export var heat_damage_bonus_at_full_heat: float = 0.8

const RUNTIME_TRAIT_HEAT: StringName = CombatTrait.HEAT
const RUNTIME_TRAIT_FIRE: StringName = CombatTrait.FIRE

func on_weapon_ready() -> void:
	_apply_runtime_traits(true)
	_apply_heat_params()

func on_level_applied(_level: int) -> void:
	_apply_heat_params()

func on_removed() -> void:
	_apply_runtime_traits(false)

func get_projectile_damage_multiplier() -> float:
	if weapon == null or not is_instance_valid(weapon):
		return 1.0
	if not weapon.has_method("get_heat_ratio"):
		return 1.0
	var heat_ratio := clampf(float(weapon.call("get_heat_ratio")), 0.0, 1.0)
	return 1.0 + heat_ratio * maxf(heat_damage_bonus_at_full_heat, 0.0)

func get_damage_type_override() -> StringName:
	return Attack.TYPE_FIRE

func _apply_runtime_traits(enable: bool) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if enable:
		if weapon.has_method("add_runtime_weapon_trait"):
			weapon.call("add_runtime_weapon_trait", RUNTIME_TRAIT_HEAT)
			weapon.call("add_runtime_weapon_trait", RUNTIME_TRAIT_FIRE)
	else:
		if weapon.has_method("remove_runtime_weapon_trait"):
			weapon.call("remove_runtime_weapon_trait", RUNTIME_TRAIT_HEAT)
			weapon.call("remove_runtime_weapon_trait", RUNTIME_TRAIT_FIRE)

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
