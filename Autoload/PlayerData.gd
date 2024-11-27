extends Node

var player_level := 1 :
	get:
		return player_level
	set(value):
		player_level = clampi(int(value), 0, 42)

var player_max_exp := 10 :
	get:
		return player_max_exp
	set(value):
		player_max_exp = clampi(int(value), 10, 99999)

var player_exp := 0 :
	get:
		return player_exp
	set(value):
		player_exp = clampi(int(value), 0, player_max_exp)
		
var player_speed := 100.0 :
	get:
		return player_speed
	set(value):
		player_speed = clampf(float(value), 1.0, 1000.0)
var player_bonus_speed := 0.0
var player_total_speed := player_speed + player_bonus_speed

var player_max_hp := 5 :
	get:
		return player_max_hp
	set(value):
		player_hp = clampi(int(value), 1, 50)
var player_hp := player_max_hp :
	get:
		return player_hp
	set(value):
		player_hp = clampi(int(value) - armor, 0, player_max_hp)

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

var hurt_cd := 1.0 :
	get:
		return hurt_cd
	set(value):
		hurt_cd = clampf(float(value), 0.2, 5.0)

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

var player_gold := 0
var is_interacting : bool = false

var overcharge_max_time : float = 1.5
var overcharge_time : float = 0:
	set(value):
		overcharge_time = value
		if overcharge_time >= overcharge_max_time:
			is_overcharged = true
		else:
			is_overcharged = false

var is_overcharging : bool = false :
	set(value):
		is_overcharging = value
		if value == false:
			overcharge_time = 0
			is_overcharged = false

var is_overcharged : bool = false:
	set(value):
		is_overcharged = value
		var ui = get_tree().get_first_node_in_group("ui")
		ui.refresh_border()

var player_weapon_list = []
var on_select_weapon : int = 0 :
	get:
		return on_select_weapon
	set(value):
		if player_weapon_list.size() == 0:
			return
		if value < 0:
			value = player_weapon_list.size() - 1
		if value >= player_weapon_list.size():
			value = 0
		on_select_weapon = clampi(value,0,player_weapon_list.size() - 1)

var player_companion_lsit = []
var player_augment_list = []
