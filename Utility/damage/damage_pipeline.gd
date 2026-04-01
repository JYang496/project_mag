extends RefCounted
class_name DamagePipeline

const DAMAGE_STATE_META := &"_incoming_damage_state"

const SCORCH_DURATION_SEC: float = 6.0
const SCORCH_DOT_RATIO_PER_STACK: float = 0.10
const SCORCH_DOT_TICK_SEC: float = 1.0
const FROST_DURATION_SEC: float = 6.0
const FROST_SLOW_PER_STACK: float = 0.04
const FROST_STACK_INTERVAL_SEC: float = 0.6
const FROST_MAX_STACKS: int = 5
const ENERGY_MARK_RATIO: float = 0.10
const ENERGY_MARK_DURATION_SEC: float = 6.0
const ENERGY_MARK_MAX_HP_RATIO: float = 0.40
const ENERGY_MARK_TRIGGER_COOLDOWN_SEC: float = 2.0

func apply_incoming_damage(target: Node, attack: Attack, profile: DamageProfile, is_periodic: bool = false) -> DamageResult:
	var result := DamageResult.new()
	result.is_periodic = is_periodic
	if target == null or not is_instance_valid(target) or attack == null or profile == null:
		return result

	if profile.read_is_dead():
		return result

	var normalized_type := Attack.normalize_damage_type(attack.damage_type)
	var state := _get_or_create_state(target, profile)
	var now_msec := Time.get_ticks_msec()
	_clear_expired_states(state, profile, now_msec)

	var incoming_damage: int = max(0, int(attack.damage))
	incoming_damage = int(round(float(incoming_damage) * profile.read_damage_reduction()))
	incoming_damage = int(round(float(incoming_damage) * profile.read_damage_taken_multiplier()))
	incoming_damage = max(0, incoming_damage - profile.read_armor())
	if incoming_damage <= 0:
		_save_state(target, state)
		return result

	var hp := profile.read_hp()
	hp -= incoming_damage
	profile.write_hp(hp)

	result.applied = true
	result.final_damage = incoming_damage
	result.damage_type = normalized_type

	if hp <= 0:
		profile.write_is_dead(true)
		result.killed = true
		_save_state(target, state)
		profile.call_on_death(attack)
		return result

	if not is_periodic:
		match normalized_type:
			Attack.TYPE_FIRE:
				if not bool(state.get("processing_scorch_dot", false)):
					_apply_scorch_on_fire_hit(state, profile, incoming_damage, attack.source_node, attack.source_player, now_msec)
			Attack.TYPE_FREEZE:
				_apply_frost_on_freeze_hit(state, profile, now_msec)
			Attack.TYPE_ENERGY:
				if not bool(state.get("processing_energy_burst", false)):
					_apply_energy_mark_on_energy_hit(state, profile, incoming_damage, now_msec)

	if _try_trigger_energy_mark_burst(target, state, profile, attack, now_msec):
		result.triggered_energy_burst = true

	if profile.use_invuln and not (is_periodic and profile.dot_bypasses_invuln):
		profile.call_trigger_invuln()
		result.triggered_invuln = true

	_save_state(target, state)
	return result

func process_periodic_effects(target: Node, profile: DamageProfile, delta_sec: float) -> Array[DamageResult]:
	var results: Array[DamageResult] = []
	if target == null or not is_instance_valid(target) or profile == null:
		return results
	if profile.read_is_dead():
		return results
	var state := _get_or_create_state(target, profile)
	var now_msec := Time.get_ticks_msec()
	_clear_expired_states(state, profile, now_msec)

	if int(state.get("scorch_stacks", 0)) > 0:
		state["scorch_dot_accum_sec"] = float(state.get("scorch_dot_accum_sec", 0.0)) + maxf(delta_sec, 0.0)
		while float(state.get("scorch_dot_accum_sec", 0.0)) >= SCORCH_DOT_TICK_SEC and int(state.get("scorch_stacks", 0)) > 0 and not profile.read_is_dead():
			state["scorch_dot_accum_sec"] = float(state.get("scorch_dot_accum_sec", 0.0)) - SCORCH_DOT_TICK_SEC
			var dot_damage: int = max(1, int(state.get("scorch_stacks", 0)) * int(state.get("scorch_dot_damage_per_stack", 1)))
			var dot_attack := Attack.new()
			dot_attack.damage = dot_damage
			dot_attack.damage_type = Attack.TYPE_FIRE
			dot_attack.source_node = state.get("scorch_source_node", null)
			dot_attack.source_player = state.get("scorch_source_player", null)
			state["processing_scorch_dot"] = true
			var dot_result := apply_incoming_damage(target, dot_attack, profile, true)
			state["processing_scorch_dot"] = false
			if dot_result.applied:
				results.append(dot_result)
	else:
		state["scorch_dot_accum_sec"] = 0.0

	_save_state(target, state)
	return results

func has_active_effects(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_meta(DAMAGE_STATE_META):
		return false
	var state: Dictionary = target.get_meta(DAMAGE_STATE_META, {})
	return int(state.get("scorch_stacks", 0)) > 0 \
		or int(state.get("frost_stacks", 0)) > 0 \
		or int(state.get("energy_mark_value", 0)) > 0

func _get_or_create_state(target: Node, profile: DamageProfile) -> Dictionary:
	if target.has_meta(DAMAGE_STATE_META):
		var existing: Variant = target.get_meta(DAMAGE_STATE_META)
		if existing is Dictionary:
			return existing
	var state := {
		"scorch_stacks": 0,
		"scorch_expires_at_msec": 0,
		"scorch_dot_damage_per_stack": 1,
		"scorch_dot_accum_sec": 0.0,
		"scorch_source_node": null,
		"scorch_source_player": null,
		"processing_scorch_dot": false,
		"frost_stacks": 0,
		"frost_expires_at_msec": 0,
		"frost_next_stack_at_msec": 0,
		"energy_mark_value": 0,
		"energy_mark_expires_at_msec": 0,
		"energy_mark_trigger_ready_at_msec": 0,
		"processing_energy_burst": false,
		"scorch_max_hp": max(1, profile.read_max_hp()),
	}
	target.set_meta(DAMAGE_STATE_META, state)
	return state

func _save_state(target: Node, state: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.set_meta(DAMAGE_STATE_META, state)

func _clear_expired_states(state: Dictionary, profile: DamageProfile, now_msec: int) -> void:
	if int(state.get("scorch_stacks", 0)) <= 0:
		state["scorch_stacks"] = 0
		state["scorch_expires_at_msec"] = 0
		state["scorch_dot_damage_per_stack"] = 1
		state["scorch_dot_accum_sec"] = 0.0
		state["scorch_source_node"] = null
		state["scorch_source_player"] = null
	elif now_msec >= int(state.get("scorch_expires_at_msec", 0)):
		state["scorch_stacks"] = 0
		state["scorch_expires_at_msec"] = 0
		state["scorch_dot_damage_per_stack"] = 1
		state["scorch_dot_accum_sec"] = 0.0
		state["scorch_source_node"] = null
		state["scorch_source_player"] = null

	if int(state.get("frost_stacks", 0)) <= 0:
		state["frost_stacks"] = 0
		state["frost_expires_at_msec"] = 0
		state["frost_next_stack_at_msec"] = 0
		profile.call_clear_frost_slow()
	elif now_msec >= int(state.get("frost_expires_at_msec", 0)):
		state["frost_stacks"] = 0
		state["frost_expires_at_msec"] = 0
		state["frost_next_stack_at_msec"] = 0
		profile.call_clear_frost_slow()

	if int(state.get("energy_mark_value", 0)) <= 0:
		state["energy_mark_value"] = 0
		state["energy_mark_expires_at_msec"] = 0
	elif now_msec >= int(state.get("energy_mark_expires_at_msec", 0)):
		state["energy_mark_value"] = 0
		state["energy_mark_expires_at_msec"] = 0

func _apply_scorch_on_fire_hit(state: Dictionary, profile: DamageProfile, fire_damage: int, source_node: Node, source_player: Node, now_msec: int) -> void:
	var max_hp: int = max(1, int(state.get("scorch_max_hp", profile.read_max_hp())))
	var hp_ratio := clampf(float(max(profile.read_hp(), 0)) / float(max_hp), 0.0, 1.0)
	var stack_cap := 1
	if hp_ratio <= 0.5:
		stack_cap = 3
	elif hp_ratio <= 0.75:
		stack_cap = 2
	if int(state.get("scorch_stacks", 0)) < stack_cap:
		state["scorch_stacks"] = int(state.get("scorch_stacks", 0)) + 1
	var per_stack_dot: int = max(1, int(round(float(max(1, fire_damage)) * SCORCH_DOT_RATIO_PER_STACK)))
	state["scorch_dot_damage_per_stack"] = max(int(state.get("scorch_dot_damage_per_stack", 1)), per_stack_dot)
	state["scorch_source_node"] = source_node
	state["scorch_source_player"] = source_player
	state["scorch_expires_at_msec"] = now_msec + int(SCORCH_DURATION_SEC * 1000.0)

func _apply_frost_on_freeze_hit(state: Dictionary, profile: DamageProfile, now_msec: int) -> void:
	if int(state.get("frost_stacks", 0)) < FROST_MAX_STACKS and now_msec >= int(state.get("frost_next_stack_at_msec", 0)):
		state["frost_stacks"] = int(state.get("frost_stacks", 0)) + 1
		state["frost_next_stack_at_msec"] = now_msec + int(FROST_STACK_INTERVAL_SEC * 1000.0)
	var move_mul := clampf(1.0 - float(int(state.get("frost_stacks", 0))) * FROST_SLOW_PER_STACK, 0.05, 1.0)
	profile.call_apply_frost_slow(move_mul, FROST_DURATION_SEC)
	state["frost_expires_at_msec"] = now_msec + int(FROST_DURATION_SEC * 1000.0)

func _apply_energy_mark_on_energy_hit(state: Dictionary, profile: DamageProfile, energy_damage: int, now_msec: int) -> void:
	var gained_mark: int = max(0, int(round(float(max(0, energy_damage)) * ENERGY_MARK_RATIO)))
	if gained_mark <= 0:
		return
	var mark_cap: int = max(1, int(round(float(profile.read_max_hp()) * ENERGY_MARK_MAX_HP_RATIO)))
	state["energy_mark_value"] = mini(mark_cap, int(state.get("energy_mark_value", 0)) + gained_mark)
	state["energy_mark_expires_at_msec"] = now_msec + int(ENERGY_MARK_DURATION_SEC * 1000.0)

func _try_trigger_energy_mark_burst(target: Node, state: Dictionary, profile: DamageProfile, reference_attack: Attack, now_msec: int) -> bool:
	if int(state.get("energy_mark_value", 0)) <= 0:
		return false
	if now_msec < int(state.get("energy_mark_trigger_ready_at_msec", 0)):
		return false
	if profile.read_hp() >= int(state.get("energy_mark_value", 0)):
		return false
	var burst_damage := int(state.get("energy_mark_value", 0))
	state["energy_mark_value"] = 0
	state["energy_mark_expires_at_msec"] = 0
	state["energy_mark_trigger_ready_at_msec"] = now_msec + int(ENERGY_MARK_TRIGGER_COOLDOWN_SEC * 1000.0)
	if burst_damage <= 0:
		return false
	var burst_attack := Attack.new()
	burst_attack.damage = burst_damage
	burst_attack.damage_type = Attack.TYPE_ENERGY
	if reference_attack != null:
		burst_attack.source_node = reference_attack.source_node
		burst_attack.source_player = reference_attack.source_player
	state["processing_energy_burst"] = true
	apply_incoming_damage(target, burst_attack, profile, false)
	state["processing_energy_burst"] = false
	return true
