extends Node

# Weapon id, file location price and description will be stored in this object.
var weapon_list = JSON.new()


func _ready():
	import_resources_data()
	
# This function is used for locate weapon file location which stored in weapons.json, called in shop.
func import_resources_data() -> void:
	var file = FileAccess.open("res://Data/weapons.json", FileAccess.READ)
	var stringdata = file.get_as_text()
	weapon_list.parse(stringdata)
	file.close()

# Load mecha data, will be called in Start menu.
func read_mecha_data(id : String) -> Dictionary:
	var file = FileAccess.open("res://Data/Mechas/mechas.json", FileAccess.READ)
	var file_data = JSON.new()
	file_data.parse(file.get_as_text())
	file.close()
	return file_data.data[id]
