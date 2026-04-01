extends Module
# Extends frost expiration and strengthens slow derived from frost stacks.

var ITEM_NAME := "Subzero Extension"

@export var extension_lv1: float = 0.6
@export var extension_lv2: float = 0.9
@export var extension_lv3: float = 1.2
@export var slow_bonus_lv1: float = 0.10
@export var slow_bonus_lv2: float = 0.15
@export var slow_bonus_lv3: float = 0.20
@export var max_total_slow: float = 0.35
@export var base_frost_slow_per_stack: float = 0.04

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(_source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_meta("_incoming_damage_state"):
		return
	var state_variant: Variant = target.get_meta("_incoming_damage_state", {})
	if not (state_variant is Dictionary):
		return
	var state: Dictionary = state_variant
	var frost_stacks: int = int(state.get("frost_stacks", 0))
	if frost_stacks <= 0:
		return
	var extension_sec: float = _get_extension_sec_by_level()
	var now_msec: int = Time.get_ticks_msec()
	var expires_at: int = int(state.get("frost_expires_at_msec", 0))
	if expires_at < now_msec:
		expires_at = now_msec
	expires_at += int(maxf(extension_sec, 0.0) * 1000.0)
	state["frost_expires_at_msec"] = expires_at
	target.set_meta("_incoming_damage_state", state)
	if target.has_method("apply_slow"):
		var bonus_factor: float = _get_slow_bonus_factor_by_level()
		var per_stack_slow: float = base_frost_slow_per_stack * (1.0 + bonus_factor)
		var total_slow: float = clampf(float(frost_stacks) * per_stack_slow, 0.0, maxf(max_total_slow, 0.0))
		var move_multiplier: float = clampf(1.0 - total_slow, 0.05, 1.0)
		target.call("apply_slow", move_multiplier, maxf(extension_sec, 0.1))

func _get_extension_sec_by_level() -> float:
	match module_level:
		3:
			return extension_lv3
		2:
			return extension_lv2
		_:
			return extension_lv1

func _get_slow_bonus_factor_by_level() -> float:
	match module_level:
		3:
			return slow_bonus_lv3
		2:
			return slow_bonus_lv2
		_:
			return slow_bonus_lv1
