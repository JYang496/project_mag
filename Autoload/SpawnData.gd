extends Node

var level_list : Array

func _ready() -> void:
	load_all_spawn_data("res://Data/spawns/")
	#load_spawn_data()


func load_spawn_data() -> void:
	var level_spawn_info_1 = load("res://Data/spawns/1-1.tscn")
	level_list.append(level_spawn_info_1)


func load_all_spawn_data(path):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				print("Found directory: " + file_name)
			elif file_name.ends_with(".tscn"):
				print("Found file: " + file_name)
				var level_spawn_info = load("res://Data/spawns/" + file_name)
				level_list.append(level_spawn_info)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
