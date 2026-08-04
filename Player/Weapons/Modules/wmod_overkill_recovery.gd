extends "res://Player/Weapons/Modules/wmod_synergy_base.gd"

var ITEM_NAME := "Overkill Recovery"
@export var conversion_lv1 := 0.25
@export var conversion_lv2 := 0.35
@export var conversion_lv3 := 0.45
@export var max_bonus_lv1 := 0.30
@export var max_bonus_lv2 := 0.45
@export var max_bonus_lv3 := 0.60
@export var buff_duration_sec := 4.0

func on_damage_dealt(source_weapon: Weapon, target: Node, _data: DamageData, result: DamageResult) -> void:
	if not is_enemy_target(target) or result == null or not result.killed:
		return
	var overkill: int = maxi(0, result.overkill_damage)
	if overkill <= 0:
		return
	var base_damage: int = WeaponModuleRuntimeUtils.get_runtime_weapon_damage(source_weapon)
	var ratio: float = float(overkill) / float(maxi(base_damage, 1))
	var bonus: float = minf(ratio * get_level_value(conversion_lv1, conversion_lv2, conversion_lv3), get_level_value(max_bonus_lv1, max_bonus_lv2, max_bonus_lv3))
	apply_damage_buff(1.0 + bonus, buff_duration_sec)
