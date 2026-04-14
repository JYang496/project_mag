extends Module
# Reloading grants temporary bonus shield based on spent ammo ratio.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Reload Barrier"

@export var shield_ratio_lv1: float = 0.10
@export var shield_ratio_lv2: float = 0.14
@export var shield_ratio_lv3: float = 0.18
@export var duration_lv1: float = 3.0
@export var duration_lv2: float = 4.0
@export var duration_lv3: float = 5.0

var _registered: bool = false
var _active_until_msec: int = 0
var _active_bonus_shield: int = 0

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
		"Reload grants temporary shield",
		"Shield scales with spent ammo",
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
	_clear_bonus()
	var max_hp: int = max(1, int(PlayerData.player_max_hp))
	_active_bonus_shield = max(0, int(round(float(max_hp) * _get_shield_ratio() * spent_ratio)))
	if _active_bonus_shield <= 0:
		return
	PlayerData.bonus_shield += _active_bonus_shield
	_active_until_msec = Time.get_ticks_msec() + int(maxf(_get_duration(), 0.05) * 1000.0)

func _clear_bonus() -> void:
	if _active_bonus_shield > 0:
		PlayerData.bonus_shield = max(0, int(PlayerData.bonus_shield) - _active_bonus_shield)
	_active_bonus_shield = 0
	_active_until_msec = 0

func _get_shield_ratio() -> float:
	return UTILS.get_value_by_level(module_level, shield_ratio_lv1, shield_ratio_lv2, shield_ratio_lv3)

func _get_duration() -> float:
	return UTILS.get_value_by_level(module_level, duration_lv1, duration_lv2, duration_lv3)
