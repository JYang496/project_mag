extends Node

const BattleContractDefinition = preload("res://Combat/battle_contract/BattleContractDefinition.gd")
const EnhancedContractDefinition = preload("res://Combat/battle_contract/EnhancedContractDefinition.gd")
const BattleContractCombatPort = preload("res://Combat/battle_contract/BattleContractCombatPort.gd")
const ELIMINATION := preload("res://data/battle_contracts/elimination.tres")
const SURVIVAL := preload("res://data/battle_contracts/survival.tres")
const OPERATION := preload("res://data/battle_contracts/operation.tres")
const CONTAINMENT := preload("res://data/battle_contracts/containment.tres")
const EXTRACTION := preload("res://data/battle_contracts/extraction.tres")
const REWARD := preload("res://data/battle_contracts/reward.tres")
const CONTRACT_COIN_SCENE := preload("res://Objects/loots/coin.tscn")
const REST_PROTOCOL := preload("res://data/battle_contracts/rest.tres")
const FINALE := preload("res://data/battle_contracts/finale.tres")
const ELIMINATION_RUNTIME := preload("res://Combat/battle_contract/runtime/elimination_contract_runtime.gd")
const SURVIVAL_RUNTIME := preload("res://Combat/battle_contract/runtime/survival_contract_runtime.gd")
const OPERATION_RUNTIME := preload("res://Combat/battle_contract/runtime/operation_contract_runtime.gd")
const CONTAINMENT_RUNTIME := preload("res://Combat/battle_contract/runtime/containment_contract_runtime.gd")
const EXTRACTION_RUNTIME := preload("res://Combat/battle_contract/runtime/extraction_contract_runtime.gd")
const REWARD_RUNTIME := preload("res://Combat/battle_contract/runtime/reward_contract_runtime.gd")
const ENHANCED_ELIMINATION := preload("res://data/enhanced_contracts/elimination_overclock.tres")
const ENHANCED_SURVIVAL := preload("res://data/enhanced_contracts/survival_elite_anchor.tres")
const ENHANCED_CONTAINMENT := preload("res://data/enhanced_contracts/containment_mortar_barrage.tres")
const ENHANCED_EXTRACTION := preload("res://data/enhanced_contracts/extraction_navigation_keys.tres")

signal state_changed(state: StringName)
signal offer_changed(options: Array[BattleContractDefinition])
signal contract_selected(definition: BattleContractDefinition)
signal contract_completed(snapshot: Dictionary)
signal combat_event(event_name: StringName, snapshot: Dictionary)
signal performance_reward_granted(summary: Dictionary)
signal enhanced_selection_changed(definition: Resource, reward: Dictionary)
signal enhanced_reward_granted(summary: Dictionary)

const IDLE := &"idle"
const OFFERED := &"offered"
const SELECTED := &"selected"
const ACTIVE := &"active"
const COMPLETED := &"completed"
const VALID_STATES: Array[StringName] = [IDLE, OFFERED, SELECTED, ACTIVE, COMPLETED]
const REWARD_CONTRACT_THIRD_SLOT_CHANCE := 0.25

var state: StringName = IDLE
var current_options: Array[BattleContractDefinition] = []
var selected_contract: BattleContractDefinition
var selected_enhanced_contract: EnhancedContractDefinition
var selected_enhanced_reward: Dictionary = {}
var _enhanced_reward_by_contract: Dictionary = {}
var runtime_snapshot: Dictionary = {}
var last_selected_id: StringName = &""
var consecutive_selection_count := 0
var missed_offer_counts: Dictionary = {}
var restored_selection_pending := false
var _reward_offer_roll_level := -1
var _reward_offer_available := false

var _combat_port: BattleContractCombatPort
var _completion_guard := false
var _rng := RandomNumberGenerator.new()
var _runtime: RefCounted
var _history_before_offer: Dictionary = {}
var _reward_settled := false
var _enhanced_reward_settled := false
var _pending_success_settlement := false
var _staged_completion_granted := 0
var _staged_milestones: Dictionary = {}
var _restored_contract_gold := 0
const STATE_PATH := "user://battle_contract_state.json"

func _ready() -> void:
	_rng.randomize()
	for definition in _get_catalog():
		if definition.contract_id in [&"reward", &"rest", &"finale"]:
			continue
		missed_offer_counts[definition.contract_id] = 0
	_load_persistent_state()

func request_offer() -> Array[BattleContractDefinition]:
	if _combat_port == null or _combat_port.is_boss_battle():
		return []
	_history_before_offer = get_history_snapshot()
	var capabilities := _combat_port.get_battlefield_capabilities()
	var allowed := _combat_port.get_allowed_contracts()
	var level_index := maxi(PhaseManager.current_level, 0)
	var candidates: Array[BattleContractDefinition] = []
	for definition in _get_catalog():
		if definition.contract_id in [&"reward", &"rest", &"finale"]:
			continue
		if not allowed.is_empty() and definition.contract_id not in allowed:
			continue
		if not is_contract_unlocked_for_level(definition, level_index):
			continue
		var required_capability := str(definition.parameters.get("required_capability", ""))
		if not required_capability.is_empty() and not bool(capabilities.get(required_capability, false)):
			continue
		if definition.contract_id == last_selected_id and consecutive_selection_count >= 2:
			continue
		candidates.append(definition)
	if candidates.size() < 2:
		push_warning("Battle contract candidates below two; falling back to elimination and survival.")
		candidates = [ELIMINATION, SURVIVAL]
	var target_option_count := 2
	var max_long_form_options := get_max_long_form_options_for_level(level_index)
	var options: Array[BattleContractDefinition] = []
	while options.size() < target_option_count and not candidates.is_empty():
		var picked := _pick_weighted(candidates)
		options.append(picked)
		candidates.erase(picked)
		if picked.long_form:
			var selected_long_count := options.filter(func(option): return option.long_form).size()
			if selected_long_count >= max_long_form_options:
				candidates = candidates.filter(func(option): return not option.long_form)
	if PhaseManager.is_rest_protocol_available():
		options.append(REST_PROTOCOL)
	elif _is_reward_offer_available_for_current_level():
		options.append(REWARD)
	set_offer(options)
	PhaseManager.record_pacing_event(&"protocol_panel_opened", {"option_ids": options.map(func(option): return str(option.contract_id))})
	return current_options.duplicate()

func request_fixed_offer(contract_id: StringName) -> bool:
	if _combat_port == null or _combat_port.is_boss_battle():
		return false
	var definition := get_definition(contract_id)
	if definition == null or not is_contract_unlocked_for_level(definition, PhaseManager.current_level):
		return false
	if not set_offer([definition]):
		return false
	return select_contract(definition)

func get_definition(contract_id: StringName) -> BattleContractDefinition:
	for definition in _get_catalog():
		if definition != null and definition.contract_id == contract_id:
			return definition
	return null

func get_enhanced_definition(contract_id: StringName) -> EnhancedContractDefinition:
	for definition in _get_enhanced_catalog():
		if definition != null and definition.contract_id == contract_id \
				and PhaseManager.current_level >= definition.minimum_level_index:
			return definition
	return null

func set_selected_contract_enhanced(enabled: bool) -> bool:
	if selected_contract == null:
		return false
	if not enabled:
		selected_enhanced_contract = null
		selected_enhanced_reward = {}
		enhanced_selection_changed.emit(null, {})
		return true
	var definition := get_enhanced_definition(selected_contract.contract_id)
	if definition == null:
		return false
	selected_enhanced_contract = definition
	var contract_key := str(definition.contract_id)
	if not _enhanced_reward_by_contract.has(contract_key):
		_enhanced_reward_by_contract[contract_key] = _roll_enhanced_reward(definition)
	selected_enhanced_reward = (_enhanced_reward_by_contract.get(contract_key, {}) as Dictionary).duplicate(true)
	enhanced_selection_changed.emit(selected_enhanced_contract, selected_enhanced_reward.duplicate(true))
	return not selected_enhanced_reward.is_empty()

func is_selected_contract_enhanced() -> bool:
	return selected_enhanced_contract != null

func get_selected_enhanced_reward_line() -> String:
	match str(selected_enhanced_reward.get("type", "")):
		"compatible_module": return LocalizationManager.tr_key("battle_contract.enhanced.reward.module", "Random compatible module")
		"equipped_weapon_core":
			return LocalizationManager.tr_key("battle_contract.enhanced.reward.core", "Weapon core: {name}").replace("{name}", str(selected_enhanced_reward.get("weapon_name", "Weapon")))
		"gold_pack":
			return LocalizationManager.tr_key("battle_contract.enhanced.reward.gold", "Gold +{amount}").replace("{amount}", str(int(selected_enhanced_reward.get("amount", 0))))
	return LocalizationManager.tr_key("battle_contract.enhanced.reward.random", "Random bonus reward")

func is_contract_unlocked_for_level(definition: BattleContractDefinition, level_index: int) -> bool:
	if definition == null:
		return false
	var safe_level := maxi(level_index, 0)
	if safe_level < maxi(definition.minimum_offer_level_index, 0):
		return false
	return true

func get_max_long_form_options_for_level(level_index: int) -> int:
	var safe_level := maxi(level_index, 0)
	var unlocked_long_contracts := _get_catalog().filter(func(definition):
		return definition.long_form and safe_level >= maxi(definition.minimum_offer_level_index, 0)
	)
	if unlocked_long_contracts.is_empty():
		return 0
	var pairable_count := unlocked_long_contracts.filter(func(definition):
		return definition.multiple_long_offer_level_index >= 0 \
			and safe_level >= definition.multiple_long_offer_level_index
	).size()
	return 2 if pairable_count >= 2 else 1

func confirm_selection() -> bool:
	if state != SELECTED or selected_contract == null:
		return false
	if selected_contract.contract_id == &"rest":
		restored_selection_pending = false
		_save_persistent_state()
		return true
	if selected_contract.contract_id == last_selected_id:
		consecutive_selection_count += 1
	else:
		last_selected_id = selected_contract.contract_id
		consecutive_selection_count = 1
	for definition in _get_catalog():
		if definition.contract_id == &"rest":
			continue
		if current_options.has(definition):
			missed_offer_counts[definition.contract_id] = 0
		else:
			missed_offer_counts[definition.contract_id] = int(missed_offer_counts.get(definition.contract_id, 0)) + 1
	restored_selection_pending = false
	_save_persistent_state()
	PhaseManager.record_pacing_event(&"contract_selected", {"contract_id": str(selected_contract.contract_id)})
	return true

func cancel_offer() -> void:
	if state in [OFFERED, SELECTED]:
		reset_runtime_state()

func rollback_confirmed_selection() -> void:
	if not _history_before_offer.is_empty():
		_apply_history(_history_before_offer)
		_save_persistent_state()
	reset_runtime_state()

func abort_current_contract(_snapshot: Dictionary = {}) -> void:
	rollback_confirmed_selection()

func is_boss_battle() -> bool:
	return _combat_port != null and _combat_port.is_boss_battle()

func get_battle_intro_snapshot() -> Dictionary:
	return _combat_port.get_battle_intro_snapshot() if _combat_port != null else {}

func start_current_battle() -> bool:
	if _combat_port == null:
		return false
	_combat_port.request_start_spawning()
	return true

func _get_catalog() -> Array[BattleContractDefinition]:
	return [ELIMINATION, SURVIVAL, OPERATION, CONTAINMENT, EXTRACTION, REWARD, REST_PROTOCOL, FINALE]

func _get_enhanced_catalog() -> Array[EnhancedContractDefinition]:
	return [ENHANCED_ELIMINATION, ENHANCED_SURVIVAL, ENHANCED_CONTAINMENT, ENHANCED_EXTRACTION]

func _pick_weighted(candidates: Array[BattleContractDefinition]) -> BattleContractDefinition:
	var total := 0.0
	for definition in candidates:
		total += _effective_weight(definition)
	var roll := _rng.randf_range(0.0, total)
	for definition in candidates:
		roll -= _effective_weight(definition)
		if roll <= 0.0:
			return definition
	return candidates.back()

func _effective_weight(definition: BattleContractDefinition) -> float:
	var result := maxf(definition.weight, 0.01)
	if definition.contract_id == last_selected_id:
		result *= 0.35
	if int(missed_offer_counts.get(definition.contract_id, 0)) >= 2:
		result *= 1.75
	return result

func _is_reward_offer_available_for_current_level() -> bool:
	var level := maxi(PhaseManager.current_level, 0)
	if _reward_offer_roll_level != level:
		_reward_offer_roll_level = level
		_reward_offer_available = _rng.randf() < REWARD_CONTRACT_THIRD_SLOT_CHANCE
	return _reward_offer_available

func set_offer(options: Array[BattleContractDefinition]) -> bool:
	if state == ACTIVE:
		return false
	current_options.assign(options.filter(func(option): return option != null))
	selected_contract = null
	selected_enhanced_contract = null
	selected_enhanced_reward = {}
	_enhanced_reward_by_contract.clear()
	runtime_snapshot = {}
	_completion_guard = false
	_set_state(OFFERED if not current_options.is_empty() else IDLE)
	offer_changed.emit(current_options.duplicate())
	return state == OFFERED

func select_contract(definition: BattleContractDefinition) -> bool:
	if state not in [OFFERED, SELECTED] or definition == null or not current_options.has(definition):
		return false
	if selected_contract != definition:
		selected_enhanced_contract = null
		selected_enhanced_reward = {}
	selected_contract = definition
	_set_state(SELECTED)
	contract_selected.emit(selected_contract)
	return true

func activate_contract(snapshot: Dictionary = {}) -> bool:
	if state != SELECTED or selected_contract == null:
		return false
	if selected_contract.contract_id == &"rest":
		return false
	if _combat_port != null:
		var economy: EconomyConfig = GlobalVariables.economy_data
		var plan := economy.get_contract_gold_plan(selected_contract.contract_id, maxi(PhaseManager.current_level, 0))
		_combat_port.request_configure_contract_economy(float(plan.get("kill_gold_multiplier", 1.0)))
	runtime_snapshot = snapshot.duplicate(true)
	_completion_guard = false
	_reward_settled = false
	_enhanced_reward_settled = false
	_pending_success_settlement = false
	_staged_completion_granted = 0
	_staged_milestones.clear()
	_set_state(ACTIVE)
	_start_selected_runtime()
	return true

func update_runtime_snapshot(snapshot: Dictionary) -> void:
	if state == ACTIVE:
		runtime_snapshot = snapshot.duplicate(true)
		_grant_staged_completion_gold(runtime_snapshot, false)

func complete_contract(snapshot: Dictionary = {}) -> bool:
	if state != ACTIVE or _completion_guard:
		return false
	_completion_guard = true
	runtime_snapshot = snapshot.duplicate(true)
	_set_state(COMPLETED)
	_save_persistent_state()
	contract_completed.emit(runtime_snapshot.duplicate(true))
	return true

func reset_runtime_state() -> void:
	_stop_runtime()
	current_options.clear()
	selected_contract = null
	selected_enhanced_contract = null
	selected_enhanced_reward = {}
	_enhanced_reward_by_contract.clear()
	runtime_snapshot = {}
	_completion_guard = false
	_pending_success_settlement = false
	_reward_settled = false
	_enhanced_reward_settled = false
	_staged_completion_granted = 0
	_staged_milestones.clear()
	_restored_contract_gold = 0
	_set_state(IDLE)

func _start_selected_runtime() -> void:
	_stop_runtime()
	match selected_contract.contract_id:
		&"elimination": _runtime = ELIMINATION_RUNTIME.new()
		&"finale": _runtime = ELIMINATION_RUNTIME.new()
		&"survival": _runtime = SURVIVAL_RUNTIME.new()
		&"operation": _runtime = OPERATION_RUNTIME.new()
		&"containment": _runtime = CONTAINMENT_RUNTIME.new()
		&"extraction": _runtime = EXTRACTION_RUNTIME.new()
		&"reward": _runtime = REWARD_RUNTIME.new()
	if _runtime == null:
		return
	_runtime.snapshot_changed.connect(update_runtime_snapshot)
	_runtime.completed.connect(_on_runtime_completed)
	var runtime_parameters := selected_contract.parameters.duplicate(true)
	if selected_enhanced_contract != null:
		for key in selected_enhanced_contract.parameters:
			runtime_parameters[key] = selected_enhanced_contract.parameters[key]
		runtime_parameters["enhanced_id"] = selected_enhanced_contract.enhanced_id
	_runtime.call("start", _combat_port, runtime_parameters)

func _stop_runtime() -> void:
	if _runtime == null:
		return
	_runtime.call("stop")
	_runtime = null

func _on_runtime_completed(snapshot: Dictionary) -> void:
	_stop_runtime()
	_grant_staged_completion_gold(snapshot, true)
	if not complete_contract(snapshot):
		return
	_pending_success_settlement = true
	await get_tree().create_timer(1.0, false).timeout
	if _combat_port != null and PhaseManager.current_state() == PhaseManager.BATTLE:
		_combat_port.request_finish_battle(snapshot)

func has_pending_success_settlement() -> bool:
	return _pending_success_settlement or _restored_contract_gold > 0

func settle_pending_success_rewards() -> bool:
	if _restored_contract_gold > 0:
		if spawn_contract_gold(_restored_contract_gold) != _restored_contract_gold:
			return false
		_restored_contract_gold = 0
	if not _pending_success_settlement or state != COMPLETED:
		return false
	_settle_performance_reward(runtime_snapshot)
	_settle_enhanced_reward()
	if not _reward_settled or (selected_enhanced_contract != null and not selected_enhanced_reward.is_empty() and not _enhanced_reward_settled):
		return false
	_pending_success_settlement = false
	return true

func _grant_staged_completion_gold(snapshot: Dictionary, completed_successfully: bool) -> void:
	if state != ACTIVE or selected_contract == null or not PlayerData.gold_supply_enabled:
		return
	var contract_id := selected_contract.contract_id
	var milestone_count := 0
	var reached := 0
	match contract_id:
		&"survival":
			milestone_count = 4
			var duration := maxf(float(snapshot.get("duration_sec", 0.0)), 1.0)
			var ratio := clampf(1.0 - float(snapshot.get("remaining_sec", duration)) / duration, 0.0, 1.0)
			reached = clampi(int(floor(ratio * 4.0 + 0.0001)), 0, 4)
		&"operation":
			milestone_count = maxi(int(snapshot.get("total_beacons", 2)), 1)
			reached = clampi(int(snapshot.get("current_beacon", 0)), 0, milestone_count)
		&"containment":
			milestone_count = maxi(int(snapshot.get("total_rifts", 3)), 1)
			reached = clampi(int(snapshot.get("sealed_count", 0)), 0, milestone_count)
		&"extraction":
			milestone_count = 4
			var duration := maxf(float(snapshot.get("duration_sec", 0.0)), 1.0)
			var hold_ratio := clampf(1.0 - float(snapshot.get("remaining_sec", duration)) / duration, 0.0, 1.0)
			reached = clampi(int(floor(hold_ratio * 4.0 + 0.0001)), 0, 3)
			if completed_successfully:
				reached = 4
		_:
			return
	if reached <= 0:
		return
	var economy: EconomyConfig = GlobalVariables.economy_data
	var completion_budget := int(economy.get_contract_gold_plan(contract_id, maxi(PhaseManager.current_level, 0)).get("completion_gold", 0))
	for milestone in range(1, reached + 1):
		var key := "%s:%d:%d" % [str(contract_id), maxi(PhaseManager.current_level, 0), milestone]
		if _staged_milestones.has(key):
			continue
		var cumulative := int(floor(float(completion_budget * milestone) / float(milestone_count)))
		var amount := maxi(cumulative - _staged_completion_granted, 0)
		if amount > 0:
			var spawned := spawn_contract_gold(amount)
			if spawned != amount:
				return
			_staged_completion_granted += spawned
		_staged_milestones[key] = true

func _settle_performance_reward(result: Dictionary) -> void:
	if _reward_settled:
		return
	_reward_settled = true
	var economy: EconomyConfig = GlobalVariables.economy_data
	var level := maxi(PhaseManager.current_level - (1 if PhaseManager.current_state() == PhaseManager.SETTLEMENT else 0), 0)
	var contract_id := StringName(result.get("contract_id", &""))
	if contract_id == &"reward":
		return
	var plan := economy.get_contract_gold_plan(contract_id, level)
	var completion_gold := int(plan.get("completion_gold", 0))
	var performance_cap := int(plan.get("performance_gold_cap", 0))
	var ratio := 0.0
	match str(contract_id):
		"elimination": ratio = clampf((float(result.get("standard_duration_sec", 45.0)) - float(result.get("actual_completion_sec", 45.0))) / maxf(float(result.get("standard_duration_sec", 45.0)), 1.0), 0.0, 1.0)
		"survival": ratio = 0.0
		"operation": ratio = clampf(float(result.get("actual_progress_sec", 0.0)) / maxf(float(result.get("available_progress_sec", 1.0)), 1.0), 0.0, 1.0)
		"containment", "extraction":
			ratio = clampf(float(result.get("performance_ratio", 0.0)), 0.0, 1.0)
	var performance_gold := clampi(int(round(float(performance_cap) * ratio)), 0, performance_cap)
	var completion_remainder := maxi(completion_gold - _staged_completion_granted, 0)
	var amount := maxi(completion_remainder + performance_gold, 0)
	if amount <= 0:
		return
	if spawn_contract_gold(amount) != amount:
		_reward_settled = false

func _settle_enhanced_reward() -> void:
	if _enhanced_reward_settled or selected_enhanced_contract == null or selected_enhanced_reward.is_empty():
		return
	_enhanced_reward_settled = true
	var reward := selected_enhanced_reward.duplicate(true)
	var granted := false
	match str(reward.get("type", "")):
		"gold_pack":
			var amount := maxi(int(reward.get("amount", 0)), 0)
			if amount > 0:
				granted = spawn_contract_gold(amount) == amount
				if not granted:
					_enhanced_reward_settled = false
		"equipped_weapon_core":
			granted = bool(InventoryData.add_weapon_cores(reward.get("core_tags", []), 1).get("ok", false))
		"compatible_module":
			var manager := _resolve_reward_manager()
			if manager != null and manager.has_method("grant_enhanced_module"):
				granted = bool(manager.call("grant_enhanced_module", str(reward.get("module_scene_path", ""))))
	if granted and str(reward.get("type", "")) != "gold_pack":
		reward["enhanced_id"] = selected_enhanced_contract.enhanced_id
		enhanced_reward_granted.emit(reward)

# Gold is issued as loot; only the player's normal pickup path records income.
func spawn_contract_gold(amount: int) -> int:
	if amount <= 0:
		return 0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or get_tree().current_scene == null:
		return 0
	var economy: EconomyConfig = GlobalVariables.economy_data
	var values := economy.get_contract_coin_values(amount)
	var facing := Vector2.DOWN
	if player.has_method("get_aim_world_position"):
		var aim: Vector2 = player.call("get_aim_world_position")
		if player.global_position.distance_squared_to(aim) > 0.001:
			facing = player.global_position.direction_to(aim)
	for index in range(values.size()):
		var angle := lerpf(-0.7, 0.7, float(index) / float(maxi(values.size() - 1, 1)))
		var offset := facing.rotated(angle) * (52.0 + float(index % 3) * 14.0)
		var landing := player.global_position + offset
		var spawner := GlobalVariables.enemy_spawner
		if is_instance_valid(spawner):
			landing = spawner.clamp_position(landing.x, landing.y)
		var query := PhysicsRayQueryParameters2D.create(player.global_position, landing, 32)
		var obstruction := player.get_world_2d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty():
			var hit_position: Vector2 = obstruction["position"]
			var safe_distance := maxf(player.global_position.distance_to(hit_position) - 12.0, 0.0)
			landing = player.global_position.move_toward(hit_position, safe_distance)
		var coin := CONTRACT_COIN_SCENE.instantiate() as Coin
		coin.value = values[index]
		coin.contract_reward = true
		var parent_2d := get_tree().current_scene as Node2D
		coin.position = parent_2d.to_local(landing) if parent_2d != null else landing
		get_tree().current_scene.add_child(coin)
		coin.global_position = landing
	return amount

func has_uncollected_contract_gold() -> bool:
	for coin in CollectableRegistry.get_coins():
		if coin.contract_reward and not coin._collected:
			return true
	return false

func _get_uncollected_contract_gold_amount() -> int:
	var amount := _restored_contract_gold
	for coin in CollectableRegistry.get_coins():
		if coin.contract_reward and not coin._collected:
			amount += coin.value
	return amount

func collect_remaining_contract_gold() -> bool:
	if not has_uncollected_contract_gold():
		return true
	# Allow the drop to land before the victory collection sweep.
	await get_tree().create_timer(0.7).timeout
	if PhaseManager.current_state() != PhaseManager.SETTLEMENT:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("_on_collect_area_area_entered"):
		return false
	var coins: Array[Coin] = []
	var sweep := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for coin in CollectableRegistry.get_coins():
		if not coin.contract_reward or coin._collected:
			continue
		coins.append(coin)
		coin.target = null
		sweep.tween_method(_move_contract_coin_to_player.bind(coin, player, coin.global_position), 0.0, 1.0, 0.45)
	if coins.is_empty():
		sweep.kill()
		return true
	await sweep.finished
	if not is_instance_valid(player) or PhaseManager.current_state() != PhaseManager.SETTLEMENT:
		return false
	for coin in coins:
		if is_instance_valid(coin) and not coin._collected:
			player.call("_on_collect_area_area_entered", coin)
	return not has_uncollected_contract_gold()

func _move_contract_coin_to_player(ratio: float, coin: Coin, player: Node2D, start: Vector2) -> void:
	if is_instance_valid(coin) and not coin._collected and is_instance_valid(player):
		coin.global_position = start.lerp(player.global_position, ratio)

func _roll_enhanced_reward(definition: EnhancedContractDefinition) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for reward_type in definition.reward_pool:
		match reward_type:
			&"compatible_module":
				var manager := _resolve_reward_manager()
				if manager != null and manager.has_method("roll_enhanced_module_scene_path"):
					var path := str(manager.call("roll_enhanced_module_scene_path"))
					if path != "": candidates.append({"type": &"compatible_module", "module_scene_path": path})
			&"equipped_weapon_core":
				var core_reward := _build_equipped_weapon_core_reward()
				if not core_reward.is_empty(): candidates.append(core_reward)
			&"gold_pack":
				if not PlayerData.gold_supply_enabled:
					candidates.append({"type": &"gold_pack", "amount": _enhanced_gold_amount()})
	if candidates.is_empty():
		if PlayerData.gold_supply_enabled:
			var core_reward := _build_equipped_weapon_core_reward()
			if not core_reward.is_empty():
				return core_reward
			return {}
		return {"type": &"gold_pack", "amount": _enhanced_gold_amount()}
	return candidates[_rng.randi_range(0, candidates.size() - 1)].duplicate(true)

func _build_equipped_weapon_core_reward() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for weapon_variant in PlayerData.player_weapon_list:
		var weapon := weapon_variant as Weapon
		if weapon == null or not is_instance_valid(weapon): continue
		var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
		var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if definition == null: continue
		var tags := definition.get_normalized_core_tags()
		if not definition.has_valid_core_tag_count() or not definition.get_unknown_core_tags().is_empty(): continue
		candidates.append({"type": &"equipped_weapon_core", "weapon_id": weapon_id, "weapon_name": LocalizationManager.get_weapon_name_from_definition(definition), "core_tags": tags})
	return {} if candidates.is_empty() else candidates[_rng.randi_range(0, candidates.size() - 1)]

func _enhanced_gold_amount() -> int:
	var level := maxi(PhaseManager.current_level, 0)
	return 80 if level < 4 else (120 if level < 8 else 160)

func _resolve_reward_manager() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("RewardManager") if scene != null else null

func get_history_snapshot() -> Dictionary:
	return {"last_selected_id": last_selected_id, "consecutive_selection_count": consecutive_selection_count, "missed_offer_counts": missed_offer_counts.duplicate(true)}

func export_save_state() -> Dictionary:
	var payload := get_history_snapshot()
	payload["settlement"] = _build_settlement_snapshot()
	return payload

func import_save_state(payload: Dictionary) -> void:
	_apply_history(payload)
	reset_runtime_state()
	_restore_settlement_snapshot(payload.get("settlement", {}) as Dictionary)

func build_rollback_snapshot() -> Dictionary:
	return {"history_before_confirmation": _history_before_offer.duplicate(true), "option_ids": current_options.map(func(item): return str(item.contract_id)), "selected_id": str(selected_contract.contract_id) if selected_contract != null else "", "enhanced_id": str(selected_enhanced_contract.enhanced_id) if selected_enhanced_contract != null else "", "enhanced_reward": selected_enhanced_reward.duplicate(true), "settlement": _build_settlement_snapshot()}

func restore_rollback_snapshot(payload: Dictionary) -> void:
	_apply_history(payload.get("history_before_confirmation", {}) as Dictionary)
	var options: Array[BattleContractDefinition] = []
	for id in payload.get("option_ids", []):
		var definition := _find_definition(str(id))
		if definition != null: options.append(definition)
	set_offer(options)
	selected_contract = _find_definition(str(payload.get("selected_id", "")))
	if selected_contract != null:
		var enhanced_id := str(payload.get("enhanced_id", ""))
		for definition in _get_enhanced_catalog():
			if str(definition.enhanced_id) == enhanced_id:
				selected_enhanced_contract = definition
				break
		selected_enhanced_reward = (payload.get("enhanced_reward", {}) as Dictionary).duplicate(true)
		_set_state(SELECTED)
		restored_selection_pending = true
	_restore_settlement_snapshot(payload.get("settlement", {}) as Dictionary)
	_save_persistent_state()

func _build_settlement_snapshot() -> Dictionary:
	return {
		"state": str(state),
		"selected_id": str(selected_contract.contract_id) if selected_contract != null else "",
		"runtime_snapshot": runtime_snapshot.duplicate(true),
		"pending_success": _pending_success_settlement,
		"reward_settled": _reward_settled,
		"enhanced_reward_settled": _enhanced_reward_settled,
		"staged_completion_granted": _staged_completion_granted,
		"staged_milestones": _staged_milestones.duplicate(true),
		"uncollected_contract_gold": _get_uncollected_contract_gold_amount(),
	}

func _restore_settlement_snapshot(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var restored_state := StringName(str(payload.get("state", IDLE)))
	if restored_state not in [SELECTED, COMPLETED]:
		return
	var restored_contract := _find_definition(str(payload.get("selected_id", "")))
	if restored_contract == null:
		return
	selected_contract = restored_contract
	runtime_snapshot = (payload.get("runtime_snapshot", {}) as Dictionary).duplicate(true)
	_pending_success_settlement = bool(payload.get("pending_success", false))
	_reward_settled = bool(payload.get("reward_settled", false))
	_enhanced_reward_settled = bool(payload.get("enhanced_reward_settled", false))
	_staged_completion_granted = maxi(int(payload.get("staged_completion_granted", 0)), 0)
	_staged_milestones = (payload.get("staged_milestones", {}) as Dictionary).duplicate(true)
	_restored_contract_gold = maxi(int(payload.get("uncollected_contract_gold", 0)), 0)
	_set_state(restored_state)

func reset_persistent_state() -> void:
	last_selected_id = &""
	consecutive_selection_count = 0
	missed_offer_counts.clear()
	for definition in _get_catalog(): missed_offer_counts[definition.contract_id] = 0
	_history_before_offer = {}
	restored_selection_pending = false
	_reward_offer_roll_level = -1
	_reward_offer_available = false
	if FileAccess.file_exists(STATE_PATH): DirAccess.remove_absolute(STATE_PATH)
	reset_runtime_state()

func _find_definition(id: String) -> BattleContractDefinition:
	for definition in _get_catalog():
		if str(definition.contract_id) == id: return definition
	return null

func _apply_history(payload: Dictionary) -> void:
	last_selected_id = StringName(payload.get("last_selected_id", ""))
	consecutive_selection_count = maxi(int(payload.get("consecutive_selection_count", 0)), 0)
	missed_offer_counts = (payload.get("missed_offer_counts", {}) as Dictionary).duplicate(true)

func _save_persistent_state() -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(get_history_snapshot()))

func _load_persistent_state() -> void:
	if not FileAccess.file_exists(STATE_PATH): return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null: return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary: _apply_history(parsed)

func bind_combat_port(port: BattleContractCombatPort) -> void:
	if _combat_port == port:
		return
	unbind_combat_port()
	_combat_port = port
	if _combat_port == null:
		return
	_combat_port.battle_tick.connect(_on_battle_tick)
	_combat_port.enemy_spawned.connect(_on_enemy_spawned)
	_combat_port.enemy_died.connect(_on_enemy_died)
	_combat_port.spawn_budget_exhausted.connect(_on_spawn_budget_exhausted)
	_combat_port.battle_aborted.connect(_on_battle_aborted)

func unbind_combat_port() -> void:
	if _combat_port == null:
		return
	_disconnect_port_signal(_combat_port.battle_tick, _on_battle_tick)
	_disconnect_port_signal(_combat_port.enemy_spawned, _on_enemy_spawned)
	_disconnect_port_signal(_combat_port.enemy_died, _on_enemy_died)
	_disconnect_port_signal(_combat_port.spawn_budget_exhausted, _on_spawn_budget_exhausted)
	_disconnect_port_signal(_combat_port.battle_aborted, _on_battle_aborted)
	_combat_port = null

func get_combat_port() -> BattleContractCombatPort:
	return _combat_port

func _exit_tree() -> void:
	unbind_combat_port()

func _set_state(next_state: StringName) -> void:
	if next_state not in VALID_STATES or state == next_state:
		return
	state = next_state
	state_changed.emit(state)

func _disconnect_port_signal(port_signal: Signal, callback: Callable) -> void:
	if port_signal.is_connected(callback):
		port_signal.disconnect(callback)

func _forward_combat_event(event_name: StringName, snapshot: Dictionary) -> void:
	combat_event.emit(event_name, snapshot.duplicate(true))

func _on_battle_tick(snapshot: Dictionary) -> void:
	_forward_combat_event(&"battle_tick", snapshot)

func _on_enemy_spawned(snapshot: Dictionary) -> void:
	_forward_combat_event(&"enemy_spawned", snapshot)

func _on_enemy_died(snapshot: Dictionary) -> void:
	_forward_combat_event(&"enemy_died", snapshot)

func _on_spawn_budget_exhausted(snapshot: Dictionary) -> void:
	_forward_combat_event(&"spawn_budget_exhausted", snapshot)

func _on_battle_aborted(snapshot: Dictionary) -> void:
	_forward_combat_event(&"battle_aborted", snapshot)
	unbind_combat_port()
	rollback_confirmed_selection()
