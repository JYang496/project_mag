extends Module
# Reload speed improves when another weapon is already reloading.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Reload Link"

@export var bonus_lv1: float = 0.18
@export var bonus_lv2: float = 0.24
@export var bonus_lv3: float = 0.30

func get_reload_duration_multiplier(source_weapon: Weapon, _base_duration: float) -> float:
	if source_weapon == null or source_weapon != weapon:
		return 1.0
	if not _has_other_reloading_weapon():
		return 1.0
	return maxf(1.0 - _get_bonus_ratio(), 0.05)

func get_effect_descriptions() -> PackedStringArray:
	return with_level_effect_descriptions(PackedStringArray([
		LocalizationManager.get_module_detail(
			self, "detail.1", {}, "Reloads faster while another weapon is reloading"
		),
	]))

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
