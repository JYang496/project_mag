extends Node

var level_list : Array[LevelSpawnConfig] = []
const SPAWN_RESOURCE_PATHS := [
	"res://data/spawns/1-1.tres",
	"res://data/spawns/1-2.tres",
	"res://data/spawns/1-3.tres",
	"res://data/spawns/1-4.tres",
	"res://data/spawns/1-5.tres",
	"res://data/spawns/1-6.tres",
	"res://data/spawns/1-7.tres",
]

func _ready() -> void:
	load_all_spawn_data(GlobalVariables.SPAWN_PATN)

func load_all_spawn_data(path: String) -> void:
	level_list.clear()
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Unable to open spawn directory: %s" % path)
		return
	var spawn_files : Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".tres"):
			spawn_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	spawn_files.sort()
	for spawn_file in spawn_files:
		_register_spawn_resource(load(path + spawn_file), path + spawn_file)
	if level_list.is_empty():
		for spawn_path: String in SPAWN_RESOURCE_PATHS:
			_register_spawn_resource(load(spawn_path), spawn_path)
	if level_list.is_empty():
		push_warning("No spawn data loaded. Check exported resources in data/spawns/*.tres")

func _register_spawn_resource(resource: Resource, source_path: String) -> void:
	if resource == null:
		push_warning("Failed to load spawn resource: %s" % source_path)
		return
	if resource.get("spawns") == null:
		push_warning("Spawn resource missing 'spawns' field: %s" % source_path)
		return
	level_list.append(resource)

