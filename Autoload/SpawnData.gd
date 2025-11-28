extends Node

var level_list : Array[LevelSpawnConfig] = []

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
		var level_spawn_info : LevelSpawnConfig = load(path + spawn_file)
		if level_spawn_info:
			level_list.append(level_spawn_info)
