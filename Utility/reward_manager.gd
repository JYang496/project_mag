extends Node2D
class_name BonusManager

const LOOT_BOX = preload("res://Objects/loots/loot_box.tscn")
const RARITY_UTIL := preload("res://data/LootRarity.gd")
const MODULE_DIRECTORY_PATH := "res://Player/Weapons/Modules/"
const REWARD_TYPE_WEAPON := "weapon"
const REWARD_TYPE_MODULE := "module"
const WEAPON_REWARD_CHANCE: float = 0.5
const MAX_REWARD_ROLL_ATTEMPTS: int = 64

var instance_list: Array = []

func _ready() -> void:
	rebuild_rewards_cache()
	if not PhaseManager.is_connected("pre_enter_prepare_loot", Callable(self, "create_loot_box")):
		PhaseManager.connect("pre_enter_prepare_loot", Callable(self, "create_loot_box"))

func create_loot_box() -> void:
	var level_index := int(PhaseManager.current_level)
	if not RunRouteManager.should_spawn_prepare_loot_for_level(level_index):
		return
	var route_def := RunRouteManager.get_route_for_level(level_index)
	create_loot_box_for_level(level_index, route_def, false)

func rebuild_rewards_cache() -> void:
	instance_list.clear()
	for level_config in SpawnData.level_list:
		if level_config == null:
			instance_list.append([])
			continue
		var ins: LevelSpawnConfig = level_config.duplicate(true)
		instance_list.append(ins.rewards.duplicate(true))

func create_loot_box_for_level(
	level_index: int,
	route_def: RunRouteDefinition = null,
	resolve_immediately: bool = false
) -> int:
	var rewards := get_adjusted_rewards_for_level(level_index, route_def)
	if rewards.is_empty():
		return 0
	var spawned_count := 0
	for reward in rewards:
		if reward == null:
			continue
		if _spawn_loot_box_from_reward(reward, resolve_immediately):
			spawned_count += 1
	return spawned_count

func get_adjusted_rewards_for_level(level_index: int, route_def: RunRouteDefinition = null) -> Array[RewardInfo]:
	if instance_list.is_empty():
		push_warning("get_adjusted_rewards_for_level ignored because reward cache is empty.")
		return []
	if level_index < 0:
		push_warning("get_adjusted_rewards_for_level ignored invalid level index: %d" % level_index)
		return []
	var wrapped_level_index := posmod(level_index, instance_list.size())
	var resolved_route := route_def if route_def != null else RunRouteManager.get_route_for_level(level_index)
	var rewards_at_level: Array = instance_list[wrapped_level_index]
	var adjusted: Array[RewardInfo] = []
	for reward_entry in rewards_at_level:
		if not (reward_entry is RewardInfo):
			push_warning("Reward entry is invalid and was skipped at level index %d." % wrapped_level_index)
			continue
		adjusted.append(_build_route_adjusted_reward(reward_entry as RewardInfo, resolved_route))
	return adjusted

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
	var module_candidates := _build_module_reward_candidates()
	var options: Array[RewardInfo] = []
	var selected_keys: Dictionary = {}
	for _i in range(target_count):
		var reward := _roll_reward_option(weapon_candidates, module_candidates, selected_keys, resolved_route)
		if reward == null:
			reward = _build_fallback_chip_reward(options.size(), resolved_route)
		options.append(reward)
	return options

func grant_reward_immediately(reward: RewardInfo) -> bool:
	if reward == null:
		return false
	var granted_any := false
	if reward.total_chip_value > 0:
		var chip_value: int = max(0, int(reward.total_chip_value))
		PlayerData.player_exp += chip_value
		PlayerData.round_chip_collected += chip_value
		granted_any = true
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var weapon_id := reward.item_id.strip_edges()
		if PlayerData.player and is_instance_valid(PlayerData.player):
			var outcome: Dictionary = PlayerData.player.try_auto_fuse_weapon_obtain(weapon_id)
			if str(outcome.get("result", "")) == "not_applicable":
				PlayerData.player.create_weapon(weapon_id, max(1, int(reward.item_level)))
			granted_any = true
		else:
			var weapon_def = DataHandler.read_weapon_data(weapon_id)
			if weapon_def and weapon_def.scene:
				var weapon = weapon_def.scene.instantiate()
				weapon.level = max(1, int(reward.item_level))
				InventoryData.inventory_slots.append(weapon)
				granted_any = true
	if reward.module_scene:
		var module_instance := reward.module_scene.instantiate() as Module
		if module_instance:
			module_instance.set_module_level(_sanitize_module_level(int(reward.module_level)))
			InventoryData.obtain_module(module_instance)
			granted_any = true
	if granted_any:
		_show_reward_granted_message(reward)
	return granted_any

func _spawn_loot_box_from_reward(reward: RewardInfo, resolve_immediately: bool = false) -> bool:
	var lb_ins: Node2D = LOOT_BOX.instantiate() as Node2D
	if lb_ins == null:
		return false
	if PlayerData.player and is_instance_valid(PlayerData.player):
		lb_ins.position = PlayerData.player.position
	else:
		lb_ins.position = Vector2.ZERO
	lb_ins.item_id = reward.item_id
	lb_ins.item_lvl = max(0, int(reward.item_level))
	lb_ins.module_scene = reward.module_scene
	lb_ins.module_level = _sanitize_module_level(int(reward.module_level))
	lb_ins.total_value = max(0, int(reward.total_chip_value))
	lb_ins.resolve_immediately = resolve_immediately
	add_child(lb_ins)
	return true

func _build_route_adjusted_reward(base_reward: RewardInfo, route_def: RunRouteDefinition) -> RewardInfo:
	var reward := RewardInfo.new()
	reward.item_id = base_reward.item_id
	reward.item_level = max(0, int(base_reward.item_level))
	reward.module_scene = base_reward.module_scene
	reward.module_level = _sanitize_module_level(int(base_reward.module_level))
	reward.total_chip_value = max(0, int(base_reward.total_chip_value))
	reward.rarity = base_reward.get_rarity()
	if route_def == null:
		return reward
	reward.total_chip_value = max(0, int(round(float(reward.total_chip_value) * route_def.reward_chip_multiplier)))
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		reward.item_level = max(1, reward.item_level + int(route_def.reward_item_level_bonus))
	if reward.module_scene:
		reward.module_level = _sanitize_module_level(reward.module_level + int(route_def.reward_module_level_bonus))
	return reward

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
	var candidates: Array[Dictionary] = []
	var dir := DirAccess.open(MODULE_DIRECTORY_PATH)
	if dir == null:
		push_warning("Unable to open module reward directory: %s" % MODULE_DIRECTORY_PATH)
		return candidates
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".tscn") and file_name != "wmod_base.tscn":
			var scene_path := MODULE_DIRECTORY_PATH + file_name
			var candidate := _build_module_reward_candidate(scene_path)
			if not candidate.is_empty():
				candidates.append(candidate)
		file_name = dir.get_next()
	dir.list_dir_end()
	return candidates

func _build_module_reward_candidate(scene_path: String) -> Dictionary:
	if not _can_offer_module_reward(scene_path):
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

func _roll_reward_option(
	weapon_candidates: Array[Dictionary],
	module_candidates: Array[Dictionary],
	selected_keys: Dictionary,
	route_def: RunRouteDefinition
) -> RewardInfo:
	var prefer_weapon := randf() < WEAPON_REWARD_CHANCE
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

func _build_fallback_chip_reward(option_index: int, route_def: RunRouteDefinition) -> RewardInfo:
	var fallback := RewardInfo.new()
	var base_value: int = max(1, route_def.fallback_reward_chip_value if route_def else 5)
	fallback.total_chip_value = base_value + option_index * 2
	fallback.rarity = RARITY_UTIL.COMMON
	return fallback

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
	for weapon_ref in InventoryData.inventory_slots:
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
	for module_ref in InventoryData.moddule_slots:
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

func _show_reward_granted_message(reward: RewardInfo) -> void:
	var ui := GlobalVariables.ui
	if ui == null or not is_instance_valid(ui) or not ui.has_method("show_item_message"):
		return
	var chunks: PackedStringArray = []
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
