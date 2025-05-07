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
	ImportData.import_mecha_data(str(PlayerData.select_mecha_id))
	var path = ImportData.mecha_data["res"]
	var select_mecha_load = load(path)
	set_start_up_status()
	var ins = select_mecha_load.instantiate()
	ins.position = self.position
	self.call_deferred("add_sibling",ins)
	
func set_start_up_status():
	PlayerData.player_speed = start_up_status["player_speed"]
	PlayerData.player_max_hp = start_up_status["player_max_hp"]
	PlayerData.player_hp = PlayerData.player_max_hp
	PlayerData.hp_regen = start_up_status["hp_regen"]
	PlayerData.armor = start_up_status["armor"]
	PlayerData.shield = start_up_status["shield"]
	PlayerData.damage_reduction = start_up_status["damage_reduction"]
	PlayerData.crit_rate = start_up_status["crit_rate"]
	PlayerData.crit_damage = start_up_status["crit_damage"]
	PlayerData.grab_radius = start_up_status["grab_radius"]
	PlayerData.player_gold = start_up_status["player_gold"]
