extends Node

@onready var ui : UI
@onready var mech_data : Dictionary
@onready var autosave_data : Dictionary
@onready var weapon_list : JSON
@onready var mecha_list : JSON
@onready var enemy_spawner : EnemySpawner
@onready var AUTOSAVE_PATH : String = "res://Data/savedata/autosave.tres"
@onready var SPAWN_PATN : String = "res://data/spawns/"
