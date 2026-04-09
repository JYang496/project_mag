extends WeaponBranchBehavior
class_name CannonZeroBranch

const DAMAGE_STATE_META := &"_incoming_damage_state"

@export var execute_burst_ratio: float = 0.20
@export var execute_trigger_cooldown_sec: float = 2.0

var _execute_ready_at_msec: Dictionary = {}

func on_removed() -> void:
	_execute_ready_at_msec.clear()

func get_damage_type_override() -> StringName:
	return Attack.TYPE_ENERGY

func on_target_hit(target: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	if not target.has_meta(DAMAGE_STATE_META):
		return
	var state_variant: Variant = target.get_meta(DAMAGE_STATE_META, {})
	if not (state_variant is Dictionary):
		return
	var state: Dictionary = state_variant
	var recorded_energy_damage: int = max(0, int(state.get("energy_damage_recorded", 0)))
	if recorded_energy_damage <= 0:
		return
	var hp_value: Variant = target.get("hp")
	if hp_value == null:
		return
	var target_hp: int = int(hp_value)
	if target_hp >= recorded_energy_damage:
		return
	var target_id: int = target.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var ready_msec: int = int(_execute_ready_at_msec.get(target_id, 0))
	if now_msec < ready_msec:
		return
	_execute_ready_at_msec[target_id] = now_msec + int(maxf(execute_trigger_cooldown_sec, 0.1) * 1000.0)
	var burst_damage: int = max(1, int(round(float(recorded_energy_damage) * maxf(execute_burst_ratio, 0.0))))
	var burst_data: DamageData = DamageManager.build_damage_data(
		weapon,
		burst_damage,
		Attack.TYPE_ENERGY,
		{
			"amount": 0,
			"angle": Vector2.ZERO
		}
	)
	if DamageManager.apply_to_target(target, burst_data):
		var owner_player: Player = burst_data.source_player as Player
		if owner_player and is_instance_valid(owner_player):
			owner_player.apply_bonus_hit_if_needed(target)
