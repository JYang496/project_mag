extends Node2D
class_name BonusManager

const LOOT_BOX = preload("res://Objects/loots/loot_box.tscn")

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
	if level_index < 0 or level_index >= instance_list.size():
		push_warning("get_adjusted_rewards_for_level ignored invalid level index: %d" % level_index)
		return []
	var resolved_route := route_def if route_def != null else RunRouteManager.get_route_for_level(level_index)
	var rewards_at_level: Array = instance_list[level_index]
	var adjusted: Array[RewardInfo] = []
	for reward_entry in rewards_at_level:
		if not (reward_entry is RewardInfo):
			push_warning("Reward entry is invalid and was skipped at level index %d." % level_index)
			continue
		adjusted.append(_build_route_adjusted_reward(reward_entry as RewardInfo, resolved_route))
	return adjusted

func build_reward_selection_options(
	level_index: int,
	route_def: RunRouteDefinition = null,
	option_count_override: int = -1
) -> Array[RewardInfo]:
	var resolved_route := route_def if route_def != null else RunRouteManager.get_route_for_level(level_index)
	var options := get_adjusted_rewards_for_level(level_index, resolved_route)
	if options.is_empty():
		var fallback := RewardInfo.new()
		fallback.total_chip_value = max(1, resolved_route.fallback_reward_chip_value if resolved_route else 5)
		options.append(fallback)
	options.shuffle()
	var target_count := option_count_override
	if target_count <= 0:
		target_count = resolved_route.reward_option_count if resolved_route else 3
	target_count = clampi(target_count, 1, 6)
	while options.size() < target_count:
		var filler := RewardInfo.new()
		filler.total_chip_value = max(1, (resolved_route.fallback_reward_chip_value if resolved_route else 5) + options.size() * 2)
		options.append(filler)
	if options.size() > target_count:
		options.resize(target_count)
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
		var weapon_id := DataHandler.resolve_weapon_id_for_standalone(reward.item_id.strip_edges())
		if PlayerData.player and is_instance_valid(PlayerData.player):
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
	if route_def == null:
		return reward
	reward.total_chip_value = max(0, int(round(float(reward.total_chip_value) * route_def.reward_chip_multiplier)))
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		reward.item_level = max(1, reward.item_level + int(route_def.reward_item_level_bonus))
	if reward.module_scene:
		reward.module_level = _sanitize_module_level(reward.module_level + int(route_def.reward_module_level_bonus))
	return reward

func _sanitize_module_level(level_value: int) -> int:
	return clampi(level_value, 1, Module.MAX_LEVEL)

func _show_reward_granted_message(reward: RewardInfo) -> void:
	var ui := GlobalVariables.ui
	if ui == null or not is_instance_valid(ui) or not ui.has_method("show_item_message"):
		return
	var chunks: PackedStringArray = []
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		chunks.append("Weapon #%s Lv.%d" % [reward.item_id, reward.item_level])
	if reward.module_scene:
		var module_name := reward.module_scene.resource_path.get_file().get_basename().replace("_", " ").capitalize()
		chunks.append("Module %s Lv.%d" % [module_name, _sanitize_module_level(reward.module_level)])
	if reward.total_chip_value > 0:
		chunks.append("EXP +%d" % reward.total_chip_value)
	if chunks.is_empty():
		return
	ui.show_item_message("Reward: %s" % " + ".join(chunks), 2.1)
