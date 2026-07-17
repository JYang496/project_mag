extends Node

const BattleContractDefinition = preload("res://Combat/battle_contract/BattleContractDefinition.gd")
const BattleContractCombatPort = preload("res://Combat/battle_contract/BattleContractCombatPort.gd")
const ELIMINATION := preload("res://data/battle_contracts/elimination.tres")
const SURVIVAL := preload("res://data/battle_contracts/survival.tres")
const OPERATION := preload("res://data/battle_contracts/operation.tres")
const CONTAINMENT := preload("res://data/battle_contracts/containment.tres")
const EXTRACTION := preload("res://data/battle_contracts/extraction.tres")
const REWARD := preload("res://data/battle_contracts/reward.tres")
const ELIMINATION_RUNTIME := preload("res://Combat/battle_contract/runtime/elimination_contract_runtime.gd")
const SURVIVAL_RUNTIME := preload("res://Combat/battle_contract/runtime/survival_contract_runtime.gd")
const OPERATION_RUNTIME := preload("res://Combat/battle_contract/runtime/operation_contract_runtime.gd")
const CONTAINMENT_RUNTIME := preload("res://Combat/battle_contract/runtime/containment_contract_runtime.gd")
const EXTRACTION_RUNTIME := preload("res://Combat/battle_contract/runtime/extraction_contract_runtime.gd")
const REWARD_RUNTIME := preload("res://Combat/battle_contract/runtime/reward_contract_runtime.gd")

signal state_changed(state: StringName)
signal offer_changed(options: Array[BattleContractDefinition])
signal contract_selected(definition: BattleContractDefinition)
signal contract_completed(snapshot: Dictionary)
signal combat_event(event_name: StringName, snapshot: Dictionary)
signal performance_reward_granted(summary: Dictionary)

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
const STATE_PATH := "user://battle_contract_state.json"

func _ready() -> void:
	_rng.randomize()
	for definition in _get_catalog():
		if definition.contract_id == &"reward":
			continue
		missed_offer_counts[definition.contract_id] = 0
	_load_persistent_state()

func request_offer() -> Array[BattleContractDefinition]:
	if _combat_port == null or _combat_port.is_boss_battle():
		return []
	_history_before_offer = get_history_snapshot()
	var capabilities := _combat_port.get_battlefield_capabilities()
	var allowed := _combat_port.get_allowed_contracts()
	var candidates: Array[BattleContractDefinition] = []
	for definition in _get_catalog():
		if definition.contract_id == &"reward":
			continue
		if not allowed.is_empty() and definition.contract_id not in allowed:
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
	var options: Array[BattleContractDefinition] = []
	while options.size() < target_option_count and not candidates.is_empty():
		var picked := _pick_weighted(candidates)
		options.append(picked)
		candidates.erase(picked)
	if _is_reward_offer_available_for_current_level():
		options.append(REWARD)
	set_offer(options)
	return current_options.duplicate()

func confirm_selection() -> bool:
	if state != SELECTED or selected_contract == null:
		return false
	if selected_contract.contract_id == last_selected_id:
		consecutive_selection_count += 1
	else:
		last_selected_id = selected_contract.contract_id
		consecutive_selection_count = 1
	for definition in _get_catalog():
		if current_options.has(definition):
			missed_offer_counts[definition.contract_id] = 0
		else:
			missed_offer_counts[definition.contract_id] = int(missed_offer_counts.get(definition.contract_id, 0)) + 1
	restored_selection_pending = false
	_save_persistent_state()
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
	return [ELIMINATION, SURVIVAL, OPERATION, CONTAINMENT, EXTRACTION, REWARD]

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
	runtime_snapshot = {}
	_completion_guard = false
	_set_state(OFFERED if not current_options.is_empty() else IDLE)
	offer_changed.emit(current_options.duplicate())
	return state == OFFERED

func select_contract(definition: BattleContractDefinition) -> bool:
	if state not in [OFFERED, SELECTED] or definition == null or not current_options.has(definition):
		return false
	selected_contract = definition
	_set_state(SELECTED)
	contract_selected.emit(selected_contract)
	return true

func activate_contract(snapshot: Dictionary = {}) -> bool:
	if state != SELECTED or selected_contract == null:
		return false
	if _combat_port != null:
		var economy: EconomyConfig = GlobalVariables.economy_data
		var plan := economy.get_contract_gold_plan(selected_contract.contract_id, maxi(PhaseManager.current_level, 0))
		_combat_port.request_configure_contract_economy(float(plan.get("kill_gold_multiplier", 1.0)))
	runtime_snapshot = snapshot.duplicate(true)
	_completion_guard = false
	_reward_settled = false
	_set_state(ACTIVE)
	_start_selected_runtime()
	return true

func update_runtime_snapshot(snapshot: Dictionary) -> void:
	if state == ACTIVE:
		runtime_snapshot = snapshot.duplicate(true)

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
	runtime_snapshot = {}
	_completion_guard = false
	_set_state(IDLE)

func _start_selected_runtime() -> void:
	_stop_runtime()
	match selected_contract.contract_id:
		&"elimination": _runtime = ELIMINATION_RUNTIME.new()
		&"survival": _runtime = SURVIVAL_RUNTIME.new()
		&"operation": _runtime = OPERATION_RUNTIME.new()
		&"containment": _runtime = CONTAINMENT_RUNTIME.new()
		&"extraction": _runtime = EXTRACTION_RUNTIME.new()
		&"reward": _runtime = REWARD_RUNTIME.new()
	if _runtime == null:
		return
	_runtime.snapshot_changed.connect(update_runtime_snapshot)
	_runtime.completed.connect(_on_runtime_completed)
	_runtime.call("start", _combat_port, selected_contract.parameters)

func _stop_runtime() -> void:
	if _runtime == null:
		return
	_runtime.call("stop")
	_runtime = null

func _on_runtime_completed(snapshot: Dictionary) -> void:
	_stop_runtime()
	if not complete_contract(snapshot):
		return
	_settle_performance_reward(snapshot)
	await get_tree().create_timer(1.0).timeout
	if _combat_port != null and PhaseManager.current_state() == PhaseManager.BATTLE:
		_combat_port.request_finish_battle(snapshot)

func _settle_performance_reward(result: Dictionary) -> void:
	if _reward_settled:
		return
	_reward_settled = true
	var economy: EconomyConfig = GlobalVariables.economy_data
	var level := maxi(PhaseManager.current_level, 0)
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
	var amount := maxi(completion_gold + performance_gold, 0)
	if amount <= 0:
		return
	PlayerData.player_gold += amount
	PlayerData.run_gold_earned += amount
	performance_reward_granted.emit({"type": &"gold", "amount": amount, "contract_id": contract_id, "completion_gold": completion_gold, "performance_gold": performance_gold})

func get_history_snapshot() -> Dictionary:
	return {"last_selected_id": last_selected_id, "consecutive_selection_count": consecutive_selection_count, "missed_offer_counts": missed_offer_counts.duplicate(true)}

func build_rollback_snapshot() -> Dictionary:
	return {"history_before_confirmation": _history_before_offer.duplicate(true), "option_ids": current_options.map(func(item): return str(item.contract_id)), "selected_id": str(selected_contract.contract_id) if selected_contract != null else ""}

func restore_rollback_snapshot(payload: Dictionary) -> void:
	_apply_history(payload.get("history_before_confirmation", {}) as Dictionary)
	var options: Array[BattleContractDefinition] = []
	for id in payload.get("option_ids", []):
		var definition := _find_definition(str(id))
		if definition != null: options.append(definition)
	set_offer(options)
	selected_contract = _find_definition(str(payload.get("selected_id", "")))
	if selected_contract != null:
		_set_state(SELECTED)
		restored_selection_pending = true
	_save_persistent_state()

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
