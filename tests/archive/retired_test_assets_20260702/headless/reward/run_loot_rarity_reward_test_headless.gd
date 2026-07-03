extends Node

const REWARD_MANAGER_SCENE := preload("res://World/rewards/reward_manager.tscn")
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

	if not _assert_module_option_gate(reward_manager, route):
		get_tree().quit(5)
		return
	if not _assert_weapon_progress_floor_with_module_draft(reward_manager, route):
		get_tree().quit(6)
		return
	if not _assert_standard_rewards_do_not_include_task_rewards(reward_manager, route):
		get_tree().quit(10)
		return
	if not _assert_full_fuse_weapon_filter(reward_manager):
		get_tree().quit(7)
		return
	if not _assert_full_level_module_filter(reward_manager):
		get_tree().quit(8)
		return
	if not _assert_hidden_weapon_filter(reward_manager):
		get_tree().quit(9)
		return

	print("LootRarityRewardTest: PASS")
	get_tree().quit(0)

func _assert_module_option_gate(reward_manager: BonusManager, route: RunRouteDefinition) -> bool:
	var economy := EconomyConfig.new()
	economy.reward_module_options_enabled = false
	economy.reward_weapon_option_chance = 0.0
	economy.reward_economy_option_chance = 0.0
	GlobalVariables.economy_data = economy
	var closed_options := reward_manager.build_reward_selection_options(0, route, 3)
	for reward in closed_options:
		if reward != null and reward.module_scene != null:
			push_error("LootRarityRewardTest: module option appeared while module draft was disabled.")
			return false
	economy.reward_module_options_enabled = true
	var open_options := reward_manager.build_reward_selection_options(0, route, 3)
	if not _has_module_reward(open_options):
		push_error("LootRarityRewardTest: module option did not appear when module draft was enabled and preferred.")
		return false
	return true

func _assert_weapon_progress_floor_with_module_draft(reward_manager: BonusManager, route: RunRouteDefinition) -> bool:
	var weapon := _instantiate_first_rewardable_weapon()
	if weapon == null:
		push_error("LootRarityRewardTest: failed to create weapon progress fixture.")
		return false
	weapon.level = 1
	weapon.refresh_max_level_from_data()
	PlayerData.player_weapon_list.append(weapon)
	var economy := EconomyConfig.new()
	economy.reward_module_options_enabled = true
	economy.reward_weapon_option_chance = 0.0
	economy.reward_economy_option_chance = 0.0
	GlobalVariables.economy_data = economy
	var options := reward_manager.build_reward_selection_options(0, route, 3)
	PlayerData.player_weapon_list.erase(weapon)
	weapon.free()
	if not _has_weapon_progress_reward(options):
		push_error("LootRarityRewardTest: module draft removed the guaranteed weapon progress option.")
		return false
	if not _has_module_reward(options):
		push_error("LootRarityRewardTest: module draft did not include a module beside weapon progress.")
		return false
	return true

func _assert_standard_rewards_do_not_include_task_rewards(reward_manager: BonusManager, route: RunRouteDefinition) -> bool:
	var economy := EconomyConfig.new()
	economy.reward_module_options_enabled = true
	economy.reward_weapon_option_chance = 0.0
	economy.reward_economy_option_chance = 0.0
	GlobalVariables.economy_data = economy
	var options := reward_manager.build_reward_selection_options(0, route, 3)
	for reward in options:
		if reward != null and reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
			push_error("LootRarityRewardTest: standard battle reward included a task module.")
			return false
		if reward != null and reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
			push_error("LootRarityRewardTest: standard battle reward included a cell effect.")
			return false
	return true

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
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		return "upgrade:%s" % reward.target_weapon_id
	if reward.item_id.strip_edges() != "":
		return "weapon:%s" % reward.item_id.strip_edges()
	if reward.module_scene != null:
		return "module:%s" % str(reward.module_scene.resource_path)
	return "chip:%d" % int(reward.total_chip_value)

func _has_module_reward(options: Array[RewardInfo]) -> bool:
	for reward in options:
		if reward != null and reward.module_scene != null:
			return true
	return false

func _has_weapon_progress_reward(options: Array[RewardInfo]) -> bool:
	for reward in options:
		if reward == null:
			continue
		if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
			return true
		if reward.item_id.strip_edges() != "":
			return true
	return false

func _instantiate_first_rewardable_weapon() -> Weapon:
	for weapon_id in DataHandler.get_weapon_ids():
		var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if weapon_def == null or weapon_def.scene == null:
			continue
		var weapon := weapon_def.scene.instantiate() as Weapon
		if weapon != null:
			return weapon
	return null

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
