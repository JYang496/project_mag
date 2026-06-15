extends "res://Player/Weapons/Modules/wmod_synergy_base.gd"

var ITEM_NAME := "Magazine Pressure"
@export var max_damage_bonus_lv1 := 0.20
@export var max_damage_bonus_lv2 := 0.30
@export var max_damage_bonus_lv3 := 0.40

func get_incompatibility_reason(target_weapon: Weapon) -> String:
	var reason := super.get_incompatibility_reason(target_weapon)
	if reason != "":
		return reason
	return "" if target_weapon.uses_ammo_system() else "Requires an ammo-based weapon."

func apply_stat_modifiers(stat_block: Dictionary) -> Dictionary:
	var output := super.apply_stat_modifiers(stat_block)
	if not output.has("damage"):
		return output
	var spent_ratio := 1.0 - get_ammo_ratio()
	var bonus := get_level_value(max_damage_bonus_lv1, max_damage_bonus_lv2, max_damage_bonus_lv3) * spent_ratio
	output["damage"] = float(output["damage"]) * (1.0 + bonus)
	return output
