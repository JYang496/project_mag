extends Node2D

const DAMAGE_PIPELINE_SCRIPT := preload("res://Utility/damage/damage_pipeline.gd")
const DAMAGE_PROFILE_SCRIPT := preload("res://Utility/damage/damage_profile.gd")
const CRYO_INFUSER_SCRIPT := preload("res://Player/Weapons/Modules/wmod_cryo_infuser_freeze.gd")
const SUBZERO_EXTENSION_SCRIPT := preload("res://Player/Weapons/Modules/wmod_subzero_extension_freeze.gd")
const BRITTLE_TRIGGER_SCRIPT := preload("res://Player/Weapons/Modules/wmod_brittle_trigger_freeze.gd")
const PERMAFROST_FIELD_SCRIPT := preload("res://Player/Weapons/Modules/wmod_permafrost_field_freeze.gd")

class MockTarget:
	extends Node2D
	var hp: int = 200
	var max_hp: int = 200
	var is_dead: bool = false
	var slow_multiplier: float = 1.0
	var pipeline: DamagePipeline
	var profile: DamageProfile

	func damaged(attack: Attack) -> void:
		if pipeline == null or profile == null:
			return
		pipeline.apply_incoming_damage(self, attack, profile)

	func apply_slow(move_multiplier: float, _duration: float) -> void:
		slow_multiplier = move_multiplier

@onready var result_label: Label = $ResultLabel

var _pipeline: DamagePipeline
var _logs: PackedStringArray = []
var _failure_count: int = 0

func _ready() -> void:
	_pipeline = DAMAGE_PIPELINE_SCRIPT.new() as DamagePipeline
	await _run_tests()
	result_label.text = "\n".join(_logs)

func _run_tests() -> void:
	await _test_freeze_stack_interval()
	_test_cryo_infuser_applies_freeze_damage()
	_test_subzero_extension_extends_frost()
	_test_brittle_trigger_icd()
	_test_permafrost_field_cap()
	var status: String = "PASS" if _failure_count == 0 else "FAIL (%d)" % _failure_count
	_log("==== Freeze Kit Test: %s ====" % status)

func _test_freeze_stack_interval() -> void:
	var target: MockTarget = _new_target(200)
	var profile: DamageProfile = _build_enemy_profile(target)
	var freeze_attack: Attack = _build_attack(10, Attack.TYPE_FREEZE)
	_pipeline.apply_incoming_damage(target, freeze_attack, profile)
	_pipeline.apply_incoming_damage(target, freeze_attack, profile)
	var state: Dictionary = target.get_meta("_incoming_damage_state", {})
	_expect(int(state.get("frost_stacks", 0)) == 1, "freeze immediate re-hit should be interval-limited")
	var next_stack_at_msec: int = int(state.get("frost_next_stack_at_msec", 0))
	var now_msec: int = Time.get_ticks_msec()
	var wait_sec: float = maxf(0.0, float(next_stack_at_msec - now_msec) / 1000.0 + 0.05)
	await get_tree().create_timer(wait_sec).timeout
	_pipeline.apply_incoming_damage(target, freeze_attack, profile)
	state = target.get_meta("_incoming_damage_state", {})
	if int(state.get("frost_stacks", 0)) >= 2:
		_expect(true, "freeze stack should increase after interval")
		return
	var start_msec: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 1200:
		await get_tree().create_timer(0.05).timeout
		_pipeline.apply_incoming_damage(target, freeze_attack, profile)
		state = target.get_meta("_incoming_damage_state", {})
		if int(state.get("frost_stacks", 0)) >= 2:
			_expect(true, "freeze stack should increase after interval")
			return
	_expect(false, "freeze stack should increase after interval")

func _test_cryo_infuser_applies_freeze_damage() -> void:
	var module_instance: Module = CRYO_INFUSER_SCRIPT.new() as Module
	var target: MockTarget = _new_target(200)
	var profile: DamageProfile = _build_enemy_profile(target)
	target.pipeline = _pipeline
	target.profile = profile
	module_instance.module_level = 1
	module_instance.apply_on_hit(null, target)
	var state: Dictionary = target.get_meta("_incoming_damage_state", {})
	_expect(int(state.get("frost_stacks", 0)) >= 1, "cryo infuser should apply freeze damage and seed frost")

func _test_subzero_extension_extends_frost() -> void:
	var module_instance: Module = SUBZERO_EXTENSION_SCRIPT.new() as Module
	var target: MockTarget = _new_target(200)
	var profile: DamageProfile = _build_enemy_profile(target)
	target.pipeline = _pipeline
	target.profile = profile
	var now_msec: int = Time.get_ticks_msec()
	target.set_meta("_incoming_damage_state", {
		"frost_stacks": 3,
		"frost_expires_at_msec": now_msec + 1000,
		"frost_next_stack_at_msec": now_msec,
	})
	module_instance.module_level = 3
	module_instance.apply_on_hit(null, target)
	var state: Dictionary = target.get_meta("_incoming_damage_state", {})
	_expect(int(state.get("frost_expires_at_msec", 0)) > now_msec + 1000, "subzero extension should extend frost expiry")
	_expect(target.slow_multiplier < 1.0, "subzero extension should apply strengthened frost slow")

func _test_brittle_trigger_icd() -> void:
	var module_instance: Module = BRITTLE_TRIGGER_SCRIPT.new() as Module
	var target: MockTarget = _new_target(200)
	var profile: DamageProfile = _build_enemy_profile(target)
	target.pipeline = _pipeline
	target.profile = profile
	target.set_meta("_incoming_damage_state", {
		"frost_stacks": 3,
		"frost_expires_at_msec": Time.get_ticks_msec() + 2000,
	})
	module_instance.module_level = 1
	var hp_before: int = target.hp
	module_instance.apply_on_hit(null, target)
	var hp_after_first: int = target.hp
	module_instance.apply_on_hit(null, target)
	var hp_after_second: int = target.hp
	_expect(hp_after_first < hp_before, "brittle trigger should deal bonus physical at >=3 frost")
	_expect(hp_after_second == hp_after_first, "brittle trigger should respect per-target ICD")

func _test_permafrost_field_cap() -> void:
	var module_instance: Module = PERMAFROST_FIELD_SCRIPT.new() as Module
	var target: MockTarget = _new_target(100)
	target.hp = 0
	target.is_dead = true
	target.set_meta("_incoming_damage_state", {
		"frost_stacks": 2,
		"frost_expires_at_msec": Time.get_ticks_msec() + 2000,
	})
	module_instance.module_level = 3
	for _i in range(5):
		module_instance.apply_on_hit(null, target)
	await get_tree().process_frame
	var field_count: int = 0
	var parent_node: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	for child in parent_node.get_children():
		if child is FrostFieldEffect:
			field_count += 1
	_expect(field_count <= 3, "permafrost field should cap active zones at 3")

func _new_target(max_hp: int) -> MockTarget:
	var target: MockTarget = MockTarget.new()
	target.max_hp = max_hp
	target.hp = max_hp
	add_child(target)
	return target

func _build_attack(amount: int, damage_type: StringName) -> Attack:
	var attack: Attack = Attack.new()
	attack.damage = amount
	attack.damage_type = damage_type
	return attack

func _build_enemy_profile(target: MockTarget) -> DamageProfile:
	var profile: DamageProfile = DAMAGE_PROFILE_SCRIPT.new() as DamageProfile
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

func _expect(condition: bool, message: String) -> void:
	if condition:
		_log("[PASS] %s" % message)
		return
	_failure_count += 1
	_log("[FAIL] %s" % message)

func _log(message: String) -> void:
	print(message)
	_logs.append(message)
