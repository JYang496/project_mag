extends RefCounted
class_name DamageProfile

var profile_id: StringName = StringName()
var use_damage_reduction: bool = true
var use_armor: bool = true
var use_invuln: bool = false
var dot_bypasses_invuln: bool = true

var get_hp: Callable
var set_hp: Callable
var get_max_hp: Callable
var get_armor: Callable
var get_damage_reduction: Callable
var get_damage_taken_multiplier: Callable
var get_is_dead: Callable
var set_is_dead: Callable

var on_death: Callable
var on_trigger_invuln: Callable
var on_apply_frost_slow: Callable
var on_clear_frost_slow: Callable

func _call_or_default(callable_ref: Callable, default_value: Variant = null, args: Array = []) -> Variant:
	if callable_ref == Callable() or not callable_ref.is_valid():
		return default_value
	return callable_ref.callv(args)

func read_hp() -> int:
	return int(_call_or_default(get_hp, 0))

func write_hp(value: int) -> void:
	_call_or_default(set_hp, null, [value])

func read_max_hp() -> int:
	return max(1, int(_call_or_default(get_max_hp, 1)))

func read_armor() -> int:
	if not use_armor:
		return 0
	return max(0, int(_call_or_default(get_armor, 0)))

func read_damage_reduction() -> float:
	if not use_damage_reduction:
		return 1.0
	return float(_call_or_default(get_damage_reduction, 1.0))

func read_damage_taken_multiplier() -> float:
	return maxf(0.0, float(_call_or_default(get_damage_taken_multiplier, 1.0)))

func read_is_dead() -> bool:
	return bool(_call_or_default(get_is_dead, false))

func write_is_dead(value: bool) -> void:
	if set_is_dead == Callable() or not set_is_dead.is_valid():
		return
	set_is_dead.call(value)

func call_on_death(attack: Attack) -> void:
	if on_death == Callable() or not on_death.is_valid():
		return
	on_death.call(attack)

func call_trigger_invuln() -> void:
	if on_trigger_invuln == Callable() or not on_trigger_invuln.is_valid():
		return
	on_trigger_invuln.call()

func call_apply_frost_slow(move_multiplier: float, duration_sec: float) -> void:
	if on_apply_frost_slow == Callable() or not on_apply_frost_slow.is_valid():
		return
	on_apply_frost_slow.call(move_multiplier, duration_sec)

func call_clear_frost_slow() -> void:
	if on_clear_frost_slow == Callable() or not on_clear_frost_slow.is_valid():
		return
	on_clear_frost_slow.call()
