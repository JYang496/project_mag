extends Node

func _ready():
	import_resources_data()

# This function is used for locate weapon file location which stored in weapons.json, called in shop.
func import_resources_data() -> void:
	var file = FileAccess.open("res://Data/weapons.json", FileAccess.READ)
	var stringdata = file.get_as_text()
	GlobalVariables.weapon_list = JSON.new()
	GlobalVariables.weapon_list.parse(stringdata)
	file.close()

# Load mecha data, will be called in Start menu.
func read_mecha_data(id : String) -> Dictionary:
	var file = FileAccess.open("res://Data/mechas.json", FileAccess.READ)
	var file_data = JSON.new()
	file_data.parse(file.get_as_text())
	file.close()
	return file_data.data[id]

# Load mecha data, will be called in Start menu.
func read_autosave_mecha_data(id : String) -> Dictionary:
	var file = FileAccess.open("res://Data/autosave.json", FileAccess.READ)
	var file_data = JSON.new()
	file_data.parse(file.get_as_text())
	file.close()
	return file_data.data["mechas"][id]

func modify_autosave_mecha_data(id : String, key : String, value : String) -> void:
	var file = FileAccess.open("res://Data/autosave.json", FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message())
		return
	var data = json.data
	data["mechas"][id][key] = value
	var modified_json = JSON.stringify(data,"\t",false)
	var file_write = FileAccess.open("res://Data/autosave.json", FileAccess.WRITE)
	file_write.store_string(modified_json)
	file_write.close()

func save() -> void:
	var new_save = SaveData.new()
	var result = ResourceSaver.save(new_save,"res://Data/savedata/savegame.tres")
	print(self,": ",error_string(result))

func load_game(file_path: String = "res://Data/savedata/savegame.tres"):
	if not FileAccess.file_exists(file_path):
		print("Save file doesn't exist")
		return null
	var save_data = load(file_path) as SaveData
	if save_data == null:
		print("Failed to load save file")
		return null
	return save_data.save_data
