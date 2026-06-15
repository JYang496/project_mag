extends "res://Player/Weapons/Modules/wmod_synergy_base.gd"

var ITEM_NAME := "Rhythm Converter"
@export var pause_sec := 0.8
@export var buff_duration_sec := 2.0
@export var bonus_per_hit_lv1 := 0.03
@export var bonus_per_hit_lv2 := 0.04
@export var bonus_per_hit_lv3 := 0.05
@export var max_hits := 10
var _hit_count := 0
var _last_hit_msec := 0

func apply_on_hit(_source_weapon: Weapon, target: Node) -> void:
	if not is_enemy_target(target):
		return
	_hit_count = mini(maxi(max_hits, 1), _hit_count + 1)
	_last_hit_msec = Time.get_ticks_msec()
	set_physics_process(true)

func on_synergy_physics_process() -> void:
	if _hit_count <= 0 or Time.get_ticks_msec() < _last_hit_msec + int(maxf(pause_sec, 0.1) * 1000.0):
		return
	apply_damage_buff(1.0 + float(_hit_count) * get_level_value(bonus_per_hit_lv1, bonus_per_hit_lv2, bonus_per_hit_lv3), buff_duration_sec)
	_hit_count = 0

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_hit_count = 0
