extends Module
# Reloading grants this weapon temporary bonus damage based on spent ammo ratio.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Reloaded Force"

@export var bonus_lv1: float = 0.20
@export var bonus_lv2: float = 0.30
@export var bonus_lv3: float = 0.40
@export var duration_lv1: float = 3.0
@export var duration_lv2: float = 4.0
@export var duration_lv3: float = 5.0

var _registered: bool = false
var _active_until_msec: int = 0

func _enter_tree() -> void:
	super._enter_tree()
	_register_hook()

func _ready() -> void:
	_register_hook()

func _exit_tree() -> void:
	_unregister_hook()
	_clear_bonus()

func _physics_process(_delta: float) -> void:
	if _active_until_msec <= 0:
		return
	if Time.get_ticks_msec() < _active_until_msec:
		return
	_clear_bonus()

func get_effect_descriptions() -> PackedStringArray:
	return PackedStringArray([
		"Reload grants temporary weapon damage",
		"Bonus scales with spent ammo",
	])

func _register_hook() -> void:
	if _registered:
		return
	if weapon == null:
		weapon = _resolve_weapon()
	if weapon == null or not is_instance_valid(weapon):
		return
	if weapon.passive_triggered.is_connected(_on_weapon_passive_triggered):
		_registered = true
		return
	weapon.passive_triggered.connect(_on_weapon_passive_triggered)
	_registered = true

func _unregister_hook() -> void:
	if not _registered:
		return
	if weapon != null and is_instance_valid(weapon) and weapon.passive_triggered.is_connected(_on_weapon_passive_triggered):
		weapon.passive_triggered.disconnect(_on_weapon_passive_triggered)
	_registered = false

func _on_weapon_passive_triggered(event_name: StringName, detail: Dictionary) -> void:
	if event_name != &"on_reload_started":
		return
	if detail == null or detail.get("source_weapon", null) != weapon:
		return
	var spent_ratio := UTILS.get_spent_ratio(detail)
	if spent_ratio <= 0.0:
		return
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.has_method("apply_external_damage_mul") or not weapon.has_method("remove_external_damage_mul"):
		return
	var next_mul := 1.0 + _get_bonus_ratio() * spent_ratio
	var source_id := _get_source_id()
	weapon.call("remove_external_damage_mul", source_id)
	weapon.call("apply_external_damage_mul", source_id, next_mul)
	_active_until_msec = Time.get_ticks_msec() + int(maxf(_get_duration(), 0.05) * 1000.0)

func _clear_bonus() -> void:
	if weapon != null and is_instance_valid(weapon) and weapon.has_method("remove_external_damage_mul"):
		weapon.call("remove_external_damage_mul", _get_source_id())
	_active_until_msec = 0

func _get_bonus_ratio() -> float:
	return UTILS.get_value_by_level(module_level, bonus_lv1, bonus_lv2, bonus_lv3)

func _get_duration() -> float:
	return UTILS.get_value_by_level(module_level, duration_lv1, duration_lv2, duration_lv3)

func _get_source_id() -> StringName:
	return StringName("wmod_reload_damage_boost_%s" % str(get_instance_id()))
