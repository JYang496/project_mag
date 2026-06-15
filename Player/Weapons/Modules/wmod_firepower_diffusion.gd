extends "res://Player/Weapons/Modules/wmod_synergy_base.gd"

var ITEM_NAME := "Firepower Diffusion"
@export var unique_window_sec := 1.0
@export var buff_duration_sec := 2.5
@export var bonus_per_target_lv1 := 0.05
@export var bonus_per_target_lv2 := 0.07
@export var bonus_per_target_lv3 := 0.09
@export var max_bonus_targets := 5
var _recent_targets: Dictionary = {}

func apply_on_hit(_source_weapon: Weapon, target: Node) -> void:
	if not is_enemy_target(target):
		return
	var now := Time.get_ticks_msec()
	for target_id in _recent_targets.keys():
		if now >= int(_recent_targets[target_id]):
			_recent_targets.erase(target_id)
	_recent_targets[target.get_instance_id()] = now + int(maxf(unique_window_sec, 0.1) * 1000.0)
	if _recent_targets.size() < 2:
		return
	var counted := mini(_recent_targets.size(), maxi(max_bonus_targets, 2))
	apply_damage_buff(1.0 + float(counted - 1) * get_level_value(bonus_per_target_lv1, bonus_per_target_lv2, bonus_per_target_lv3), buff_duration_sec)

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_recent_targets.clear()
