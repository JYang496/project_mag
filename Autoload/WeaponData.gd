extends Node

# Weapon id, file location price and description will be stored in this object.
var weapon_list = JSON.new()

# Mecha current level, max level, status of each level is stored in this object.
var mecha_data = JSON.new()

func _ready():
	import_resources_data()
	
# This function is used for locate weapon file location which stored in example.json, called in shop.
func import_resources_data():
	var file = FileAccess.open("res://Data/example.json", FileAccess.READ)
	var stringdata = file.get_as_text()
	weapon_list.parse(stringdata)
	file.close()

# Load mecha data, will be called in Start menu.
func import_mecha_data(mecha : String) -> void:
	var file = FileAccess.open("res://Data/Mechas/" + mecha + ".json", FileAccess.READ)
	var stringdata = file.get_as_text()
	mecha_data.parse(stringdata)
	file.close()
