extends Node

const SPAWN_BALANCE_PROFILE_PATH := "res://data/spawns/spawn_balance_profile.tres"
const LEVEL_COMBAT_BUDGET_PROFILE_PATH := "res://data/spawns/level_combat_budget_profile.tres"

var spawn_balance_profile: Resource
var level_combat_budget_profile: Resource
var level_list: Array[LevelSpawnConfig] = []

func _ready() -> void:
	load_all_spawn_data(GlobalVariables.SPAWN_PATN)

func load_all_spawn_data(_legacy_path: String = "") -> void:
	reload_spawn_balance_profile()
	reload_level_combat_budget_profile()

func reload_spawn_balance_profile() -> void:
	level_list.clear()
	spawn_balance_profile = load(SPAWN_BALANCE_PROFILE_PATH) as Resource
	if spawn_balance_profile == null:
		push_warning("Failed to load spawn balance profile: %s" % SPAWN_BALANCE_PROFILE_PATH)
		return
	spawn_balance_profile.call("sanitize")
	var configs_variant: Variant = spawn_balance_profile.get("level_configs")
	if not (configs_variant is Array):
		push_warning("Spawn balance profile level_configs is invalid: %s" % SPAWN_BALANCE_PROFILE_PATH)
		return
	for level_config in configs_variant as Array:
		if level_config == null:
			continue
		level_list.append(level_config)
	if level_list.is_empty():
		push_warning("Spawn balance profile has no level configs: %s" % SPAWN_BALANCE_PROFILE_PATH)

func get_spawn_balance_profile() -> Resource:
	if spawn_balance_profile == null:
		reload_spawn_balance_profile()
	return spawn_balance_profile

func reload_level_combat_budget_profile() -> void:
	level_combat_budget_profile = load(LEVEL_COMBAT_BUDGET_PROFILE_PATH) as Resource
	if level_combat_budget_profile == null:
		push_warning("Failed to load level combat budget profile: %s" % LEVEL_COMBAT_BUDGET_PROFILE_PATH)
		return
	if level_combat_budget_profile.has_method("sanitize"):
		level_combat_budget_profile.call("sanitize")

func get_level_combat_budget_profile() -> Resource:
	if level_combat_budget_profile == null:
		reload_level_combat_budget_profile()
	return level_combat_budget_profile
