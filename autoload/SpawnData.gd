extends Node

const SPAWN_COMBAT_PROFILE_PATH := "res://data/spawns/spawn_combat_profile.tres"

var spawn_combat_profile: SpawnCombatProfile
var level_list: Array[LevelCombatPlan] = []

func _ready() -> void:
	load_all_spawn_data(GlobalVariables.SPAWN_PATN)

func load_all_spawn_data(_legacy_path: String = "") -> void:
	reload_spawn_combat_profile()

func reload_spawn_combat_profile() -> void:
	level_list.clear()
	spawn_combat_profile = load(SPAWN_COMBAT_PROFILE_PATH) as SpawnCombatProfile
	if spawn_combat_profile == null:
		push_warning("Failed to load spawn combat profile: %s" % SPAWN_COMBAT_PROFILE_PATH)
		return
	spawn_combat_profile.sanitize()
	for level_config in spawn_combat_profile.levels:
		if level_config == null:
			continue
		level_list.append(level_config)
	if level_list.is_empty():
		push_warning("Spawn combat profile has no level configs: %s" % SPAWN_COMBAT_PROFILE_PATH)

func get_spawn_combat_profile() -> SpawnCombatProfile:
	if spawn_combat_profile == null:
		reload_spawn_combat_profile()
	return spawn_combat_profile
