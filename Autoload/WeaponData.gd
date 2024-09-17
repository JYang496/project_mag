extends Node

var weapon_list = JSON.new()

func _ready():
	import_resources_data()
	
func import_resources_data():
	var file = FileAccess.open("res://Data/example.json", FileAccess.READ)
	var stringdata = file.get_as_text()
	weapon_list.parse(stringdata)
	file.close()
