extends Module
# Reload speed improves when another weapon is already reloading.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Reload Link"

@export var bonus_lv1: float = 0.18
@export var bonus_lv2: float = 0.24
@export var bonus_lv3: float = 0.30

var _registered: bool = false

func _enter_tree() -> void:
	super._enter_tree()
	_register_plugin()

func _ready() -> void:
	_register_plugin()

func _exit_tree() -> void:
	_unregister_plugin()

func get_reload_duration_multiplier(source_weapon: Weapon, _base_duration: float) -> float:
	if source_weapon == null or source_weapon != weapon:
		return 1.0
	if not _has_other_reloading_weapon():
		return 1.0
	return maxf(1.0 - _get_bonus_ratio(), 0.05)

func get_effect_descriptions() -> PackedStringArray:
	return PackedStringArray([
		"Reloads faster while another weapon is reloading",
	])

func _register_plugin() -> void:
	if _registered:
		return
	if weapon == null:
		weapon = _resolve_weapon()
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.has_method("register_reload_duration_plugin"):
		return
	weapon.call("register_reload_duration_plugin", self)
	_registered = true

func _unregister_plugin() -> void:
	if not _registered:
		return
	if weapon != null and is_instance_valid(weapon) and weapon.has_method("unregister_reload_duration_plugin"):
		weapon.call("unregister_reload_duration_plugin", self)
	_registered = false

func _has_other_reloading_weapon() -> bool:
	for other_weapon in UTILS.get_player_weapons():
		if other_weapon == null or not is_instance_valid(other_weapon):
			continue
		if other_weapon == weapon:
			continue
		if other_weapon.get("is_reloading") == null:
			continue
		if bool(other_weapon.get("is_reloading")):
			return true
	return false

func _get_bonus_ratio() -> float:
	return UTILS.get_value_by_level(module_level, bonus_lv1, bonus_lv2, bonus_lv3)
