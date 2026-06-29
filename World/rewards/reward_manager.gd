extends Node2D
class_name BonusManager

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const MODULE_DIRECTORY_PATH := "res://Player/Weapons/Modules/"
const REWARD_TYPE_WEAPON := "weapon"
const REWARD_TYPE_MODULE := "module"
const REWARD_TYPE_ECONOMY := "economy"
const MAX_REWARD_ROLL_ATTEMPTS: int = 64
const DROP_SCENE := preload("res://Objects/loots/drop.tscn")
const DROP_ITEM_SCENE := preload("res://Objects/loots/drop_item.tscn")

var _last_phase := ""
var _module_candidate_cache: Array[Dictionary] = []
var _module_candidate_cache_ready := false
var _module_candidate_cache_building := false

func _ready() -> void:
	_last_phase = PhaseManager.current_state()
	if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.connect(_on_phase_changed)
	call_deferred("_warm_module_candidate_cache")

func _exit_tree() -> void:
	if PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.disconnect(_on_phase_changed)

func _on_phase_changed(new_phase: String) -> void:
	var completed_battle := _last_phase == PhaseManager.BATTLE and new_phase == PhaseManager.PREPARE
	var leaving_rest_area := _last_phase == PhaseManager.PREPARE and new_phase == PhaseManager.BATTLE
	_last_phase = new_phase
	if leaving_rest_area:
		_settle_unclaimed_battle_drops()
	if completed_battle:
		call_deferred("_spawn_completed_battle_drops")

func _spawn_completed_battle_drops() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	var level_index := maxi(int(PhaseManager.current_level) - 1, 0)
	var route_def := RunRouteManager.get_route_for_level(level_index)
	var rewards := build_completed_battle_drop_rewards(level_index, route_def)
	if rewards.is_empty():
		return
	var origin := _resolve_rest_area_drop_origin()
	for reward in rewards:
		_spawn_reward_drop(reward, origin)

func build_completed_battle_drop_rewards(
	_level_index: int,
	route_def: RunRouteDefinition = null
) -> Array[RewardInfo]:
	var economy := _get_economy_config()
	var weapon_candidates := _build_all_weapon_drop_candidates()
	var module_candidates := _build_all_module_drop_candidates()
	var drop_weapon := not weapon_candidates.is_empty() \
		and randf() < clampf(economy.battle_drop_weapon_chance, 0.0, 1.0)
	var drop_module := not module_candidates.is_empty() \
		and randf() < clampf(economy.battle_drop_module_chance, 0.0, 1.0)
	if not drop_weapon and not drop_module:
		if weapon_candidates.is_empty():
			drop_module = not module_candidates.is_empty()
		elif module_candidates.is_empty():
			drop_weapon = true
		else:
			var total_chance := economy.battle_drop_weapon_chance + economy.battle_drop_module_chance
			drop_weapon = total_chance <= 0.0 \
				or randf() < economy.battle_drop_weapon_chance / total_chance
			drop_module = not drop_weapon
	var rewards: Array[RewardInfo] = []
	if drop_weapon:
		var weapon_candidate := _pick_weighted_candidate(weapon_candidates, {})
		var weapon_reward := _build_reward_from_candidate(weapon_candidate, route_def)
		if weapon_reward:
			rewards.append(weapon_reward)
	if drop_module:
		var module_candidate := _pick_weighted_candidate(module_candidates, {})
		var module_reward := _build_reward_from_candidate(module_candidate, route_def)
		if module_reward:
			rewards.append(module_reward)
	return rewards

func _build_all_weapon_drop_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for weapon_id in DataHandler.get_weapon_ids():
		var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if weapon_def == null or weapon_def.is_hidden or weapon_def.get_drop_weight() <= 0.0:
			continue
		candidates.append({
			"type": REWARD_TYPE_WEAPON,
			"id": weapon_id,
			"rarity": weapon_def.get_rarity(),
			"weight": weapon_def.get_drop_weight(),
		})
	return candidates

func _build_all_module_drop_candidates() -> Array[Dictionary]:
	if _module_candidate_cache_ready:
		return _copy_module_candidate_cache(false)
	return _build_module_candidates_uncached(false)

func _build_module_candidates_uncached(filter_unavailable_rewards: bool) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var dir := DirAccess.open(MODULE_DIRECTORY_PATH)
	if dir == null:
		return candidates
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn") and file_name != "wmod_base.tscn":
			var scene_path := MODULE_DIRECTORY_PATH + file_name
			var candidate := _build_module_candidate_from_scene(scene_path, filter_unavailable_rewards)
			if not candidate.is_empty():
				candidates.append(candidate)
		file_name = dir.get_next()
	dir.list_dir_end()
	return candidates

func _warm_module_candidate_cache() -> void:
	if _module_candidate_cache_ready or _module_candidate_cache_building:
		return
	_module_candidate_cache_building = true
	var candidates: Array[Dictionary] = []
	var scene_paths := _collect_module_candidate_scene_paths()
	for scene_path in scene_paths:
		var candidate := _build_module_candidate_from_scene(scene_path, false)
		if not candidate.is_empty():
			candidates.append(candidate)
		if is_inside_tree():
			await get_tree().process_frame
	_module_candidate_cache = candidates
	_module_candidate_cache_ready = true
	_module_candidate_cache_building = false

func _collect_module_candidate_scene_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	var dir := DirAccess.open(MODULE_DIRECTORY_PATH)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn") and file_name != "wmod_base.tscn":
			paths.append(MODULE_DIRECTORY_PATH + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return paths

func _copy_module_candidate_cache(filter_unavailable_rewards: bool) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for candidate in _module_candidate_cache:
		var scene_path := str(candidate.get("scene_path", ""))
		if filter_unavailable_rewards and not _can_offer_module_reward(scene_path):
			continue
		output.append(candidate.duplicate(false))
	return output

func _build_module_candidate_from_scene(scene_path: String, filter_unavailable_rewards: bool) -> Dictionary:
	if filter_unavailable_rewards and not _can_offer_module_reward(scene_path):
		return {}
	var module_scene := load(scene_path) as PackedScene
	if module_scene == null:
		return {}
	var module_instance := module_scene.instantiate() as Module
	if module_instance == null:
		return {}
	var weight := module_instance.get_drop_weight()
	var rarity: String = module_instance.get_rarity()
	module_instance.free()
	if weight <= 0.0:
		return {}
	return {
		"type": REWARD_TYPE_MODULE,
		"scene": module_scene,
		"scene_path": scene_path,
		"rarity": rarity,
		"weight": weight,
	}

func _resolve_rest_area_drop_origin() -> Vector2:
	for node in get_tree().get_nodes_in_group("rest_area"):
		if node and is_instance_valid(node) and node.has_method("get_spawn_position"):
			return node.call("get_spawn_position") as Vector2
	return PlayerData.player.global_position \
		if PlayerData.player and is_instance_valid(PlayerData.player) \
		else global_position

func _spawn_reward_drop(reward: RewardInfo, origin: Vector2) -> void:
	if reward == null:
		return
	var drop := DROP_SCENE.instantiate()
	drop.drop = DROP_ITEM_SCENE
	drop.spawn_global_position = origin
	drop.settle_unclaimed_on_battle_start = true
	if reward.module_scene:
		drop.module_scene = reward.module_scene
		drop.module_level = _sanitize_module_level(reward.module_level)
	elif reward.item_id != "":
		drop.item_id = reward.item_id
		drop.level = maxi(reward.item_level, 1)
	else:
		drop.queue_free()
		return
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(drop)
	else:
		add_sibling(drop)

func _settle_unclaimed_battle_drops() -> void:
	for drop_item in get_tree().get_nodes_in_group(&"unclaimed_battle_rewards"):
		if drop_item and is_instance_valid(drop_item) and drop_item.has_method("settle_unclaimed"):
			drop_item.call("settle_unclaimed")

func create_loot_box() -> void:
	if PhaseManager.current_state() == PhaseManager.BATTLE:
		_request_battle_reward_selection()
		return
	var level_index := int(PhaseManager.current_level)
	if not RunRouteManager.should_spawn_prepare_loot_for_level(level_index):
		return

func _request_battle_reward_selection() -> void:
	var level_index := int(PhaseManager.current_level)
	if not RunRouteManager.should_spawn_prepare_loot_for_level(level_index):
		return
	var route_def := RunRouteManager.get_route_for_level(level_index)
	var reward_options := build_reward_selection_options(level_index, route_def)
	if reward_options.is_empty():
		return
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui) or not ui.has_method("request_reward_selection"):
		grant_reward_immediately(reward_options[0])
		return
	var route_name := route_def.display_name if route_def else "Battle Reward"
	var opened: bool = bool(ui.request_reward_selection(
		route_name,
		reward_options,
		Callable(self, "_on_battle_reward_selected"),
		Callable(),
		false
	))
	if not opened:
		grant_reward_immediately(reward_options[0])

func _on_battle_reward_selected(reward: RewardInfo) -> void:
	grant_reward_immediately(reward)

func build_reward_selection_options(
	level_index: int,
	route_def: RunRouteDefinition = null,
	option_count_override: int = -1
) -> Array[RewardInfo]:
	var resolved_route := route_def if route_def != null else RunRouteManager.get_route_for_level(level_index)
	var target_count := option_count_override
	if target_count <= 0:
		target_count = resolved_route.reward_option_count if resolved_route else 3
	target_count = clampi(target_count, 1, 6)
	var weapon_candidates := _build_weapon_reward_candidates()
	var module_candidates: Array[Dictionary] = []
	if _get_economy_config().reward_module_options_enabled:
		module_candidates = _build_module_reward_candidates()
	var options: Array[RewardInfo] = []
	var selected_keys: Dictionary = {}
	var guaranteed_reward := _build_guaranteed_weapon_progress_reward(selected_keys)
	if guaranteed_reward != null:
		options.append(guaranteed_reward)
	while options.size() < target_count:
		var reward := _roll_reward_option(weapon_candidates, module_candidates, selected_keys, resolved_route)
		if reward == null:
			reward = _build_fallback_economy_reward(options.size(), resolved_route)
		selected_keys[_get_reward_key(reward)] = true
		options.append(reward)
	return options

func grant_reward_immediately(reward: RewardInfo) -> bool:
	if reward == null:
		return false
	var granted_any := false
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		granted_any = _grant_weapon_upgrade_reward(reward)
	if reward.total_chip_value > 0:
		var chip_value: int = max(0, int(reward.total_chip_value))
		PlayerData.player_exp += chip_value
		PlayerData.round_chip_collected += chip_value
		granted_any = true
	if reward.gold_value > 0:
		var gold_value: int = max(0, int(reward.gold_value))
		PlayerData.player_gold += gold_value
		PlayerData.run_gold_earned += gold_value
		granted_any = true
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var weapon_id := reward.item_id.strip_edges()
		if PlayerData.player and is_instance_valid(PlayerData.player):
			var outcome: Dictionary = PlayerData.player.try_auto_fuse_weapon_obtain(weapon_id)
			if str(outcome.get("result", "")) == "not_applicable":
				var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
				var weapon: Weapon
				if weapon_def and weapon_def.scene:
					weapon = weapon_def.scene.instantiate() as Weapon
				if weapon:
					weapon.level = max(1, int(reward.item_level))
					var ui = GlobalVariables.ui
					if ui and is_instance_valid(ui) and ui.has_method("request_weapon_replacement"):
						ui.call("request_weapon_replacement", weapon, false)
					else:
						PlayerData.player.create_weapon(weapon)
			granted_any = true
		else:
			var weapon_def = DataHandler.read_weapon_data(weapon_id)
			if weapon_def and weapon_def.scene:
				var weapon = weapon_def.scene.instantiate()
				weapon.level = max(1, int(reward.item_level))
				var ui = GlobalVariables.ui
				if ui and is_instance_valid(ui) and ui.has_method("request_weapon_replacement"):
					ui.call("request_weapon_replacement", weapon)
				else:
					weapon.queue_free()
				granted_any = true
	if reward.module_scene:
		var module_instance := reward.module_scene.instantiate() as Module
		if module_instance:
			module_instance.set_module_level(_sanitize_module_level(int(reward.module_level)))
			var module_result := InventoryData.obtain_module(module_instance)
			if str(module_result.get("result", "")) == "stored":
				var ui = GlobalVariables.ui
				if ui and is_instance_valid(ui) and ui.has_method("request_module_equip_selection"):
					ui.call(
						"request_module_equip_selection",
						module_instance,
						Callable(),
						true
					)
			granted_any = true
	if granted_any:
		_show_reward_granted_message(reward)
	return granted_any

func _build_weapon_reward_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for weapon_id in DataHandler.get_weapon_ids():
		if not _can_offer_weapon_reward(weapon_id):
			continue
		var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if weapon_def == null:
			continue
		if weapon_def.is_hidden:
			continue
		var weight := weapon_def.get_drop_weight()
		if weight <= 0.0:
			continue
		candidates.append({
			"type": REWARD_TYPE_WEAPON,
			"id": weapon_id,
			"rarity": weapon_def.get_rarity(),
			"weight": weight,
		})
	return candidates

func _build_module_reward_candidates() -> Array[Dictionary]:
	if _module_candidate_cache_ready:
		return _copy_module_candidate_cache(true)
	return _build_module_candidates_uncached(true)

func _build_module_reward_candidate(scene_path: String) -> Dictionary:
	return _build_module_candidate_from_scene(scene_path, true)

func _roll_reward_option(
	weapon_candidates: Array[Dictionary],
	module_candidates: Array[Dictionary],
	selected_keys: Dictionary,
	route_def: RunRouteDefinition
) -> RewardInfo:
	var economy := _get_economy_config()
	if randf() < economy.get_reward_economy_option_chance() and not _has_selected_economy_reward(selected_keys):
		var economy_reward := _build_fallback_economy_reward(selected_keys.size(), route_def)
		if not selected_keys.has(_get_reward_key(economy_reward)):
			return economy_reward
	if not economy.reward_module_options_enabled or module_candidates.is_empty():
		return _roll_reward_from_type(REWARD_TYPE_WEAPON, weapon_candidates, module_candidates, selected_keys, route_def)
	var prefer_weapon := randf() < economy.get_reward_weapon_option_chance()
	var first_type := REWARD_TYPE_WEAPON if prefer_weapon else REWARD_TYPE_MODULE
	var second_type := REWARD_TYPE_MODULE if prefer_weapon else REWARD_TYPE_WEAPON
	var reward := _roll_reward_from_type(first_type, weapon_candidates, module_candidates, selected_keys, route_def)
	if reward != null:
		return reward
	return _roll_reward_from_type(second_type, weapon_candidates, module_candidates, selected_keys, route_def)

func _roll_reward_from_type(
	reward_type: String,
	weapon_candidates: Array[Dictionary],
	module_candidates: Array[Dictionary],
	selected_keys: Dictionary,
	route_def: RunRouteDefinition
) -> RewardInfo:
	var candidates := weapon_candidates if reward_type == REWARD_TYPE_WEAPON else module_candidates
	for _attempt in range(MAX_REWARD_ROLL_ATTEMPTS):
		var candidate := _pick_weighted_candidate(candidates, selected_keys)
		if candidate.is_empty():
			return null
		var key := _get_candidate_key(candidate)
		if selected_keys.has(key):
			continue
		var reward := _build_reward_from_candidate(candidate, route_def)
		if reward == null:
			continue
		selected_keys[key] = true
		return reward
	return null

func _pick_weighted_candidate(candidates: Array[Dictionary], selected_keys: Dictionary) -> Dictionary:
	var total_weight := 0.0
	for candidate in candidates:
		if selected_keys.has(_get_candidate_key(candidate)):
			continue
		total_weight += maxf(0.0, float(candidate.get("weight", 0.0)))
	if total_weight <= 0.0:
		return {}
	var roll := randf() * total_weight
	for candidate in candidates:
		if selected_keys.has(_get_candidate_key(candidate)):
			continue
		roll -= maxf(0.0, float(candidate.get("weight", 0.0)))
		if roll <= 0.0:
			return candidate
	return {}

func _build_reward_from_candidate(candidate: Dictionary, route_def: RunRouteDefinition) -> RewardInfo:
	var reward := RewardInfo.new()
	reward.rarity = RARITY_UTIL.normalize(str(candidate.get("rarity", RARITY_UTIL.COMMON)))
	match str(candidate.get("type", "")):
		REWARD_TYPE_WEAPON:
			reward.item_id = str(candidate.get("id", ""))
			reward.item_level = max(1, 1 + (int(route_def.reward_item_level_bonus) if route_def else 0))
		REWARD_TYPE_MODULE:
			reward.module_scene = candidate.get("scene", null) as PackedScene
			reward.module_level = _sanitize_module_level(1 + (int(route_def.reward_module_level_bonus) if route_def else 0))
		_:
			return null
	return reward

func _build_fallback_economy_reward(option_index: int, _route_def: RunRouteDefinition) -> RewardInfo:
	var economy := _get_economy_config()
	var fallback := RewardInfo.new()
	fallback.reward_kind = RewardInfo.KIND_ECONOMY
	fallback.total_chip_value = economy.get_reward_economy_exp()
	fallback.gold_value = economy.get_reward_economy_gold()
	fallback.rarity = RARITY_UTIL.COMMON
	fallback.reward_key_override = "economy:%d" % max(option_index, 0)
	return fallback

func _build_guaranteed_weapon_progress_reward(selected_keys: Dictionary) -> RewardInfo:
	var equipped_weapons := _get_valid_equipped_weapons()
	var upgrade_candidates: Array[Weapon] = []
	var fuse_candidates: Array[Weapon] = []
	for weapon in equipped_weapons:
		if _can_upgrade_weapon(weapon):
			upgrade_candidates.append(weapon)
		elif _can_fuse_weapon(weapon):
			fuse_candidates.append(weapon)
	if not upgrade_candidates.is_empty():
		var upgrade_weapon: Weapon = upgrade_candidates.pick_random()
		var reward := RewardInfo.new()
		reward.configure_weapon_upgrade(upgrade_weapon)
		reward.rarity = _get_weapon_rarity_by_instance(upgrade_weapon)
		_mark_reward_selected(reward, selected_keys)
		_mark_weapon_id_selected(DataHandler.get_weapon_id_from_instance(upgrade_weapon), selected_keys)
		return reward
	if not fuse_candidates.is_empty():
		var fuse_weapon: Weapon = fuse_candidates.pick_random()
		var weapon_id: String = DataHandler.get_weapon_id_from_instance(fuse_weapon)
		var reward := RewardInfo.new()
		reward.item_id = weapon_id
		reward.item_level = 1
		reward.rarity = _get_weapon_rarity_by_instance(fuse_weapon)
		_mark_reward_selected(reward, selected_keys)
		return reward
	var fallback := _build_fallback_economy_reward(0, null)
	_mark_reward_selected(fallback, selected_keys)
	return fallback

func _get_valid_equipped_weapons() -> Array[Weapon]:
	var result: Array[Weapon] = []
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon != null and is_instance_valid(weapon):
			result.append(weapon)
	return result

func _can_upgrade_weapon(weapon: Weapon) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	return int(weapon.level) < int(weapon.max_level)

func _can_fuse_weapon(weapon: Weapon) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if DataHandler.get_weapon_id_from_instance(weapon).strip_edges() == "":
		return false
	return int(weapon.fuse) < max(1, int(weapon.FINAL_MAX_FUSE))

func _grant_weapon_upgrade_reward(reward: RewardInfo) -> bool:
	var weapon := reward.get_target_weapon()
	if weapon == null or not is_instance_valid(weapon):
		return false
	if not _can_upgrade_weapon(weapon):
		return false
	var next_level := mini(int(weapon.level) + 1, int(weapon.max_level))
	if weapon.has_method("set_level"):
		weapon.call("set_level", next_level)
	else:
		weapon.level = next_level
		if weapon.has_method("calculate_status"):
			weapon.call("calculate_status")
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui):
		if GlobalVariables.ui.upgrade_management_controller:
			GlobalVariables.ui.upgrade_management_controller.update_upg()
		if GlobalVariables.ui.has_method("refresh_border"):
			GlobalVariables.ui.refresh_border()
	return true

func _get_weapon_rarity_by_instance(weapon: Weapon) -> String:
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null:
		return RARITY_UTIL.COMMON
	return weapon_def.get_rarity()

func _mark_reward_selected(reward: RewardInfo, selected_keys: Dictionary) -> void:
	selected_keys[_get_reward_key(reward)] = true

func _mark_weapon_id_selected(weapon_id: String, selected_keys: Dictionary) -> void:
	var normalized_id := weapon_id.strip_edges()
	if normalized_id != "":
		selected_keys["weapon:%s" % normalized_id] = true

func _has_selected_economy_reward(selected_keys: Dictionary) -> bool:
	for key_variant in selected_keys.keys():
		if str(key_variant).begins_with("economy:"):
			return true
	return false

func _get_reward_key(reward: RewardInfo) -> String:
	if reward == null:
		return "null"
	if reward.reward_key_override.strip_edges() != "":
		return reward.reward_key_override
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		return "upgrade:%s" % str(reward.target_weapon_id)
	if reward.item_id.strip_edges() != "":
		return "weapon:%s" % reward.item_id.strip_edges()
	if reward.module_scene != null:
		return "module:%s" % str(reward.module_scene.resource_path)
	if reward.gold_value > 0 or reward.total_chip_value > 0:
		return "economy:%d:%d" % [int(reward.total_chip_value), int(reward.gold_value)]
	return "reward:%s" % str(reward)

func _get_candidate_key(candidate: Dictionary) -> String:
	match str(candidate.get("type", "")):
		REWARD_TYPE_WEAPON:
			return "weapon:%s" % str(candidate.get("id", ""))
		REWARD_TYPE_MODULE:
			return "module:%s" % str(candidate.get("scene_path", ""))
		_:
			return "unknown:%s" % str(candidate)

func _can_offer_weapon_reward(weapon_id: String) -> bool:
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if _is_full_fuse_weapon_match(weapon, weapon_id):
			return false
	return true

func _is_full_fuse_weapon_match(weapon: Weapon, weapon_id: String) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if DataHandler.get_weapon_id_from_instance(weapon) != weapon_id:
		return false
	return int(weapon.fuse) >= max(1, int(weapon.FINAL_MAX_FUSE))

func _can_offer_module_reward(scene_path: String) -> bool:
	for module_ref in InventoryData.temporary_modules:
		var module_instance := module_ref as Module
		if _is_full_level_module_match(module_instance, scene_path):
			return false
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon) or weapon.modules == null:
			continue
		for child in weapon.modules.get_children():
			var equipped_module := child as Module
			if _is_full_level_module_match(equipped_module, scene_path):
				return false
	return true

func _is_full_level_module_match(module_instance: Module, scene_path: String) -> bool:
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	if str(module_instance.scene_file_path) != scene_path:
		return false
	return int(module_instance.module_level) >= Module.MAX_LEVEL

func _sanitize_module_level(level_value: int) -> int:
	return clampi(level_value, 1, Module.MAX_LEVEL)

func _get_economy_config() -> EconomyConfig:
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data
	return EconomyConfig.new()

func _show_reward_granted_message(reward: RewardInfo) -> void:
	var ui := GlobalVariables.ui
	if ui == null or not is_instance_valid(ui) or not ui.has_method("show_item_message"):
		return
	var chunks: PackedStringArray = []
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		var weapon_name := reward.target_weapon_name
		if weapon_name.strip_edges() == "":
			weapon_name = LocalizationManager.tr_key("ui.branch.weapon", "Weapon")
		chunks.append(LocalizationManager.tr_format(
			"ui.reward.weapon_upgrade",
			{
				"name": weapon_name,
				"from": int(reward.target_weapon_from_level),
				"to": int(reward.target_weapon_to_level),
			},
			"Upgrade %s Lv.%d -> Lv.%d" % [
				weapon_name,
				int(reward.target_weapon_from_level),
				int(reward.target_weapon_to_level),
			]
		))
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var weapon_name := LocalizationManager.get_weapon_name_by_id(reward.item_id, reward.item_id)
		var weapon_text := LocalizationManager.tr_format(
			"ui.reward.weapon",
			{"id": weapon_name, "level": reward.item_level},
			"Weapon %s Lv.%d" % [weapon_name, reward.item_level]
		)
		if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("predict_auto_fuse_weapon_obtain"):
			var outcome: Dictionary = PlayerData.player.predict_auto_fuse_weapon_obtain(reward.item_id)
			weapon_text = _format_weapon_obtain_prediction(weapon_text, weapon_name, outcome)
		chunks.append(weapon_text)
	if reward.module_scene:
		var module_name := _get_module_name_from_reward_scene(reward.module_scene)
		var level := _sanitize_module_level(reward.module_level)
		chunks.append(
			LocalizationManager.tr_format(
				"ui.reward.module",
				{"name": module_name, "level": level},
				"Module %s Lv.%d" % [module_name, level]
			)
		)
	if reward.total_chip_value > 0:
		chunks.append(
			LocalizationManager.tr_format(
				"ui.reward.exp",
				{"value": reward.total_chip_value},
				"EXP +%d" % reward.total_chip_value
			)
		)
	if reward.gold_value > 0:
		chunks.append(
			LocalizationManager.tr_format(
				"ui.reward.gold",
				{"value": reward.gold_value},
				"Gold +%d" % reward.gold_value
			)
		)
	if chunks.is_empty():
		return
	var content := " + ".join(chunks)
	ui.show_item_message(
		LocalizationManager.tr_format("ui.reward.message", {"content": content}, "Reward: %s" % content),
		2.1
	)

func _get_module_name_from_reward_scene(module_scene: PackedScene) -> String:
	if module_scene == null:
		return ""
	var scene_path := str(module_scene.resource_path)
	var module_id := scene_path.get_file().get_basename() if scene_path != "" else ""
	var fallback := module_id.replace("_", " ").capitalize()
	if module_id == "":
		return fallback
	return LocalizationManager.tr_key("module.%s.name" % module_id, fallback)

func _format_weapon_obtain_prediction(base_text: String, weapon_name: String, outcome: Dictionary) -> String:
	var result_type := str(outcome.get("result", "not_applicable"))
	match result_type:
		"fused":
			return LocalizationManager.tr_format(
				"ui.weapon.obtain_preview.fuse",
				{"name": weapon_name, "fuse": int(outcome.get("target_fuse", 1))},
				"%s -> Fuse %d" % [weapon_name, int(outcome.get("target_fuse", 1))]
			)
		"converted_to_gold":
			return LocalizationManager.tr_format(
				"ui.weapon.obtain_preview.gold",
				{"name": weapon_name, "gold": int(outcome.get("gold", 0))},
				"%s -> +%d Gold" % [weapon_name, int(outcome.get("gold", 0))]
			)
		_:
			return base_text
