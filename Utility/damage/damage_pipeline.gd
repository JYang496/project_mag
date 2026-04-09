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
const ENERGY_EXECUTE_DAMAGE_MULT: float = 1.2

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
	var hp := profile.read_hp()
	if _has_energy_damage_breakpoint(state, hp):
		incoming_damage = max(1, int(round(float(incoming_damage) * ENERGY_EXECUTE_DAMAGE_MULT)))
	if incoming_damage <= 0:
		_save_state(target, state)
		return result

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
				_record_energy_damage_on_hit(state, incoming_damage)

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
			var scorch_source_node: Variant = state.get("scorch_source_node", null)
			if scorch_source_node != null and is_instance_valid(scorch_source_node):
				dot_attack.source_node = scorch_source_node as Node
			else:
				dot_attack.source_node = null
				state["scorch_source_node"] = null
			var scorch_source_player: Variant = state.get("scorch_source_player", null)
			if scorch_source_player != null and is_instance_valid(scorch_source_player):
				dot_attack.source_player = scorch_source_player as Node
			else:
				dot_attack.source_player = null
				state["scorch_source_player"] = null
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
		or int(state.get("frost_stacks", 0)) > 0

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
		"energy_damage_recorded": 0,
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
	var current_per_stack_dot: int = int(state.get("scorch_dot_damage_per_stack", 1))
	state["scorch_dot_damage_per_stack"] = max(current_per_stack_dot, per_stack_dot)
	state["scorch_source_node"] = source_node
	state["scorch_source_player"] = source_player
	# Only refresh scorch duration when the new fire hit is at least as strong as
	# the currently active per-stack DOT value.
	if per_stack_dot >= current_per_stack_dot:
		state["scorch_expires_at_msec"] = now_msec + int(SCORCH_DURATION_SEC * 1000.0)

func _apply_frost_on_freeze_hit(state: Dictionary, profile: DamageProfile, now_msec: int) -> void:
	if int(state.get("frost_stacks", 0)) < FROST_MAX_STACKS and now_msec >= int(state.get("frost_next_stack_at_msec", 0)):
		state["frost_stacks"] = int(state.get("frost_stacks", 0)) + 1
		state["frost_next_stack_at_msec"] = now_msec + int(FROST_STACK_INTERVAL_SEC * 1000.0)
	var move_mul := clampf(1.0 - float(int(state.get("frost_stacks", 0))) * FROST_SLOW_PER_STACK, 0.05, 1.0)
	profile.call_apply_frost_slow(move_mul, FROST_DURATION_SEC)
	state["frost_expires_at_msec"] = now_msec + int(FROST_DURATION_SEC * 1000.0)

func _record_energy_damage_on_hit(state: Dictionary, energy_damage: int) -> void:
	if energy_damage <= 0:
		return
	state["energy_damage_recorded"] = max(0, int(state.get("energy_damage_recorded", 0))) + energy_damage

func _has_energy_damage_breakpoint(state: Dictionary, current_hp: int) -> bool:
	return int(state.get("energy_damage_recorded", 0)) > max(0, current_hp)
