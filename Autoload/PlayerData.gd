extends Node

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
var is_interacting : bool = false

var overcharge_enable : bool = true:
	set(value):
		# Bug fix: to remove weapon properly
		#on_select_weapon = -1
		overcharge_enable = value
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
		if is_overcharged != value:
			is_overcharged = value
			var ui = get_tree().get_first_node_in_group("ui")
			ui.refresh_border()

var casting_oc_skill : bool = false
var detected_enemies : Array = []
var cloestest_enemy : Area2D = null

var player_weapon_list = []
var max_weapon_num : int = 4
var on_select_weapon : int = -1 :
	get:
		return on_select_weapon
	set(value):
		if value >= player_weapon_list.size() or player_weapon_list.size() <= 0:
			value = -1
		if value < -1:
			value = player_weapon_list.size() - 1
		on_select_weapon = clampi(value,-1,player_weapon_list.size() - 1)
		GlobalVariables.ui.refresh_border()

var player_companion_lsit = []
var player_augment_list = []
