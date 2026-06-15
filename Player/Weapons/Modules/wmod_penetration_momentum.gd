extends "res://Player/Weapons/Modules/wmod_synergy_base.gd"

var ITEM_NAME := "Penetration Momentum"
@export var chain_window_sec := 0.22
@export var buff_duration_sec := 1.5
@export var bonus_per_chain_lv1 := 0.08
@export var bonus_per_chain_lv2 := 0.11
@export var bonus_per_chain_lv3 := 0.14
@export var max_chains := 5
var _last_target_id := 0
var _last_hit_msec := 0
var _chains := 0

func apply_on_hit(_source_weapon: Weapon, target: Node) -> void:
	if not is_enemy_target(target):
		return
	var now := Time.get_ticks_msec()
	var target_id := target.get_instance_id()
	if _last_target_id != 0 and target_id != _last_target_id and now <= _last_hit_msec + int(maxf(chain_window_sec, 0.05) * 1000.0):
		_chains = mini(maxi(max_chains, 1), _chains + 1)
		apply_damage_buff(1.0 + float(_chains) * get_level_value(bonus_per_chain_lv1, bonus_per_chain_lv2, bonus_per_chain_lv3), buff_duration_sec)
	else:
		_chains = 0
	_last_target_id = target_id
	_last_hit_msec = now

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_last_target_id = 0
	_chains = 0
