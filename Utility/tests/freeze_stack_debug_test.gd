extends Node2D

const DAMAGE_PIPELINE_SCRIPT := preload("res://Utility/damage/damage_pipeline.gd")
const DAMAGE_PROFILE_SCRIPT := preload("res://Utility/damage/damage_profile.gd")

class MockTarget:
	extends Node
	var hp: int = 200
	var max_hp: int = 200
	var is_dead: bool = false
	var slow_multiplier: float = 1.0

@onready var result_label: Label = $ResultLabel

var _pipeline: DamagePipeline
var _target: MockTarget
var _profile: DamageProfile
var _freeze_attack: Attack
var _logs: PackedStringArray = []

func _ready() -> void:
	_pipeline = DAMAGE_PIPELINE_SCRIPT.new() as DamagePipeline
	_target = MockTarget.new()
	add_child(_target)
	_profile = _build_enemy_profile(_target)
	_freeze_attack = _build_attack(10, Attack.TYPE_FREEZE)
	await _run_debug_test()
	result_label.text = "\n".join(_logs)

func _run_debug_test() -> void:
	_log("== Freeze Stack Debug Test ==")
	_apply_and_log("hit#1")
	_apply_and_log("hit#2 immediate")

	var state: Dictionary = _target.get_meta("_incoming_damage_state", {})
	var next_msec: int = int(state.get("frost_next_stack_at_msec", 0))
	var now_msec: int = Time.get_ticks_msec()
	var wait_sec: float = maxf(0.0, float(next_msec - now_msec) / 1000.0 + 0.05)
	_log("wait to next stack: now=%d next=%d wait=%.3f" % [now_msec, next_msec, wait_sec])
	await get_tree().create_timer(wait_sec).timeout

	_apply_and_log("hit#3 after precise wait")
	state = _target.get_meta("_incoming_damage_state", {})
	if int(state.get("frost_stacks", 0)) >= 2:
		_log("[PASS] frost stack increased to %d" % int(state.get("frost_stacks", 0)))
		return

	_log("stack still not increased; start probing every 0.05s for 2s")
	var start_msec: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 2000:
		await get_tree().create_timer(0.05).timeout
		_apply_and_log("probe")
		state = _target.get_meta("_incoming_damage_state", {})
		if int(state.get("frost_stacks", 0)) >= 2:
			_log("[PASS] frost stack eventually increased to %d" % int(state.get("frost_stacks", 0)))
			return

	state = _target.get_meta("_incoming_damage_state", {})
	_log("[FAIL] frost stack never reached 2; final state=%s" % str(state))

func _apply_and_log(tag: String) -> void:
	var before: Dictionary = _target.get_meta("_incoming_damage_state", {}).duplicate(true)
	_pipeline.apply_incoming_damage(_target, _freeze_attack, _profile)
	var after: Dictionary = _target.get_meta("_incoming_damage_state", {}).duplicate(true)
	_log("%s | now=%d | before(stacks=%d,next=%d,exp=%d) -> after(stacks=%d,next=%d,exp=%d)" % [
		tag,
		Time.get_ticks_msec(),
		int(before.get("frost_stacks", 0)),
		int(before.get("frost_next_stack_at_msec", 0)),
		int(before.get("frost_expires_at_msec", 0)),
		int(after.get("frost_stacks", 0)),
		int(after.get("frost_next_stack_at_msec", 0)),
		int(after.get("frost_expires_at_msec", 0)),
	])

func _build_attack(amount: int, damage_type: StringName) -> Attack:
	var attack := Attack.new()
	attack.damage = amount
	attack.damage_type = damage_type
	return attack

func _build_enemy_profile(target: MockTarget) -> DamageProfile:
	var profile := DAMAGE_PROFILE_SCRIPT.new() as DamageProfile
	profile.profile_id = &"enemy"
	profile.use_damage_reduction = true
	profile.use_armor = true
	profile.use_invuln = false
	profile.dot_bypasses_invuln = true
	profile.get_hp = func() -> int: return target.hp
	profile.set_hp = func(value: int) -> void: target.hp = value
	profile.get_max_hp = func() -> int: return target.max_hp
	profile.get_armor = func() -> int: return 0
	profile.get_damage_reduction = func() -> float: return 1.0
	profile.get_damage_taken_multiplier = func() -> float: return 1.0
	profile.get_is_dead = func() -> bool: return target.is_dead
	profile.set_is_dead = func(value: bool) -> void: target.is_dead = value
	profile.on_death = func(_attack: Attack) -> void: target.is_dead = true
	profile.on_apply_frost_slow = func(move_mul: float, _duration: float) -> void: target.slow_multiplier = move_mul
	profile.on_clear_frost_slow = func() -> void: target.slow_multiplier = 1.0
	return profile

func _log(message: String) -> void:
	print(message)
	_logs.append(message)
