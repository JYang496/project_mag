extends Node2D

@onready var collector = preload("res://Player/Mechas/collector.tscn")

var start_up_status = {
	"player_speed":100.0,
	"player_max_hp":5,
	"hp_regen":0,
	"armor":0,
	"shield":0,
	"damage_reduction":1.0,
	"crit_rate":0.0,
	"crit_damage":1.0,
	"grab_radius":50.0,
	"player_gold":0,
}
func _ready() -> void:
	GlobalVariables.mech_data = DataHandler.read_mecha_data(str(PlayerData.select_mecha_id))
	GlobalVariables.autosave_data = DataHandler.read_autosave_data(str(PlayerData.select_mecha_id))
	var path = GlobalVariables.mech_data["res"]
	var select_mecha_load = load(path)
	set_start_up_status()
	var ins = select_mecha_load.instantiate()
	ins.position = self.position
	PlayerData.player = ins
	self.call_deferred("add_sibling",ins)
	
func set_start_up_status():
	var lvl_index = int(GlobalVariables.autosave_data["current_level"]) - 1
	PlayerData.player_exp = int(GlobalVariables.autosave_data["current_exp"])
	PlayerData.player_level = int(GlobalVariables.autosave_data["current_level"])
	PlayerData.next_level_exp = int(GlobalVariables.mech_data["next_level_exp"][lvl_index])
	PlayerData.player_speed = float(GlobalVariables.mech_data["player_speed"][lvl_index])
	PlayerData.player_max_hp = int(GlobalVariables.mech_data["player_max_hp"][lvl_index])
	PlayerData.player_hp = PlayerData.player_max_hp
	PlayerData.hp_regen = float(GlobalVariables.mech_data["hp_regen"][lvl_index])
	PlayerData.armor = int(GlobalVariables.mech_data["armor"][lvl_index])
	PlayerData.shield = int(GlobalVariables.mech_data["shield"][lvl_index])
	PlayerData.damage_reduction = float(GlobalVariables.mech_data["damage_reduction"][lvl_index])
	PlayerData.crit_rate = float(GlobalVariables.mech_data["crit_rate"][lvl_index])
	PlayerData.crit_damage = float(GlobalVariables.mech_data["crit_damage"][lvl_index])
	PlayerData.grab_radius = float(GlobalVariables.mech_data["grab_radius"][lvl_index])
	PlayerData.player_gold = int(GlobalVariables.mech_data["player_gold"][lvl_index])
