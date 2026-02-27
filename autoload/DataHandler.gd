extends Node

var save_data : SaveData
const WEAPON_RESOURCE_PATHS := [
	"res://data/weapons/machine_gun.tres",
	"res://data/weapons/charged_blaster.tres",
	"res://data/weapons/Spear.tres",
	"res://data/weapons/shotgun.tres",
	"res://data/weapons/pistol.tres",
	"res://data/weapons/cyclone.tres",
	"res://data/weapons/orbit.tres",
	"res://data/weapons/rocket_luncher.tres",
	"res://data/weapons/laser.tres",
	"res://data/weapons/chainsaw_luncher.tres",
	"res://data/weapons/dash_blade.tres",
	"res://data/weapons/hammer.tres",
]
const MECHA_RESOURCE_PATHS := [
	"res://data/mechas/Prototype.tres",
	"res://data/mechas/Ranger.tres",
	"res://data/mechas/Melee.tres",
	"res://data/mechas/Collector.tres",
	"res://data/mechas/Turret.tres",
]

func _ready():
	load_game()
	load_weapon_data()
	load_mecha_data()

# This function is used for locate weapon file location which stored in data/weapons.
func load_weapon_data():
	var dir := DirAccess.open("res://data/weapons/")
	GlobalVariables.weapon_list = {}
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				_register_weapon_resource(load("res://data/weapons/%s" % file_name), "res://data/weapons/%s" % file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	if GlobalVariables.weapon_list.is_empty():
		for path: String in WEAPON_RESOURCE_PATHS:
			_register_weapon_resource(load(path), path)
	if GlobalVariables.weapon_list.is_empty():
		push_warning("No weapon data loaded. Check exported resources and script paths in data/weapons/*.tres.")

func load_mecha_data():
	GlobalVariables.mecha_list = {}
	var dir := DirAccess.open("res://data/mechas/")
	if dir:
		dir.list_dir_begin()
		var mecha_name = dir.get_next()
		while mecha_name != "":
			if mecha_name.ends_with(".tres"):
				_register_mecha_resource(load("res://data/mechas/%s" % mecha_name), "res://data/mechas/%s" % mecha_name)
			mecha_name = dir.get_next()
		dir.list_dir_end()
	if GlobalVariables.mecha_list.is_empty():
		for path: String in MECHA_RESOURCE_PATHS:
			_register_mecha_resource(load(path), path)
	if GlobalVariables.mecha_list.is_empty():
		push_warning("No mecha data loaded. Check exported resources and script paths in data/mechas/*.tres.")

func read_mecha_data(id: String) -> MechaDefinition:
	if GlobalVariables.mecha_list.is_empty():
		load_mecha_data()
	var data = GlobalVariables.mecha_list.get(id)
	if data == null:
		return null
	return data as MechaDefinition

func read_weapon_data(id: String):
	if GlobalVariables.weapon_list.is_empty():
		load_weapon_data()
	var data = GlobalVariables.weapon_list.get(str(id))
	if data == null:
		return null
	return data

func _register_weapon_resource(resource: Resource, source_path: String) -> void:
	if resource == null:
		push_warning("Failed to load weapon resource: %s" % source_path)
		return
	var weapon_id_value = resource.get("weapon_id")
	if weapon_id_value == null:
		push_warning("Weapon resource missing weapon_id: %s" % source_path)
		return
	var weapon_id := str(weapon_id_value)
	if weapon_id == "":
		push_warning("Weapon resource has empty weapon_id: %s" % source_path)
		return
	GlobalVariables.weapon_list[weapon_id] = resource

func _register_mecha_resource(resource: Resource, source_path: String) -> void:
	if resource == null:
		push_warning("Failed to load mecha resource: %s" % source_path)
		return
	var mecha_id_value = resource.get("mecha_id")
	if mecha_id_value == null:
		push_warning("Mecha resource missing mecha_id: %s" % source_path)
		return
	var mecha_id := str(mecha_id_value)
	if mecha_id == "":
		push_warning("Mecha resource has empty mecha_id: %s" % source_path)
		return
	GlobalVariables.mecha_list[mecha_id] = resource

# Return mecha autosave data, will be called in Start menu.
func read_autosave_mecha_data(id : String) -> Dictionary:
	if save_data == null:
		load_game()
	return save_data.mechas[id]

func save_game(data : SaveData = save_data, file_path: String = "res://data/savedata/autosave.tres") -> void:
	push_warning("save_game is disabled (read-only mode).")
	return

func new_save(file_path: String = "res://data/savedata/autosave.tres") -> void:
	push_warning("new_save is disabled (read-only mode).")
	if save_data == null:
		save_data = SaveData.new()
	return
	

func load_game(file_path: String = "res://data/savedata/autosave.tres") -> void:
	if not FileAccess.file_exists(file_path):
		print("Save file doesn't exist, create a new save file")
		new_save(file_path)
	else:
		save_data = load(file_path) as SaveData
	if save_data == null:
		print("Failed to load save file")
		return
