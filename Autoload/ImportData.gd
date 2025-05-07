extends Node

# Weapon id, file location price and description will be stored in this object.
var weapon_list = JSON.new()

# Mecha current level, max level, status of each level is stored in this object.
var mecha_data = JSON.new()

func _ready():
	import_resources_data()
	import_mecha_data(str(PlayerData.select_mecha_id))
	
# This function is used for locate weapon file location which stored in weapons.json, called in shop.
func import_resources_data() -> void:
	var file = FileAccess.open("res://Data/weapons.json", FileAccess.READ)
	var stringdata = file.get_as_text()
	weapon_list.parse(stringdata)
	file.close()

# Load mecha data, will be called in Start menu.
func import_mecha_data(id : String) -> void:
	var file = FileAccess.open("res://Data/Mechas/mechas.json", FileAccess.READ)
	var file_data = JSON.new()
	file_data.parse(file.get_as_text())
	mecha_data = file_data.data[id]
	file.close()
