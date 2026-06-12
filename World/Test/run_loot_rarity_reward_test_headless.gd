extends Node

const REWARD_MANAGER_SCENE := preload("res://Utility/reward_manager.tscn")
const MODULE_DIRECTORY_PATH := "res://Player/Weapons/Modules/"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DataHandler.load_weapon_data()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	RunRouteManager.reload_route_definitions()

	var reward_manager := REWARD_MANAGER_SCENE.instantiate() as BonusManager
	if reward_manager == null:
		push_error("LootRarityRewardTest: failed to instantiate reward manager.")
		get_tree().quit(1)
		return
	get_tree().root.add_child(reward_manager)

	var route := RunRouteManager.get_route_for_level(0)
	var options := reward_manager.build_reward_selection_options(0, route, 3)
	if options.size() != 3:
		push_error("LootRarityRewardTest: expected 3 reward options, got %d." % options.size())
		get_tree().quit(2)
		return
	if _has_duplicate_rewards(options):
		push_error("LootRarityRewardTest: generated duplicate rewards in one selection.")
		get_tree().quit(3)
		return
	for reward in options:
		if reward.get_rarity() == "":
			push_error("LootRarityRewardTest: reward has empty rarity.")
			get_tree().quit(4)
			return

	if not _assert_full_fuse_weapon_filter(reward_manager):
		get_tree().quit(5)
		return
	if not _assert_full_level_module_filter(reward_manager):
		get_tree().quit(6)
		return
	if not _assert_hidden_weapon_filter(reward_manager):
		get_tree().quit(7)
		return

	print("LootRarityRewardTest: PASS")
	get_tree().quit(0)

func _assert_hidden_weapon_filter(reward_manager: BonusManager) -> bool:
	var hidden_ids: PackedStringArray = []
	for weapon_id in DataHandler.get_weapon_ids():
		var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if weapon_def and weapon_def.is_hidden:
			hidden_ids.append(weapon_id)
	if hidden_ids.is_empty():
		return true
	var candidates: Array = reward_manager.call("_build_weapon_reward_candidates")
	for candidate in candidates:
		var candidate_id := str(candidate.get("id", ""))
		if hidden_ids.has(candidate_id):
			push_error("LootRarityRewardTest: hidden weapon id=%s was still in reward candidates." % candidate_id)
			return false
	return true

func _assert_full_fuse_weapon_filter(reward_manager: BonusManager) -> bool:
	var weapon_ids := DataHandler.get_weapon_ids()
	if weapon_ids.is_empty():
		push_error("LootRarityRewardTest: no weapon ids loaded.")
		return false
	var weapon_id := weapon_ids[0]
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null or weapon_def.scene == null:
		push_error("LootRarityRewardTest: weapon definition is invalid for id=%s." % weapon_id)
		return false
	var weapon := weapon_def.scene.instantiate() as Weapon
	if weapon == null:
		push_error("LootRarityRewardTest: failed to instantiate weapon id=%s." % weapon_id)
		return false
	weapon.fuse = int(weapon.FINAL_MAX_FUSE)
	PlayerData.player_weapon_list.append(weapon)
	var can_offer := bool(reward_manager.call("_can_offer_weapon_reward", weapon_id))
	PlayerData.player_weapon_list.erase(weapon)
	weapon.free()
	if can_offer:
		push_error("LootRarityRewardTest: max-fuse weapon was still offerable.")
		return false
	return true

func _assert_full_level_module_filter(reward_manager: BonusManager) -> bool:
	var module_path := _find_first_module_scene_path()
	if module_path == "":
		push_error("LootRarityRewardTest: no module scene found.")
		return false
	var module_scene := load(module_path) as PackedScene
	if module_scene == null:
		push_error("LootRarityRewardTest: failed to load module scene %s." % module_path)
		return false
	var module_instance := module_scene.instantiate() as Module
	if module_instance == null:
		push_error("LootRarityRewardTest: failed to instantiate module scene %s." % module_path)
		return false
	module_instance.set_module_level(Module.MAX_LEVEL)
	InventoryData.temporary_modules.append(module_instance)
	var can_offer := bool(reward_manager.call("_can_offer_module_reward", module_path))
	InventoryData.temporary_modules.erase(module_instance)
	module_instance.free()
	if can_offer:
		push_error("LootRarityRewardTest: max-level module was still offerable.")
		return false
	return true

func _has_duplicate_rewards(options: Array[RewardInfo]) -> bool:
	var seen: Dictionary = {}
	for reward in options:
		var key := _reward_key(reward)
		if seen.has(key):
			return true
		seen[key] = true
	return false

func _reward_key(reward: RewardInfo) -> String:
	if reward.item_id.strip_edges() != "":
		return "weapon:%s" % reward.item_id.strip_edges()
	if reward.module_scene != null:
		return "module:%s" % str(reward.module_scene.resource_path)
	return "chip:%d" % int(reward.total_chip_value)

func _find_first_module_scene_path() -> String:
	var dir := DirAccess.open(MODULE_DIRECTORY_PATH)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".tscn") and file_name != "wmod_base.tscn":
			dir.list_dir_end()
			return MODULE_DIRECTORY_PATH + file_name
		file_name = dir.get_next()
	dir.list_dir_end()
	return ""
