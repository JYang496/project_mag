extends "res://Player/Weapons/Modules/wmod_synergy_base.gd"

var ITEM_NAME := "Inertial Aim"
@export var stationary_damage_lv1 := 0.15
@export var stationary_damage_lv2 := 0.22
@export var stationary_damage_lv3 := 0.29
@export var moving_attack_speed_lv1 := 0.10
@export var moving_attack_speed_lv2 := 0.15
@export var moving_attack_speed_lv3 := 0.20
@export var moving_threshold := 10.0
var _attack_speed_source_id: StringName
var _moving := false

func _ready() -> void:
	super._ready()
	_attack_speed_source_id = StringName("inertial_aim_%s" % str(get_instance_id()))
	set_physics_process(true)

func _exit_tree() -> void:
	_clear_attack_speed()
	super._exit_tree()

func on_synergy_physics_process() -> void:
	var player: Node = PlayerData.player
	var moving_now: bool = player != null and is_instance_valid(player) and player.get("velocity") != null and (player.get("velocity") as Vector2).length() >= moving_threshold
	if moving_now == _moving:
		return
	_moving = moving_now
	if weapon is Ranger:
		if _moving:
			(weapon as Ranger).apply_external_attack_speed_mul(_attack_speed_source_id, 1.0 + get_level_value(moving_attack_speed_lv1, moving_attack_speed_lv2, moving_attack_speed_lv3))
		else:
			_clear_attack_speed()

func apply_stat_modifiers(stat_block: Dictionary) -> Dictionary:
	var output := super.apply_stat_modifiers(stat_block)
	if output.has("damage") and not _moving:
		output["damage"] = float(output["damage"]) * (1.0 + get_level_value(stationary_damage_lv1, stationary_damage_lv2, stationary_damage_lv3))
	return output

func _clear_attack_speed() -> void:
	if weapon is Ranger:
		(weapon as Ranger).remove_external_attack_speed_mul(_attack_speed_source_id)
