extends Node

var save_data : SaveData

func _ready():
	load_game()
	load_weapon_data()
	load_mecha_data()

# This function is used for locate weapon file location which stored in weapons.json.
#func load_weapon_data() -> void:
	#var file = FileAccess.open("res://Data/weapons.json", FileAccess.READ)
	#var stringdata = file.get_as_text()
	#GlobalVariables.weapon_list = JSON.new()
	#GlobalVariables.weapon_list.parse(stringdata)
	#file.close()
func load_weapon_data():
	var dir := DirAccess.open("res://Data/weapons")
	GlobalVariables.weapon_list = {}
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var def := load("res://Data/weapons/%s" % file_name) as WeaponDefinition
				if def and def.weapon_id != "":
					GlobalVariables.weapon_list[def.weapon_id] = def
			file_name = dir.get_next()
		dir.list_dir_end()

# Load mecha stats for each level
func load_mecha_data() -> void:
	var file = FileAccess.open("res://Data/mechas.json", FileAccess.READ)
	var stringdata = file.get_as_text()
	GlobalVariables.mecha_list = JSON.new()
	GlobalVariables.mecha_list.parse(stringdata)
	file.close()

# Return mecha fixed data, will be called in Start menu.
func read_mecha_data(id : String) -> Dictionary:
	return GlobalVariables.mecha_list.data[id]

# Return mecha autosave data, will be called in Start menu.
func read_autosave_mecha_data(id : String) -> Dictionary:
	if save_data == null:
		load_game()
	return save_data.mechas[id]

func save_game(data : SaveData = save_data, file_path: String = "res://Data/savedata/autosave.tres") -> void:
	data.mechas[str(PlayerData.select_mecha_id)]["current_exp"] = str(PlayerData.player_exp)
	data.mechas[str(PlayerData.select_mecha_id)]["current_level"] = str(PlayerData.player_level)
	data.weapons = []
	data.sub = "0"
	data.game_level = str(PhaseManager.current_level)
	var result = ResourceSaver.save(data,file_path)
	print(self,": ",error_string(result))

func new_save(file_path: String = "res://Data/savedata/autosave.tres") -> void:
	save_data = SaveData.new()
	var result = ResourceSaver.save(save_data, file_path)
	print(self,": ",error_string(result))
	

func load_game(file_path: String = "res://Data/savedata/autosave.tres") -> void:
	if not FileAccess.file_exists(file_path):
		print("Save file doesn't exist, create a new save file")
		new_save(file_path)
	else:
		save_data = load(file_path) as SaveData
	if save_data == null:
		print("Failed to load save file")
		return
