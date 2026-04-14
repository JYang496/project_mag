extends Node2D
class_name BenchmarkDummyEnemy

const DAMAGE_PIPELINE_SCRIPT := preload("res://Utility/damage/damage_pipeline.gd")
const DAMAGE_PROFILE_SCRIPT := preload("res://Utility/damage/damage_profile.gd")

@export var max_hp: int = 2000000000
@export var base_armor: int = 0
@export var base_damage_reduction: float = 1.0
@export var base_damage_taken_multiplier: float = 1.0

var hp: int = 1
var is_dead: bool = false
var damage_taken_multiplier: float = 1.0
var _status_effects: Array[StatusEffect] = []
var _incoming_damage_pipeline: DamagePipeline
var _incoming_damage_profile: DamageProfile
var _total_damage_taken: int = 0
var _slow_remaining: float = 0.0
var _slow_multiplier: float = 1.0
var _stun_remaining: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	reset_runtime()

func reset_runtime() -> void:
	hp = max(1, max_hp)
	is_dead = false
	damage_taken_multiplier = maxf(base_damage_taken_multiplier, 0.05)
	_total_damage_taken = 0
	_status_effects.clear()
	_slow_remaining = 0.0
	_slow_multiplier = 1.0
	_stun_remaining = 0.0
	_incoming_damage_pipeline = DAMAGE_PIPELINE_SCRIPT.new() as DamagePipeline
	_setup_incoming_damage_profile()
	remove_meta(&"_incoming_damage_state")

func damaged(attack: Attack) -> void:
	if attack == null:
		return
	if is_dead:
		return
	if _incoming_damage_pipeline == null or _incoming_damage_profile == null:
		_incoming_damage_pipeline = DAMAGE_PIPELINE_SCRIPT.new() as DamagePipeline
		_setup_incoming_damage_profile()
	var prev_hp: int = hp
	var result: DamageResult = _incoming_damage_pipeline.apply_incoming_damage(self, attack, _incoming_damage_profile)
	if not result.applied:
		return
	var delta: int = max(0, prev_hp - hp)
	_total_damage_taken += delta
	# Keep target active for benchmark loops; do not remove from scene.
	if hp <= 0:
		hp = 1
		is_dead = false

func tick_benchmark(delta: float) -> void:
	var step_delta := maxf(delta, 0.0)
	if _incoming_damage_pipeline != null and _incoming_damage_profile != null:
		var periodic_results: Array[DamageResult] = _incoming_damage_pipeline.process_periodic_effects(self, _incoming_damage_profile, step_delta)
		for periodic_result in periodic_results:
			if periodic_result.applied:
				_total_damage_taken += max(0, int(periodic_result.final_damage))
	for i in range(_status_effects.size() - 1, -1, -1):
		var effect := _status_effects[i]
		if effect == null:
			_status_effects.remove_at(i)
			continue
		effect.apply_tick(self)
		if effect.step():
			_status_effects.remove_at(i)
	_stun_remaining = maxf(0.0, _stun_remaining - step_delta)
	if _slow_remaining > 0.0:
		_slow_remaining = maxf(0.0, _slow_remaining - step_delta)
		if _slow_remaining <= 0.0:
			_slow_multiplier = 1.0

func apply_status_effect(effect: StatusEffect) -> void:
	if effect == null:
		return
	for existing in _status_effects:
		if existing.effect_id == effect.effect_id:
			existing.merge_from(effect)
			return
	_status_effects.append(effect)

func apply_status_payload(status_name: StringName, status_data: Variant) -> void:
	match status_name:
		&"dot":
			apply_status_effect(DotStatusEffect.from_dot_payload(status_data))
		&"stun":
			var payload: Dictionary = status_data as Dictionary if status_data is Dictionary else {}
			apply_stun(float(payload.get("duration", 0.0)))
		&"slow":
			var payload: Dictionary = status_data as Dictionary if status_data is Dictionary else {}
			apply_slow(float(payload.get("multiplier", 1.0)), float(payload.get("duration", 0.0)))

func apply_stun(duration: float) -> void:
	if duration <= 0.0:
		return
	_stun_remaining = maxf(_stun_remaining, duration)

func apply_slow(multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	_slow_multiplier = minf(_slow_multiplier, clampf(multiplier, 0.05, 1.0))
	_slow_remaining = maxf(_slow_remaining, duration)

func is_stunned() -> bool:
	return _stun_remaining > 0.0

func is_slowed() -> bool:
	return _slow_remaining > 0.0 and _slow_multiplier < 1.0

func get_total_damage_taken() -> int:
	return _total_damage_taken

func _setup_incoming_damage_profile() -> void:
	var profile := DAMAGE_PROFILE_SCRIPT.new() as DamageProfile
	profile.profile_id = &"benchmark_dummy"
	profile.use_damage_reduction = true
	profile.use_armor = true
	profile.use_invuln = false
	profile.dot_bypasses_invuln = true
	profile.get_hp = Callable(self, "_profile_get_hp")
	profile.set_hp = Callable(self, "_profile_set_hp")
	profile.get_max_hp = Callable(self, "_profile_get_max_hp")
	profile.get_armor = Callable(self, "_profile_get_armor")
	profile.get_damage_reduction = Callable(self, "_profile_get_damage_reduction")
	profile.get_damage_taken_multiplier = Callable(self, "_profile_get_damage_taken_multiplier")
	profile.get_is_dead = Callable(self, "_profile_get_is_dead")
	profile.set_is_dead = Callable(self, "_profile_set_is_dead")
	profile.on_death = Callable(self, "_profile_on_death")
	profile.on_apply_frost_slow = Callable(self, "_profile_on_apply_frost_slow")
	profile.on_clear_frost_slow = Callable(self, "_profile_on_clear_frost_slow")
	_incoming_damage_profile = profile

func _profile_get_hp() -> int:
	return hp

func _profile_set_hp(value: int) -> void:
	hp = int(value)

func _profile_get_max_hp() -> int:
	return max(1, max_hp)

func _profile_get_armor() -> int:
	return max(0, base_armor)

func _profile_get_damage_reduction() -> float:
	return clampf(base_damage_reduction, 0.05, 5.0)

func _profile_get_damage_taken_multiplier() -> float:
	return maxf(damage_taken_multiplier, 0.05)

func _profile_get_is_dead() -> bool:
	return is_dead

func _profile_set_is_dead(value: bool) -> void:
	is_dead = bool(value)

func _profile_on_death(_attack: Attack) -> void:
	is_dead = true

func _profile_on_apply_frost_slow(move_multiplier: float, duration_sec: float) -> void:
	apply_slow(move_multiplier, duration_sec)

func _profile_on_clear_frost_slow() -> void:
	_slow_remaining = 0.0
	_slow_multiplier = 1.0
