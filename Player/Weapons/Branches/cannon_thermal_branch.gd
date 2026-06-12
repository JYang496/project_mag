extends WeaponBranchBehavior
class_name CannonThermalBranch

@export var heat_accumulation: float = 35.0
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 15.0
@export var heat_damage_bonus_at_full_heat: float = 0.8
@export var cannon_spend_heat_ratio_threshold: float = 0.5
@export var cannon_heat_spend_amount: float = 40.0
@export var cannon_heat_spend_damage_bonus: float = 0.35

func on_weapon_ready() -> void:
	_apply_heat_params()

func on_level_applied(_level: int) -> void:
	_apply_heat_params()

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.HEAT, WeaponTrait.FIRE]

func get_projectile_damage_multiplier() -> float:
	if weapon == null or not is_instance_valid(weapon):
		return 1.0
	if not weapon.has_method("get_heat_ratio"):
		return 1.0
	var heat_ratio := clampf(float(weapon.call("get_heat_ratio")), 0.0, 1.0)
	return 1.0 + heat_ratio * maxf(heat_damage_bonus_at_full_heat, 0.0)

func consume_heat_spend_multiplier() -> float:
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player):
		return 1.0
	if not player.has_method("get_total_heat_ratio"):
		return 1.0
	var shared_heat_ratio := clampf(float(player.call("get_total_heat_ratio")), 0.0, 1.0)
	if shared_heat_ratio < clampf(cannon_spend_heat_ratio_threshold, 0.0, 1.0):
		return 1.0
	var intended_cost := maxf(cannon_heat_spend_amount, 0.0)
	if intended_cost <= 0.0:
		return 1.0
	var effective_cost := intended_cost
	if player.has_method("get_heat_stabilized_cost_mul"):
		effective_cost *= clampf(float(player.call("get_heat_stabilized_cost_mul")), 0.0, 1.0)
	if not player.has_method("consume_shared_heat"):
		return 1.0
	var spent := float(player.call("consume_shared_heat", effective_cost))
	if spent <= 0.0:
		return 1.0
	var spent_ratio := clampf(spent / maxf(effective_cost, 0.001), 0.0, 1.0)
	var multiplier := 1.0 + maxf(cannon_heat_spend_damage_bonus, 0.0) * spent_ratio
	var heat_prepared_active := false
	if player.has_method("has_heat_prepared") and bool(player.call("has_heat_prepared")):
		heat_prepared_active = true
	if weapon != null and is_instance_valid(weapon) and weapon.has_method("emit_passive_trigger"):
		weapon.call("emit_passive_trigger", &"cannon_thermal_heat_spend", {
			"trigger": "shot",
			"shared_heat_ratio": shared_heat_ratio,
			"heat_spent": spent,
			"heat_cost": effective_cost,
			"spent_ratio": spent_ratio,
			"damage_multiplier": multiplier,
			"heat_prepared_active": heat_prepared_active,
		}, Weapon.PASSIVE_SCOPE_GLOBAL)
	return maxf(multiplier, 0.05)

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
