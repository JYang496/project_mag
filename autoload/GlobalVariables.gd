extends Node

@onready var ui : UI
@onready var mech_data : MechaDefinition
@onready var autosave_data : Dictionary
@onready var weapon_list : Dictionary
@onready var weapon_branch_list : Dictionary
@onready var weapon_passive_branch_list : Dictionary
@onready var mecha_list : Dictionary
@onready var economy_data : EconomyConfig
@onready var enemy_spawner : EnemySpawner
@onready var AUTOSAVE_PATH : String = "res://data/savedata/autosave.tres"
@onready var SPAWN_PATN : String = "res://data/spawns/"
var _new_game_battle_pending := false


func request_new_game_battle() -> void:
	_new_game_battle_pending = true


func consume_new_game_battle_request() -> bool:
	var was_pending := _new_game_battle_pending
	_new_game_battle_pending = false
	return was_pending


func reset_run_state() -> void:
	ui = null
	mech_data = null
	autosave_data = {}
	enemy_spawner = null
	_new_game_battle_pending = false

func clear_resource_cache() -> void:
	weapon_list = {}
	weapon_branch_list = {}
	weapon_passive_branch_list = {}
	mecha_list = {}
	economy_data = null

func reset_runtime_state() -> void:
	# Compatibility entry point. Runtime resets intentionally retain immutable definitions.
	reset_run_state()
