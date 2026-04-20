extends Node

@onready var ui : UI
@onready var mech_data : MechaDefinition
@onready var autosave_data : Dictionary
@onready var weapon_list : Dictionary
@onready var weapon_branch_list : Dictionary
@onready var mecha_list : Dictionary
@onready var economy_data : EconomyConfig
@onready var enemy_spawner : EnemySpawner
@onready var AUTOSAVE_PATH : String = "res://data/savedata/autosave.tres"
@onready var SPAWN_PATN : String = "res://data/spawns/"


func reset_runtime_state() -> void:
	ui = null
	mech_data = null
	autosave_data = {}
	weapon_list = {}
	weapon_branch_list = {}
	mecha_list = {}
	economy_data = null
	enemy_spawner = null
