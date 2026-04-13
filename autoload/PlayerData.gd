extends Node

signal main_weapon_index_changed(old_index: int, new_index: int, step: int)
signal weapon_list_changed()

@onready var player : Player
var select_mecha_id :int = 1

var player_level := 1 :
	get:
		return player_level
	set(value):
		player_level = clampi(int(value), 1, 42)
		next_level_exp = int(GlobalVariables.mech_data["next_level_exp"][player_level - 1]) if GlobalVariables.mech_data else 10

var next_level_exp := 10 :
	get:
		return next_level_exp
	set(value):
		next_level_exp = clampi(int(value), 10, 99999)

var player_exp := 0 :
	get:
		return player_exp
	set(value):
		player_exp = clampi(int(value), 0, 99999)
		while player_exp >= next_level_exp:
			player_level += 1
			player_exp -= next_level_exp
		
var player_speed : float = 100.0 :
	get:
		return player_speed
	set(value):
		player_speed = clampf(float(value), 1.0, 1000.0)
var player_bonus_speed : float = 0.0
var dash_cooldown: float = 5.0

var player_max_hp := 5 :
	get:
		return player_max_hp
	set(value):
		player_max_hp = clampi(int(value), 1, 999)
var player_hp := player_max_hp :
	get:
		return player_hp
	set(value):
		player_hp = clampi(int(value), 0, player_max_hp)

var hp_regen := 0
var hp_bonus_regen := 0
var hp_total_regen := hp_regen + hp_bonus_regen

var armor := 0
var bonus_armor := 0
var total_armor := armor + bonus_armor

var shield := 0 :
	get:
		return shield
	set(value):
		shield = clampi(int(value),0, player_max_hp)
var bonus_shield := 0
var total_shield := shield + bonus_shield

var damage_reduction := 1.0 :
	get:
		return damage_reduction
	set(value):
		damage_reduction = clampf(float(value), 0.2, 5.0)
var bonus_damage_reduction := 1.0
var total_damage_reduction := damage_reduction * bonus_damage_reduction

var hurt_cd := 3.0 :
	get:
		return hurt_cd
	set(value):
		hurt_cd = clampf(float(value), 0.2, 5.0)

var collision_cd := 1.0 :
	get:
		return collision_cd
	set(value):
		collision_cd = clampf(float(value), 0.2, 5.0)

var crit_rate := 0.0 :
	get:
		return crit_rate
	set(value):
		crit_rate = clampf(float(value), 0.0, 1.0)
var bonus_crit_rate := 0.0
var total_crit_rate := crit_rate + bonus_crit_rate

var crit_damage := 1.0
var bonus_crit_damage := 1.0
var total_crit_damage := crit_damage * bonus_crit_damage

var grab_radius := 50.0 :
	get:
		return grab_radius
	set(value):
		grab_radius = clampf(float(value),0.0, 1200.0)
		total_grab_radius = grab_radius * grab_radius_mutifactor
var grab_radius_mutifactor := 1.0 :
	get:
		return grab_radius_mutifactor
	set(value):
		grab_radius_mutifactor = value
		total_grab_radius = grab_radius * grab_radius_mutifactor

var total_grab_radius := grab_radius * grab_radius_mutifactor

var player_gold := 10
var round_coin_collected := 0
var round_chip_collected := 0
var testing_keep_hp_above_zero := false
var is_interacting : bool = false

var detected_enemies : Array = []
var cloestest_enemy : Area2D = null

var player_weapon_list = []
var max_weapon_num : int = 4
var main_weapon_index: int = -1
var on_select_weapon : int = -1 :
	get:
		return on_select_weapon
	set(value):
		if value >= player_weapon_list.size() or player_weapon_list.size() <= 0:
			value = -1
		if value < -1:
			value = player_weapon_list.size() - 1
		on_select_weapon = clampi(value,-1,player_weapon_list.size() - 1)
		if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui):
			GlobalVariables.ui.refresh_border()

var player_companion_lsit = []
var player_augment_list = []

func set_hp_safety_for_testing(enabled: bool) -> void:
	testing_keep_hp_above_zero = enabled
	if testing_keep_hp_above_zero:
		if player_max_hp < 1:
			player_max_hp = 1
		if player_hp < 1:
			player_hp = 1


func reset_runtime_state() -> void:
	var prev_main_index := main_weapon_index
	player = null
	player_level = 1
	next_level_exp = 10
	player_exp = 0
	player_speed = 100.0
	player_bonus_speed = 0.0
	dash_cooldown = 5.0
	player_max_hp = 5
	player_hp = 5
	hp_regen = 0
	hp_bonus_regen = 0
	hp_total_regen = 0
	armor = 0
	bonus_armor = 0
	total_armor = 0
	shield = 0
	bonus_shield = 0
	total_shield = 0
	damage_reduction = 1.0
	bonus_damage_reduction = 1.0
	total_damage_reduction = 1.0
	hurt_cd = 3.0
	collision_cd = 1.0
	crit_rate = 0.0
	bonus_crit_rate = 0.0
	total_crit_rate = 0.0
	crit_damage = 1.0
	bonus_crit_damage = 1.0
	total_crit_damage = 1.0
	grab_radius = 50.0
	grab_radius_mutifactor = 1.0
	total_grab_radius = 50.0
	player_gold = 10
	round_coin_collected = 0
	round_chip_collected = 0
	is_interacting = false
	detected_enemies.clear()
	cloestest_enemy = null
	player_weapon_list.clear()
	max_weapon_num = 4
	main_weapon_index = -1
	on_select_weapon = -1
	player_companion_lsit.clear()
	player_augment_list.clear()
	testing_keep_hp_above_zero = false
	weapon_list_changed.emit()
	if prev_main_index != main_weapon_index:
		main_weapon_index_changed.emit(prev_main_index, main_weapon_index, 0)

func sanitize_main_weapon_index() -> void:
	var old_index := main_weapon_index
	if player_weapon_list.is_empty():
		main_weapon_index = -1
	else:
		main_weapon_index = clampi(main_weapon_index, 0, player_weapon_list.size() - 1)
	if old_index != main_weapon_index:
		main_weapon_index_changed.emit(old_index, main_weapon_index, 0)

func can_switch_main_weapon() -> bool:
	return player_weapon_list.size() > 1

func set_main_weapon_index(value: int) -> void:
	var old_index := main_weapon_index
	if player_weapon_list.is_empty():
		main_weapon_index = -1
	else:
		main_weapon_index = clampi(value, 0, player_weapon_list.size() - 1)
	if old_index != main_weapon_index:
		var step_sign := _calculate_step_sign(old_index, main_weapon_index, player_weapon_list.size())
		main_weapon_index_changed.emit(old_index, main_weapon_index, step_sign)
	on_select_weapon = main_weapon_index
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui):
		GlobalVariables.ui.refresh_border()

func shift_main_weapon(step: int) -> void:
	if not can_switch_main_weapon():
		sanitize_main_weapon_index()
		on_select_weapon = main_weapon_index
		return
	if main_weapon_index < 0:
		main_weapon_index = 0
	var size := player_weapon_list.size()
	var next := (main_weapon_index + step) % size
	if next < 0:
		next += size
	set_main_weapon_index(next)

func notify_weapon_list_changed() -> void:
	weapon_list_changed.emit()

func _calculate_step_sign(old_index: int, new_index: int, list_size: int) -> int:
	if list_size <= 1 or old_index < 0 or new_index < 0:
		return 0
	var diff := new_index - old_index
	if diff == 0:
		return 0
	var abs_diff := absi(diff)
	if abs_diff > list_size / 2:
		return -1 if diff > 0 else 1
	return 1 if diff > 0 else -1
