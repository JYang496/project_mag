extends Node

@onready var ui : UI
@onready var mech_data : MechaDefinition
@onready var autosave_data : Dictionary
@onready var weapon_list : Dictionary
@onready var mecha_list : Dictionary
@onready var enemy_spawner : EnemySpawner
@onready var AUTOSAVE_PATH : String = "res://Data/savedata/autosave.tres"
@onready var SPAWN_PATN : String = "res://data/spawns/"


func reset_runtime_state() -> void:
	ui = null
	mech_data = null
	autosave_data = {}
	enemy_spawner = null
