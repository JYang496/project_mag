extends Node2D

const DAMAGE_PIPELINE_SCRIPT := preload("res://Utility/damage/damage_pipeline.gd")
const DAMAGE_PROFILE_SCRIPT := preload("res://Utility/damage/damage_profile.gd")

class MockTarget:
	extends Node
	var hp: int = 100
	var max_hp: int = 100
	var is_dead: bool = false
	var invuln_count: int = 0
	var slow_multiplier: float = 1.0

@onready var result_label: Label = $ResultLabel

var _pipeline: DamagePipeline
var _log_lines: PackedStringArray = []
var _failure_count: int = 0

func _ready() -> void:
	_pipeline = DAMAGE_PIPELINE_SCRIPT.new() as DamagePipeline
	await _run_all_tests()

func _run_all_tests() -> void:
	_test_player_dot_does_not_trigger_invuln()
	await _test_frost_stack_interval_and_cap()
	_test_energy_mark_burst_threshold()
	var status := "PASS" if _failure_count == 0 else "FAIL (%d)" % _failure_count
	_log("==== Damage Pipeline Test: %s ====" % status)
	result_label.text = "\n".join(_log_lines)

func _test_player_dot_does_not_trigger_invuln() -> void:
	var target := _new_target(200)
	var profile := _build_player_profile(target)
	var fire_attack := _build_attack(100, Attack.TYPE_FIRE)
	var hit_result := _pipeline.apply_incoming_damage(target, fire_attack, profile)
	_expect(hit_result.applied, "player fire hit should apply")
	_expect(target.invuln_count == 1, "player direct hit should trigger invuln once")
	_pipeline.process_periodic_effects(target, profile, 1.0)
	_expect(target.invuln_count == 1, "player DOT should not trigger invuln")

func _test_frost_stack_interval_and_cap() -> void:
	var target := _new_target(200)
	var profile := _build_enemy_profile(target)
	var freeze_attack := _build_attack(10, Attack.TYPE_FREEZE)
	_pipeline.apply_incoming_damage(target, freeze_attack, profile)
	var state: Dictionary = target.get_meta("_incoming_damage_state", {})
	_expect(int(state.get("frost_stacks", 0)) == 1, "first freeze hit should add 1 frost stack")
	_pipeline.apply_incoming_damage(target, freeze_attack, profile)
	state = target.get_meta("_incoming_damage_state", {})
	_expect(int(state.get("frost_stacks", 0)) == 1, "second immediate freeze should be interval-limited")
	var next_stack_at_msec: int = int(state.get("frost_next_stack_at_msec", 0))
	var now_msec: int = Time.get_ticks_msec()
	var wait_sec: float = maxf(0.0, float(next_stack_at_msec - now_msec) / 1000.0 + 0.2)
	await get_tree().create_timer(wait_sec).timeout
	_pipeline.apply_incoming_damage(target, freeze_attack, profile)
	state = target.get_meta("_incoming_damage_state", {})
	if int(state.get("frost_stacks", 0)) >= 2:
		_expect(true, "freeze stack should increase after interval")
		return
	var started_msec: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec < 1200:
		await get_tree().create_timer(0.05).timeout
		_pipeline.apply_incoming_damage(target, freeze_attack, profile)
		state = target.get_meta("_incoming_damage_state", {})
		if int(state.get("frost_stacks", 0)) >= 2:
			_expect(true, "freeze stack should increase after interval")
			return
	_expect(false, "freeze stack should increase after interval")
	_log("frost debug state: now=%d next=%d expires=%d stacks=%d" % [
		Time.get_ticks_msec(),
		int(state.get("frost_next_stack_at_msec", 0)),
		int(state.get("frost_expires_at_msec", 0)),
		int(state.get("frost_stacks", 0))
	])

func _test_energy_mark_burst_threshold() -> void:
	var target := _new_target(100)
	var profile := _build_enemy_profile(target)
	var energy_attack := _build_attack(50, Attack.TYPE_ENERGY)
	_pipeline.apply_incoming_damage(target, energy_attack, profile)
	var state: Dictionary = target.get_meta("_incoming_damage_state", {})
	_expect(int(state.get("energy_mark_value", 0)) == 5, "energy mark should record 10% of damage")
	var physical_attack := _build_attack(46, Attack.TYPE_PHYSICAL)
	var result := _pipeline.apply_incoming_damage(target, physical_attack, profile)
	_expect(result.applied, "threshold hit should apply base damage")
	_expect(target.hp <= 0, "energy mark burst should trigger when hp falls below mark")

func _new_target(max_hp: int) -> MockTarget:
	var target := MockTarget.new()
	target.max_hp = max_hp
	target.hp = max_hp
	add_child(target)
	return target

func _build_attack(amount: int, damage_type: StringName) -> Attack:
	var attack := Attack.new()
	attack.damage = amount
	attack.damage_type = damage_type
	return attack

func _build_player_profile(target: MockTarget) -> DamageProfile:
	var profile := DAMAGE_PROFILE_SCRIPT.new() as DamageProfile
	profile.profile_id = &"player"
	profile.use_damage_reduction = true
	profile.use_armor = true
	profile.use_invuln = true
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
	profile.on_trigger_invuln = func() -> void: target.invuln_count += 1
	profile.on_apply_frost_slow = func(move_mul: float, _duration: float) -> void: target.slow_multiplier = move_mul
	profile.on_clear_frost_slow = func() -> void: target.slow_multiplier = 1.0
	return profile

func _build_enemy_profile(target: MockTarget) -> DamageProfile:
	var profile := _build_player_profile(target)
	profile.profile_id = &"enemy"
	profile.use_invuln = false
	profile.on_trigger_invuln = Callable()
	return profile

func _expect(condition: bool, message: String) -> void:
	if condition:
		_log("[PASS] %s" % message)
		return
	_failure_count += 1
	_log("[FAIL] %s" % message)

func _log(message: String) -> void:
	print(message)
	_log_lines.append(message)
