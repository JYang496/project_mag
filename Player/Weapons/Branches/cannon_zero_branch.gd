extends WeaponBranchBehavior
class_name CannonZeroBranch

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.ENERGY]

func get_suppressed_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.PHYSICAL]

@export var execute_burst_ratio: float = 0.20

func get_damage_type_override() -> StringName:
	return Attack.TYPE_ENERGY

func get_energy_hit_passive_id() -> StringName:
	return &"cannon_zero_energy_cycle"

func get_energy_hit_display_name() -> String:
	return "Zero Burst"

func on_energy_hit_cycle_triggered(target: Node, _data: DamageData, _result: DamageResult) -> Dictionary:
	if weapon == null or not is_instance_valid(weapon):
		return {}
	if target == null or not is_instance_valid(target):
		return {}
	if not target.is_in_group("enemies"):
		return {}
	var recorded_energy_damage := DamagePipeline.consume_recorded_energy_damage(target)
	if recorded_energy_damage <= 0:
		return {"effect": "zero_burst", "consumed_recorded_damage": 0, "burst_damage": 0}
	var burst_damage: int = max(1, int(round(float(recorded_energy_damage) * maxf(execute_burst_ratio, 0.0))))
	var burst_data: DamageData = DamageManager.build_damage_data(
		weapon,
		burst_damage,
		Attack.TYPE_ENERGY,
		{
			"amount": 0,
			"angle": Vector2.ZERO
		},
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.AREA
	)
	burst_data.suppress_reactive_effects = true
	var applied := DamageManager.apply_to_target(target, burst_data)
	if applied:
		var owner_player: Player = burst_data.source_player as Player
		if owner_player and is_instance_valid(owner_player):
			owner_player.apply_bonus_hit_if_needed(target)
	return {
		"effect": "zero_burst",
		"consumed_recorded_damage": recorded_energy_damage,
		"burst_damage": burst_damage if applied else 0,
	}
