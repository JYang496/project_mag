extends "res://Player/Weapons/Modules/wmod_synergy_base.gd"

var ITEM_NAME := "Weakness Relay"
@export var buff_duration_sec := 2.5
@export var damage_bonus_lv1 := 0.12
@export var damage_bonus_lv2 := 0.18
@export var damage_bonus_lv3 := 0.24

func apply_on_hit(_source_weapon: Weapon, target: Node) -> void:
	if is_enemy_target(target) and has_negative_status(target):
		apply_damage_buff(1.0 + get_level_value(damage_bonus_lv1, damage_bonus_lv2, damage_bonus_lv3), buff_duration_sec)
