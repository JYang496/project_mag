extends Node

var spawn_list : Array

func _ready() -> void:
	load_spawn_data()


func load_spawn_data() -> void:
	var level_spawn_info_1 = load("res://Data/spawns/1-1.tscn")
	var level_spawn_info_2 = load("res://Data/spawns/1-2.tscn")
	var level_spawn_info_3 = load("res://Data/spawns/1-3.tscn")
	spawn_list.append(level_spawn_info_1)
	spawn_list.append(level_spawn_info_2)
	spawn_list.append(level_spawn_info_3)
