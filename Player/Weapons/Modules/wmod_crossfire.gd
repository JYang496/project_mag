extends "res://Player/Weapons/Modules/wmod_synergy_base.gd"

var ITEM_NAME := "Crossfire"
@export var crossfire_window_sec := 2.0
@export var buff_duration_sec := 2.5
@export var damage_bonus_lv1 := 0.16
@export var damage_bonus_lv2 := 0.23
@export var damage_bonus_lv3 := 0.30

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if not is_enemy_target(target) or source_weapon == null:
		return
	var now := Time.get_ticks_msec()
	var previous_weapon_id := int(target.get_meta(Weapon.LAST_HIT_WEAPON_META, 0))
	var previous_hit_msec := int(target.get_meta(Weapon.LAST_HIT_WEAPON_TIME_META, 0))
	if previous_weapon_id != 0 and previous_weapon_id != source_weapon.get_instance_id() and now <= previous_hit_msec + int(maxf(crossfire_window_sec, 0.1) * 1000.0):
		apply_damage_buff(1.0 + get_level_value(damage_bonus_lv1, damage_bonus_lv2, damage_bonus_lv3), buff_duration_sec)
