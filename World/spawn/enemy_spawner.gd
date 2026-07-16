extends Node2D
class_name EnemySpawner

signal combat_tick
signal enemy_spawned(enemy: Node)
signal enemy_died(enemy: Node, was_killed: bool)
signal spawn_budget_stopped
signal combat_frame(delta_sec: float)

@onready var timer = $Timer
@export var debug_print_spawn_stats := true
@export var debug_print_kill_gold_stats := true
@export var debug_print_kill_gold_drop_stats := false
@export var min_spawn_distance_from_player: float = 180.0
@export var spawn_point_attempts_per_enemy: int = 12
@export var spawn_edge_margin: float = 28.0
@onready var board = get_parent().get_node_or_null("Board")
@onready var top_left_marker: Node2D = $TopLeft
@onready var bottom_right_marker: Node2D = $BottomRight

const SpawnCombatProfileScript := preload("res://data/spawns/SpawnCombatProfile.gd")
const SPAWN_POINT_PICKER_SCRIPT := preload("res://World/spawn/spawn_point_picker.gd")
const SPAWN_BUDGET_RUNTIME_SCRIPT := preload("res://World/spawn/spawn_budget_runtime.gd")
const KILL_GOLD_BUDGET_RUNTIME_SCRIPT := preload("res://World/spawn/kill_gold_budget_runtime.gd")
const BATTLE_CONTRACT_COMBAT_BRIDGE_SCRIPT := preload("res://Combat/battle_contract/BattleContractCombatBridge.gd")
const REWARD_ENEMY_SCENE := preload("res://Npc/enemy/scenes/reward_enemy.tscn")

var instance_list : Array
var _runtime_spawn_states: Array[Dictionary] = []
var _runtime_base_time_out: int = 30
var _fallback_spawn_combat_profile: SpawnCombatProfile = SpawnCombatProfileScript.new()
var board_cells : Array[Cell] = []
var _last_spawn_cell: Cell = null
var x_min: float = 0.0
var y_min: float = 0.0
var x_max: float = 0.0
var y_max: float = 0.0
var _spawn_point_picker: RefCounted
var _rng := RandomNumberGenerator.new()
var _enemy_metadata_cache: Dictionary = {}
var _kill_gold_budget: int = 0
var _kill_gold_paid: int = 0
var _kill_gold_battle_timeout: int = 1
var _kill_gold_budget_active: bool = false
var _warned_inactive_kill_gold_budget: bool = false
var _kill_gold_collected: int = 0
var _kill_gold_budget_runtime: RefCounted
var _combat_budget_active: bool = true
var _planned_target_total_hp: int = 0
var _spawned_total_hp: int = 0
var _killed_total_hp: int = 0
var _available_hp_budget: float = 0.0
var _pressure_budget_total: float = 1.0
var _budget_release_duration_sec: int = 1
var _budget_release_finished: bool = false
var _spawn_budget_stopped: bool = false
var _budget_summary_printed: bool = false
var _spawn_budget_runtime: RefCounted
var _battle_victory_transition_active := false
var _contract_bridge: RefCounted
var _contract_duration_override_sec: int = 0
var _spawn_budget_stop_emitted := false
var _contract_continuous_spawning := false
var _contract_threat_multiplier := 1.0
var _contract_external_victory := false
var _contract_prefer_final_elite := false
var _contract_batch_count := 0
var _contract_released_batches := 0
var _contract_spawn_plan: Array[int] = []
var _contract_spawn_plan_cursor := 0
var _contract_reward_stage := false
var _contract_reward_hp_multiplier := 1.0
var _contract_reward_multiplier := 1.0
var _contract_kill_gold_multiplier := 1.0

func _ready():
	GlobalVariables.enemy_spawner = self
	_rng.randomize()
	_init_spawn_point_picker()
	_init_spawn_budget_runtime()
	_init_kill_gold_budget_runtime()
	_cache_board_cells()
	if board and board.has_signal("active_cells_changed") and not board.is_connected("active_cells_changed", Callable(self, "_on_board_active_cells_changed")):
		board.connect("active_cells_changed", Callable(self, "_on_board_active_cells_changed"))
	_refresh_fallback_bounds()
	_refresh_spawn_tables()
	_contract_bridge = BATTLE_CONTRACT_COMBAT_BRIDGE_SCRIPT.new()
	_contract_bridge.bind(self)
	BattleContractManager.bind_combat_port(_contract_bridge)

func _exit_tree() -> void:
	BattleContractManager.abort_current_contract({"reason": "scene_exit"})
	if BattleContractManager.get_combat_port() == _contract_bridge:
		BattleContractManager.unbind_combat_port()
	if _contract_bridge != null:
		_contract_bridge.unbind()

func _process(delta: float) -> void:
	if PhaseManager.current_state() == PhaseManager.BATTLE:
		combat_frame.emit(maxf(delta, 0.0))

func _init_spawn_point_picker() -> void:
	if _spawn_point_picker != null:
		return
	_spawn_point_picker = SPAWN_POINT_PICKER_SCRIPT.new()
	_spawn_point_picker.bind(self, board, top_left_marker, bottom_right_marker)
	_sync_spawn_point_picker_config()

func _sync_spawn_point_picker_config() -> void:
	if _spawn_point_picker == null:
		return
	_spawn_point_picker.configure(
		min_spawn_distance_from_player,
		spawn_point_attempts_per_enemy,
		spawn_edge_margin
	)

func _sync_spawn_point_picker_state() -> void:
	if _spawn_point_picker == null:
		return
	board_cells = _spawn_point_picker.board_cells
	_last_spawn_cell = _spawn_point_picker.last_spawn_cell
	x_min = _spawn_point_picker.x_min
	y_min = _spawn_point_picker.y_min
	x_max = _spawn_point_picker.x_max
	y_max = _spawn_point_picker.y_max

func _init_spawn_budget_runtime() -> void:
	if _spawn_budget_runtime != null:
		return
	_spawn_budget_runtime = SPAWN_BUDGET_RUNTIME_SCRIPT.new()
	_spawn_budget_runtime.bind(
		Callable(self, "_get_spawn_combat_profile"),
		Callable(self, "_resolve_budget_candidate_hp_from_spawner"),
		Callable(self, "_print_kill_gold_debug_summary")
	)
	_sync_spawn_budget_runtime_state()

func _sync_spawn_budget_runtime_state() -> void:
	if _spawn_budget_runtime == null:
		return
	_combat_budget_active = bool(_spawn_budget_runtime.combat_budget_active)
	_planned_target_total_hp = int(_spawn_budget_runtime.planned_target_total_hp)
	_spawned_total_hp = int(_spawn_budget_runtime.spawned_total_hp)
	_killed_total_hp = int(_spawn_budget_runtime.killed_total_hp)
	_available_hp_budget = float(_spawn_budget_runtime.available_hp_budget)
	_pressure_budget_total = float(_spawn_budget_runtime.pressure_budget_total)
	_budget_release_duration_sec = int(_spawn_budget_runtime.budget_release_duration_sec)
	_budget_release_finished = bool(_spawn_budget_runtime.budget_release_finished)
	_spawn_budget_stopped = bool(_spawn_budget_runtime.spawn_budget_stopped)
	_budget_summary_printed = bool(_spawn_budget_runtime.budget_summary_printed)

func _sync_spawn_budget_owner_state_to_runtime() -> void:
	if _spawn_budget_runtime == null:
		return
	_spawn_budget_runtime.combat_budget_active = _combat_budget_active
	_spawn_budget_runtime.planned_target_total_hp = _planned_target_total_hp
	_spawn_budget_runtime.spawned_total_hp = _spawned_total_hp
	_spawn_budget_runtime.killed_total_hp = _killed_total_hp
	_spawn_budget_runtime.available_hp_budget = _available_hp_budget
	_spawn_budget_runtime.pressure_budget_total = _pressure_budget_total
	_spawn_budget_runtime.budget_release_duration_sec = _budget_release_duration_sec
	_spawn_budget_runtime.budget_release_finished = _budget_release_finished
	_spawn_budget_runtime.spawn_budget_stopped = _spawn_budget_stopped
	_spawn_budget_runtime.budget_summary_printed = _budget_summary_printed

func _init_kill_gold_budget_runtime() -> void:
	if _kill_gold_budget_runtime != null:
		return
	_kill_gold_budget_runtime = KILL_GOLD_BUDGET_RUNTIME_SCRIPT.new()
	_kill_gold_budget_runtime.bind(
		self,
		Callable(self, "_get_spawn_combat_profile"),
		Callable(self, "_get_economy_config")
	)
	_sync_kill_gold_budget_config()
	_sync_kill_gold_budget_runtime_state()

func _sync_kill_gold_budget_config() -> void:
	if _kill_gold_budget_runtime == null:
		return
	_kill_gold_budget_runtime.configure(
		debug_print_kill_gold_stats,
		debug_print_kill_gold_drop_stats
	)
	_kill_gold_budget_runtime.configure_target_multipliers(_contract_reward_hp_multiplier, _contract_reward_multiplier * _contract_kill_gold_multiplier)

func _sync_kill_gold_budget_runtime_state() -> void:
	if _kill_gold_budget_runtime == null:
		return
	_kill_gold_budget = int(_kill_gold_budget_runtime.kill_gold_budget)
	_kill_gold_paid = int(_kill_gold_budget_runtime.kill_gold_paid)
	_kill_gold_battle_timeout = int(_kill_gold_budget_runtime.kill_gold_battle_timeout)
	_kill_gold_budget_active = bool(_kill_gold_budget_runtime.kill_gold_budget_active)
	_warned_inactive_kill_gold_budget = bool(_kill_gold_budget_runtime.warned_inactive_kill_gold_budget)
	_kill_gold_collected = int(_kill_gold_budget_runtime.kill_gold_collected)

func _sync_kill_gold_owner_state_to_runtime() -> void:
	if _kill_gold_budget_runtime == null:
		return
	_kill_gold_budget_runtime.kill_gold_budget = _kill_gold_budget
	_kill_gold_budget_runtime.kill_gold_paid = _kill_gold_paid
	_kill_gold_budget_runtime.kill_gold_battle_timeout = _kill_gold_battle_timeout
	_kill_gold_budget_runtime.kill_gold_budget_active = _kill_gold_budget_active
	_kill_gold_budget_runtime.warned_inactive_kill_gold_budget = _warned_inactive_kill_gold_budget
	_kill_gold_budget_runtime.kill_gold_collected = _kill_gold_collected

func _on_board_active_cells_changed(_active_cell_ids: PackedInt32Array) -> void:
	_refresh_fallback_bounds()

func _refresh_spawn_tables() -> void:
	SpawnData.ensure_loaded()
	instance_list = []
	for level_config in SpawnData.level_list:
		if level_config == null:
			continue
		var ins = level_config.duplicate(true)
		if ins == null:
			continue
		instance_list.append(ins.spawns)

func start_timer() -> void:
	if instance_list.is_empty():
		_refresh_spawn_tables()
	if instance_list.is_empty() or not _build_runtime_spawn_context(maxi(PhaseManager.current_level, 0)):
		push_warning("EnemySpawner cannot start: spawn tables are empty.")
		return
	var level_index := maxi(PhaseManager.current_level, 0)
	var effective_time_out := get_effective_time_out(_runtime_base_time_out, level_index)
	PhaseManager.start_battle_timer(effective_time_out)
	_prepare_level_combat_budget(level_index, effective_time_out)
	_spawn_budget_stop_emitted = false
	_start_kill_gold_budget(level_index, effective_time_out)
	timer.start()

func _on_timer_timeout():
	if _runtime_spawn_states.is_empty():
		timer.stop()
		push_warning("EnemySpawner timeout with empty runtime spawn table.")
		return
	var level_index := maxi(PhaseManager.current_level, 0)
	PhaseManager.advance_battle_time(1)
	combat_tick.emit()
	var base_time_out: int = _runtime_base_time_out
	var effective_time_out: int = get_effective_time_out(base_time_out, level_index)
	if not _contract_external_victory and (PhaseManager.battle_time >= effective_time_out or _should_end_after_spawn_budget_stopped()):
		finish_battle_with_victory(level_index, effective_time_out)
		return
	_tick_spawn_intervals()
	_spawn_with_random_wave_template(level_index, effective_time_out)
	if not _contract_external_victory and _should_end_after_spawn_budget_stopped():
		finish_battle_with_victory(level_index, effective_time_out)

func _is_runtime_spawn_budget_spent() -> bool:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	return bool(_spawn_budget_runtime.is_runtime_spawn_budget_spent())

func _should_end_after_spawn_budget_stopped() -> bool:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	return bool(_spawn_budget_runtime.should_end_after_spawn_budget_stopped(_get_total_runtime_alive_count()))

func _spawn_with_random_wave_template(level_index: int, effective_time_out: int) -> void:
	if not _is_combat_budget_ready():
		return
	_release_hp_budget_for_current_tick(level_index, effective_time_out)
	if _available_hp_budget <= 0.0:
		return
	if _spawn_budget_stopped:
		return
	_build_random_spawn_batch(level_index, effective_time_out)

func _tick_spawn_intervals() -> void:
	for state in _runtime_spawn_states:
		state["cooldown"] = maxi(int(state.get("cooldown", 0)) - 1, 0)

func _build_random_spawn_batch(level_index: int, _effective_time_out: int) -> Dictionary:
	var available: Array[Dictionary] = []
	for state in _runtime_spawn_states:
		var entry := _get_state_entry(state)
		if entry == null:
			continue
		if PhaseManager.battle_time < entry.start_sec:
			continue
		if int(state.get("cooldown", 0)) > 0:
			continue
		if int(state.get("alive", 0)) >= _get_state_alive_cap(state):
			continue
		if _get_total_runtime_alive_count() >= _get_spawn_combat_profile().default_total_alive_cap:
			continue
		available.append(state)
	if available.is_empty():
		return {}

	var batch: Dictionary = {}
	var count_by_scene: Dictionary = {}
	var ranged_count := 0
	var elite_count := 0

	var profile: SpawnCombatProfile = _get_spawn_combat_profile()
	for _attempt in range(int(profile.get("max_selection_attempts"))):
		if _available_hp_budget <= 0.0 or _spawn_budget_stopped:
			break
		var candidate := _get_next_contract_planned_candidate(available)
		if candidate.is_empty() and _contract_spawn_plan.is_empty():
			candidate = _pick_weighted_candidate(available, count_by_scene, ranged_count, elite_count, level_index)
		if candidate.is_empty():
			break
		var scene_path := _get_spawn_scene_path(candidate)
		var candidate_id := int(candidate.get("id", -1))
		var spawned_hp := _spawn_from_state(candidate, 1)
		if spawned_hp <= 0:
			available.erase(candidate)
			continue
		if not _contract_spawn_plan.is_empty():
			_contract_spawn_plan_cursor += 1
		candidate["cooldown"] = 1
		batch[candidate_id] = int(batch.get(candidate_id, 0)) + 1
		count_by_scene[scene_path] = int(count_by_scene.get(scene_path, 0)) + 1
		if _is_spawn_ranged(candidate):
			ranged_count += 1
		if _is_spawn_elite(candidate):
			elite_count += 1
		_spawn_budget_runtime.consume_spawned_hp(spawned_hp)
		_sync_spawn_budget_runtime_state()
		_update_spawn_budget_stop_state()
	return batch

func _resolve_batch_hp_budget(level_index: int, _effective_time_out: int) -> float:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	return float(_spawn_budget_runtime.resolve_batch_hp_budget(level_index, _effective_time_out))

func _release_hp_budget_for_current_tick(level_index: int, effective_time_out: int) -> void:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	var budget_before := float(_spawn_budget_runtime.available_hp_budget)
	_spawn_budget_runtime.release_hp_budget_for_current_tick(level_index, effective_time_out)
	var released := maxf(float(_spawn_budget_runtime.available_hp_budget) - budget_before, 0.0)
	_spawn_budget_runtime.available_hp_budget += released * (_contract_threat_multiplier - 1.0)
	_sync_spawn_budget_runtime_state()

func roll_enemy_kill_gold(enemy_instance: Node = null) -> int:
	_init_kill_gold_budget_runtime()
	_sync_kill_gold_budget_config()
	_sync_kill_gold_owner_state_to_runtime()
	var gold: int = _kill_gold_budget_runtime.roll_enemy_kill_gold(enemy_instance)
	_sync_kill_gold_budget_runtime_state()
	return gold

func record_kill_gold_coin_spawned(value: int) -> void:
	_init_kill_gold_budget_runtime()
	_sync_kill_gold_budget_config()
	_sync_kill_gold_owner_state_to_runtime()
	_kill_gold_budget_runtime.record_kill_gold_coin_spawned(value)
	_sync_kill_gold_budget_runtime_state()

func record_kill_gold_coin_collected(value: int) -> void:
	_init_kill_gold_budget_runtime()
	_sync_kill_gold_budget_config()
	_sync_kill_gold_owner_state_to_runtime()
	_kill_gold_budget_runtime.record_kill_gold_coin_collected(value)
	_sync_kill_gold_budget_runtime_state()

func _resolve_enemy_kill_expected_gold(enemy_instance: Node) -> float:
	_init_kill_gold_budget_runtime()
	_sync_kill_gold_owner_state_to_runtime()
	return float(_kill_gold_budget_runtime.resolve_enemy_kill_expected_gold(enemy_instance))

func _resolve_enemy_kill_gold_hp(enemy_instance: Node) -> int:
	_init_kill_gold_budget_runtime()
	return int(_kill_gold_budget_runtime.resolve_enemy_kill_gold_hp(enemy_instance))

func _resolve_kill_gold_target_total_hp_for_level(level_index: int) -> int:
	_init_kill_gold_budget_runtime()
	return int(_kill_gold_budget_runtime.resolve_kill_gold_target_total_hp_for_level(level_index))

func is_kill_gold_budget_active() -> bool:
	_init_kill_gold_budget_runtime()
	_sync_kill_gold_owner_state_to_runtime()
	return bool(_kill_gold_budget_runtime.is_kill_gold_budget_active())

func ensure_kill_gold_budget_active() -> bool:
	_init_kill_gold_budget_runtime()
	_sync_kill_gold_owner_state_to_runtime()
	if _kill_gold_budget_active:
		return true
	var level_index := maxi(PhaseManager.current_level, 0)
	if _runtime_spawn_states.is_empty() or _runtime_base_time_out <= 0:
		_build_runtime_spawn_context(level_index)
	var effective_time_out := get_effective_time_out(_runtime_base_time_out, level_index)
	_start_kill_gold_budget(level_index, effective_time_out)
	return _kill_gold_budget_active

func get_kill_gold_budget_snapshot() -> Dictionary:
	_init_kill_gold_budget_runtime()
	_sync_kill_gold_owner_state_to_runtime()
	var snapshot: Dictionary = _kill_gold_budget_runtime.get_kill_gold_budget_snapshot()
	_sync_kill_gold_budget_runtime_state()
	return snapshot

func _start_kill_gold_budget(level_index: int, effective_time_out: int) -> void:
	_init_kill_gold_budget_runtime()
	_sync_kill_gold_budget_config()
	_kill_gold_budget_runtime.start_kill_gold_budget(level_index, effective_time_out)
	_sync_kill_gold_budget_runtime_state()

func warn_inactive_kill_gold_budget() -> void:
	_init_kill_gold_budget_runtime()
	_sync_kill_gold_owner_state_to_runtime()
	_kill_gold_budget_runtime.warn_inactive_kill_gold_budget()
	_sync_kill_gold_budget_runtime_state()

func _resolve_kill_gold_target_for_level(level_index: int) -> int:
	_init_kill_gold_budget_runtime()
	return int(_kill_gold_budget_runtime.resolve_kill_gold_target_for_level(level_index))

func _get_kill_gold_budget_variance() -> float:
	_init_kill_gold_budget_runtime()
	return float(_kill_gold_budget_runtime.get_kill_gold_budget_variance())

func _get_kill_gold_max_drop_chance() -> float:
	_init_kill_gold_budget_runtime()
	return float(_kill_gold_budget_runtime.get_kill_gold_max_drop_chance())

func _get_economy_config() -> EconomyConfig:
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data
	if DataHandler != null and DataHandler.has_method("load_economy_data"):
		DataHandler.load_economy_data()
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data
	return EconomyConfig.new()

func _get_state_entry(state: Dictionary) -> EnemySpawnEntry:
	return state.get("entry") as EnemySpawnEntry

func _get_runtime_state_by_id(state_id: int) -> Dictionary:
	for state in _runtime_spawn_states:
		if int(state.get("id", -1)) == state_id:
			return state
	return {}

func _get_state_alive_cap(state: Dictionary) -> int:
	var entry := _get_state_entry(state)
	var profile := _get_spawn_combat_profile()
	if entry == null:
		return profile.default_alive_cap_per_type
	var scene_path := _get_spawn_scene_path(state)
	var metadata := _get_enemy_metadata(scene_path, entry.enemy)
	var enemy_cap := int(metadata.get("spawn_alive_cap", 0))
	if enemy_cap > 0:
		return enemy_cap
	return profile.default_alive_cap_per_type

func _get_total_runtime_alive_count() -> int:
	var total := 0
	for state in _runtime_spawn_states:
		total += int(state.get("alive", 0))
	return total

func _get_total_runtime_ranged_alive_count() -> int:
	var total := 0
	for state in _runtime_spawn_states:
		if _is_spawn_ranged(state):
			total += int(state.get("alive", 0))
	return total

func _add_enemy_with_state_signal(state: Dictionary, enemy_instance: Node) -> void:
	if enemy_instance == null:
		return
	state["alive"] = int(state.get("alive", 0)) + 1
	if enemy_instance.has_signal("enemy_death"):
		enemy_instance.connect("enemy_death", func(was_killed: bool) -> void:
			state["alive"] = maxi(int(state.get("alive", 0)) - 1, 0)
			_record_enemy_death_for_budget_summary(enemy_instance, was_killed)
			enemy_died.emit(enemy_instance, was_killed)
			call_deferred("_try_finish_battle_after_spawn_budget_stop")
		)

func _get_enemy_metadata(scene_path: String, scene: PackedScene) -> Dictionary:
	if scene_path != "" and _enemy_metadata_cache.has(scene_path):
		return _enemy_metadata_cache[scene_path]
	var metadata := {
		"spawn_tags": [],
		"spawn_alive_cap": 0,
		"spawn_batch_cap": 0,
		"base_hp": 1,
		"base_damage": 0,
	}
	if scene != null:
		var preview := scene.instantiate()
		if preview is BaseEnemy:
			var base_enemy := preview as BaseEnemy
			var tags_variant: Variant = base_enemy.get("spawn_tags")
			metadata["spawn_tags"] = tags_variant.duplicate() if tags_variant is Array else []
			metadata["spawn_alive_cap"] = maxi(_safe_int(base_enemy.get("spawn_alive_cap"), 0), 0)
			metadata["spawn_batch_cap"] = maxi(_safe_int(base_enemy.get("spawn_batch_cap"), 0), 0)
			metadata["base_hp"] = maxi(int(base_enemy.hp), 1)
			metadata["base_damage"] = maxi(int(base_enemy.damage), 0)
		if preview != null and is_instance_valid(preview):
			preview.free()
	if scene_path != "":
		_enemy_metadata_cache[scene_path] = metadata
	return metadata

func _safe_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	return int(value)

func _pick_weighted_candidate(
	available: Array[Dictionary],
	count_by_scene: Dictionary,
	ranged_count: int,
	elite_count: int,
	level_index: int
) -> Dictionary:
	var weighted_candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for state in available:
		if not _can_pick_candidate(state, count_by_scene, ranged_count, elite_count, level_index):
			continue
		var entry := _get_state_entry(state)
		var weight := maxf(float(entry.weight), 1.0)
		if _contract_prefer_final_elite and _planned_target_total_hp > 0 \
				and float(_spawned_total_hp) / float(_planned_target_total_hp) >= 0.8 \
				and _is_spawn_elite(state):
			weight *= 8.0
		weighted_candidates.append({"state": state, "weight": weight})
		total_weight += weight
	if weighted_candidates.is_empty() or total_weight <= 0.0:
		return {}
	var roll := _rng.randf_range(0.0, total_weight)
	for item in weighted_candidates:
		roll -= float(item["weight"])
		if roll <= 0.0:
			return item["state"] as Dictionary
	return weighted_candidates.back()["state"] as Dictionary

func _pick_fallback_candidate(
	available: Array[Dictionary],
	count_by_scene: Dictionary,
	ranged_count: int,
	elite_count: int,
	level_index: int
) -> Dictionary:
	var best: Dictionary = {}
	var best_hp := INF
	for state in available:
		if not _can_pick_candidate(state, count_by_scene, ranged_count, elite_count, level_index):
			continue
		var hp := _resolve_budget_candidate_hp(state, level_index)
		if hp < best_hp:
			best_hp = hp
			best = state
	return best

func _can_pick_candidate(
	state: Dictionary,
	count_by_scene: Dictionary,
	ranged_count: int,
	elite_count: int,
	level_index: int
) -> bool:
	if _contract_batch_count > 0 and _planned_target_total_hp > 0:
		var released_hp := ceili(float(_planned_target_total_hp) * float(_contract_released_batches) / float(_contract_batch_count))
		if _spawned_total_hp >= released_hp:
			return false
	var entry := _get_state_entry(state)
	if entry == null:
		return false
	if int(state.get("alive", 0)) >= _get_state_alive_cap(state):
		return false
	if _get_total_runtime_alive_count() >= _get_spawn_combat_profile().default_total_alive_cap:
		return false
	if _is_runtime_spawn_budget_spent():
		return false
	var scene_path := _get_spawn_scene_path(state)
	if scene_path == "":
		return false
	var same_type_count := int(count_by_scene.get(scene_path, 0))
	var profile: SpawnCombatProfile = _get_spawn_combat_profile()
	if same_type_count >= _get_same_type_batch_limit(scene_path, profile):
		return false
	var metadata := _get_enemy_metadata(scene_path, entry.enemy)
	var scene_batch_cap := int(metadata.get("spawn_batch_cap", 0))
	if scene_batch_cap > 0 and same_type_count >= scene_batch_cap:
		return false
	if _is_spawn_ranged(state) and ranged_count >= int(profile.get("max_ranged_per_batch")):
		return false
	if _is_spawn_ranged(state):
		var max_ranged_alive := int(profile.get("max_ranged_alive_total"))
		if max_ranged_alive > 0 and _get_total_runtime_ranged_alive_count() >= max_ranged_alive:
			return false
	if _is_spawn_elite(state):
		var elite_limit := 1 if level_index < 8 else 2
		if elite_count >= elite_limit:
			return false
	return true

func _get_spawn_scene_path(state: Dictionary) -> String:
	var entry := _get_state_entry(state)
	if entry == null or entry.enemy == null:
		return ""
	return entry.enemy.resource_path

func _is_spawn_elite(state: Dictionary) -> bool:
	var entry := _get_state_entry(state)
	if entry == null:
		return false
	var metadata := _get_enemy_metadata(_get_spawn_scene_path(state), entry.enemy)
	var tags: Array = metadata.get("spawn_tags", [])
	return tags.has(BaseEnemy.SPAWN_TAG_ELITE)

func _is_spawn_ranged(state: Dictionary) -> bool:
	var entry := _get_state_entry(state)
	if entry == null:
		return false
	var metadata := _get_enemy_metadata(_get_spawn_scene_path(state), entry.enemy)
	var tags: Array = metadata.get("spawn_tags", [])
	return tags.has(BaseEnemy.SPAWN_TAG_RANGED)

func _spawn_from_state(state: Dictionary, requested_count: int) -> int:
	var entry := _get_state_entry(state)
	if entry == null or entry.enemy == null:
		return 0
	var spawn_room: int = maxi(0, _get_state_alive_cap(state) - int(state.get("alive", 0)))
	if spawn_room <= 0:
		return 0
	var new_enemy := entry.enemy
	var base_count := clampi(max(1, requested_count), 1, spawn_room)
	var spawn_count: int = base_count
	var loot_value_multiplier: float = 1.0
	var random_position_center := get_random_position()
	var counter := 0
	var spawned_hp := 0
	while counter < spawn_count:
		var enemy_spawn = new_enemy.instantiate()
		_apply_level_scaling(state, enemy_spawn)
		if enemy_spawn is BaseEnemy:
			var base_enemy := enemy_spawn as BaseEnemy
			base_enemy.loot_value_multiplier = maxf(loot_value_multiplier, 0.1)
			var scaled_hp := maxi(int(base_enemy.hp), 1)
			base_enemy.set_meta("_spawn_budget_scaled_hp", scaled_hp)
			spawned_hp += scaled_hp
		_debug_log_spawned_enemy(enemy_spawn)
		enemy_spawn.global_position = get_nearby_position(random_position_center)
		self.call_deferred("add_child", enemy_spawn)
		_add_enemy_with_state_signal(state, enemy_spawn)
		enemy_spawned.emit(enemy_spawn)
		counter += 1
	return spawned_hp

func get_random_position() -> Vector2:
	_init_spawn_point_picker()
	_sync_spawn_point_picker_config()
	var spawn_position: Vector2 = _spawn_point_picker.get_random_position()
	_sync_spawn_point_picker_state()
	return spawn_position

func _cache_board_cells() -> void:
	_init_spawn_point_picker()
	_spawn_point_picker.cache_board_cells()
	_sync_spawn_point_picker_state()

func _refresh_fallback_bounds() -> void:
	_init_spawn_point_picker()
	_spawn_point_picker.refresh_fallback_bounds()
	_sync_spawn_point_picker_state()

func _pick_spawn_cell_near_player(player: Player) -> Cell:
	_init_spawn_point_picker()
	var cell: Cell = _spawn_point_picker.pick_spawn_cell_near_player(player)
	_sync_spawn_point_picker_state()
	return cell

func _get_cell_at_position(world_position: Vector2, cells: Array[Cell]) -> Cell:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_cell_at_position(world_position, cells)

func _cell_contains_point(cell: Cell, world_position: Vector2) -> bool:
	_init_spawn_point_picker()
	return _spawn_point_picker.cell_contains_point(cell, world_position)

func _get_random_point_in_cell(cell: Cell) -> Vector2:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_random_point_in_cell(cell)

func _get_random_point_in_cell_away_from_player(cell: Cell, player_position: Vector2) -> Vector2:
	_init_spawn_point_picker()
	_sync_spawn_point_picker_config()
	return _spawn_point_picker.get_random_point_in_cell_away_from_player(cell, player_position)

func _cell_can_spawn_away_from_player(cell: Cell, player_position: Vector2) -> bool:
	_init_spawn_point_picker()
	_sync_spawn_point_picker_config()
	return _spawn_point_picker.cell_can_spawn_away_from_player(cell, player_position)

func _get_neighbor_cells(player_cell: Cell, cells: Array[Cell]) -> Array[Cell]:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_neighbor_cells(player_cell, cells)

func _estimate_neighbor_distance(player_cell: Cell, cells: Array[Cell]) -> float:
	_init_spawn_point_picker()
	return _spawn_point_picker.estimate_neighbor_distance(player_cell, cells)

func _project_point_into_cell(cell: Cell, world_position: Vector2) -> Vector2:
	_init_spawn_point_picker()
	return _spawn_point_picker.project_point_into_cell(cell, world_position)

func _get_player_view_rect(player: Player) -> Rect2:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_player_view_rect(player)

func _cell_intersects_rect(cell: Cell, rect: Rect2) -> bool:
	_init_spawn_point_picker()
	return _spawn_point_picker.cell_intersects_rect(cell, rect)

func _get_cell_aabb(cell: Cell) -> Rect2:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_cell_aabb(cell)

func _get_cell_capture_polygon(cell: Cell) -> CollisionPolygon2D:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_cell_capture_polygon(cell)

func _is_point_inside_capture_polygon(capture_polygon: CollisionPolygon2D, world_position: Vector2) -> bool:
	_init_spawn_point_picker()
	return _spawn_point_picker.is_point_inside_capture_polygon(capture_polygon, world_position)

func _get_random_point_in_capture_polygon(capture_polygon: CollisionPolygon2D) -> Vector2:
	_init_spawn_point_picker()
	_sync_spawn_point_picker_config()
	return _spawn_point_picker.get_random_point_in_capture_polygon(capture_polygon)

func _project_point_into_capture_polygon(capture_polygon: CollisionPolygon2D, world_position: Vector2) -> Vector2:
	_init_spawn_point_picker()
	return _spawn_point_picker.project_point_into_capture_polygon(capture_polygon, world_position)

func _get_capture_polygon_aabb(capture_polygon: CollisionPolygon2D) -> Rect2:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_capture_polygon_aabb(capture_polygon)

func _get_polygon_local_aabb(polygon_points: PackedVector2Array) -> Rect2:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_polygon_local_aabb(polygon_points)

func _get_polygon_centroid(polygon_points: PackedVector2Array) -> Vector2:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_polygon_centroid(polygon_points)

func _get_fallback_spawn_position(player: Player) -> Vector2:
	_init_spawn_point_picker()
	_sync_spawn_point_picker_config()
	var spawn_position: Vector2 = _spawn_point_picker.get_fallback_spawn_position(player)
	_sync_spawn_point_picker_state()
	return spawn_position

func _pick_farthest_cell_from_player(player_position: Vector2) -> Cell:
	_init_spawn_point_picker()
	var cell: Cell = _spawn_point_picker.pick_farthest_cell_from_player(player_position)
	_sync_spawn_point_picker_state()
	return cell

func _get_effective_board_cells() -> Array[Cell]:
	_init_spawn_point_picker()
	var cells: Array[Cell] = _spawn_point_picker.get_effective_board_cells()
	_sync_spawn_point_picker_state()
	return cells

func get_nearby_position(A: Vector2, min_distance: float = 0.0, max_distance: float = 100.0) -> Vector2:
	_init_spawn_point_picker()
	_sync_spawn_point_picker_config()
	var spawn_position: Vector2 = _spawn_point_picker.get_nearby_position(A, min_distance, max_distance)
	_sync_spawn_point_picker_state()
	return spawn_position

func _apply_spawn_safety_margin(world_position: Vector2) -> Vector2:
	_init_spawn_point_picker()
	_sync_spawn_point_picker_config()
	var projected: Vector2 = _spawn_point_picker.apply_spawn_safety_margin(world_position)
	_sync_spawn_point_picker_state()
	return projected

func clamp_position(x_value :float, y_value :float) -> Vector2:
	_init_spawn_point_picker()
	return _spawn_point_picker.clamp_position(x_value, y_value)

func _get_random_boundary_position_away_from_player(player_position: Vector2) -> Vector2:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_random_boundary_position_away_from_player(player_position)

func _get_farthest_boundary_point(player_position: Vector2) -> Vector2:
	_init_spawn_point_picker()
	return _spawn_point_picker.get_farthest_boundary_point(player_position)

func erase_all_enemies():
	for enemy in _get_registered_enemies():
		var base_enemy := enemy as BaseEnemy
		if base_enemy != null and is_instance_valid(base_enemy):
			base_enemy.erase()
	for runtime_node in get_tree().get_nodes_in_group("enemy_runtime_cleanup"):
		if runtime_node == null or not is_instance_valid(runtime_node):
			continue
		if runtime_node.has_method("erase"):
			runtime_node.call_deferred("erase")
		else:
			runtime_node.call_deferred("queue_free")

func stop_spawning() -> void:
	if timer != null:
		timer.stop()

func get_active_enemy_count() -> int:
	return _get_total_runtime_alive_count()

func get_spawn_budget_snapshot() -> Dictionary:
	return {
		"planned_total_hp": _planned_target_total_hp,
		"spawned_total_hp": _spawned_total_hp,
		"killed_total_hp": _killed_total_hp,
		"available_hp_budget": _available_hp_budget,
		"planned_enemy_count": _contract_spawn_plan.size(),
		"spawned_enemy_count": _contract_spawn_plan_cursor,
		"stopped": _spawn_budget_stopped,
	}

func get_contract_legal_region_count() -> int:
	return _get_effective_board_cells().size()

func get_contract_beacon_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var player_position: Vector2 = PlayerData.player.global_position if PlayerData.player != null else Vector2.ZERO
	for cell in _get_effective_board_cells():
		if cell != null:
			var cell_center := cell.global_transform * Vector2(256.0, 256.0)
			if cell_center.distance_to(player_position) >= 180.0:
				points.append(cell_center)
	if points.size() < 2:
		return PackedVector2Array()
	var best := PackedVector2Array([points[0], points[1]])
	var best_distance := best[0].distance_to(best[1])
	for first in points:
		for second in points:
			var distance := first.distance_to(second)
			if distance > best_distance:
				best = PackedVector2Array([first, second])
				best_distance = distance
	return best if best_distance >= 300.0 else PackedVector2Array()

func get_contract_objective_points() -> PackedVector2Array:
	var candidates := PackedVector2Array()
	var player_position: Vector2 = PlayerData.player.global_position if PlayerData.player != null else Vector2.ZERO
	for cell in _get_effective_board_cells():
		if cell == null:
			continue
		var cell_center := cell.global_transform * Vector2(256.0, 256.0)
		if cell_center.distance_to(player_position) >= 180.0:
			candidates.append(cell_center)
	if candidates.is_empty():
		return PackedVector2Array()
	var selected := PackedVector2Array()
	var first := candidates[0]
	for point in candidates:
		if point.distance_to(player_position) > first.distance_to(player_position):
			first = point
	selected.append(first)
	while selected.size() < 3 and selected.size() < candidates.size():
		var best_point := Vector2.INF
		var best_min_distance := -1.0
		for candidate in candidates:
			if selected.has(candidate):
				continue
			var min_distance := INF
			for existing in selected:
				min_distance = minf(min_distance, candidate.distance_to(existing))
			if min_distance > best_min_distance:
				best_min_distance = min_distance
				best_point = candidate
		if best_point == Vector2.INF or best_min_distance < 220.0:
			break
		selected.append(best_point)
	return selected

func configure_contract_finite_budget(total_budget: float) -> void:
	_init_spawn_budget_runtime()
	_spawn_budget_runtime.planned_target_total_hp = maxi(int(round(total_budget)), 1)
	_spawn_budget_runtime.combat_budget_active = true
	_sync_spawn_budget_runtime_state()
	_build_contract_spawn_plan(_spawn_budget_runtime.planned_target_total_hp, maxi(PhaseManager.current_level, 0))

func configure_contract_batches(batch_count: int) -> void:
	_contract_batch_count = maxi(batch_count, 1)
	_contract_released_batches = 1

func release_contract_next_batch() -> void:
	_contract_released_batches = mini(_contract_released_batches + 1, _contract_batch_count)

func configure_contract_duration(duration_sec: float) -> void:
	_contract_duration_override_sec = maxi(int(round(duration_sec)), 1)

func configure_contract_continuous_spawning(enabled: bool) -> void:
	_contract_continuous_spawning = enabled

func configure_contract_threat_multiplier(multiplier: float) -> void:
	_contract_threat_multiplier = maxf(multiplier, 0.1)

func release_contract_reinforcement_budget(multiplier: float = 1.0) -> void:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	if not _spawn_budget_runtime.is_combat_budget_ready():
		return
	var level_index := maxi(PhaseManager.current_level, 0)
	var effective_time_out := get_effective_time_out(_runtime_base_time_out, level_index)
	var reinforcement_budget: float = (
		float(_spawn_budget_runtime.resolve_batch_hp_budget(level_index, effective_time_out))
		* clampf(multiplier, 0.0, 10.0)
	)
	_spawn_budget_runtime.available_hp_budget += reinforcement_budget
	_sync_spawn_budget_runtime_state()

func spawn_contract_pursuit_wave(min_count: int, max_count: int) -> int:
	var safe_min := maxi(min_count, 0)
	var safe_max := maxi(max_count, safe_min)
	var target_count := _rng.randi_range(safe_min, safe_max)
	var spawned_count := 0
	var ranged_count := 0
	var count_by_scene: Dictionary = {}
	var profile := _get_spawn_combat_profile()
	while spawned_count < target_count:
		if _get_total_runtime_alive_count() >= profile.default_total_alive_cap:
			break
		var candidates: Array[Dictionary] = []
		var total_weight := 0.0
		for state in _runtime_spawn_states:
			var entry := _get_state_entry(state)
			if entry == null or entry.enemy == null or PhaseManager.battle_time < entry.start_sec:
				continue
			if int(state.get("alive", 0)) >= _get_state_alive_cap(state):
				continue
			var scene_path := _get_spawn_scene_path(state)
			if int(count_by_scene.get(scene_path, 0)) >= _get_same_type_batch_limit(scene_path, profile):
				continue
			if _is_spawn_ranged(state):
				if ranged_count >= int(profile.get("max_ranged_per_batch")):
					continue
				var ranged_alive_cap := int(profile.get("max_ranged_alive_total"))
				if ranged_alive_cap > 0 and _get_total_runtime_ranged_alive_count() >= ranged_alive_cap:
					continue
			var weight := maxf(float(entry.weight), 1.0)
			candidates.append({"state": state, "weight": weight})
			total_weight += weight
		if candidates.is_empty() or total_weight <= 0.0:
			break
		var roll := _rng.randf_range(0.0, total_weight)
		var selected: Dictionary = candidates.back()["state"]
		for candidate in candidates:
			roll -= float(candidate["weight"])
			if roll <= 0.0:
				selected = candidate["state"]
				break
		if _spawn_from_state(selected, 1) <= 0:
			break
		var selected_path := _get_spawn_scene_path(selected)
		count_by_scene[selected_path] = int(count_by_scene.get(selected_path, 0)) + 1
		if _is_spawn_ranged(selected):
			ranged_count += 1
		spawned_count += 1
	return spawned_count

func configure_contract_external_victory(enabled: bool) -> void:
	_contract_external_victory = enabled

func configure_contract_prefer_final_elite(enabled: bool) -> void:
	_contract_prefer_final_elite = enabled

func reset_contract_configuration() -> void:
	_contract_duration_override_sec = 0
	_contract_continuous_spawning = false
	_contract_threat_multiplier = 1.0
	_contract_external_victory = false
	_contract_prefer_final_elite = false
	_contract_batch_count = 0
	_contract_released_batches = 0
	_contract_spawn_plan.clear()
	_contract_spawn_plan_cursor = 0
	_contract_reward_stage = false
	_contract_reward_hp_multiplier = 1.0
	_contract_reward_multiplier = 1.0
	_contract_kill_gold_multiplier = 1.0
	if _kill_gold_budget_runtime != null:
		_kill_gold_budget_runtime.configure_target_multipliers(1.0, 1.0)

func configure_contract_reward_stage(enabled: bool, hp_budget_multiplier: float = 2.0, reward_multiplier: float = 2.0) -> void:
	_contract_reward_stage = enabled
	_contract_reward_hp_multiplier = maxf(hp_budget_multiplier, 1.0) if enabled else 1.0
	_contract_reward_multiplier = maxf(reward_multiplier, 1.0) if enabled else 1.0
	_init_kill_gold_budget_runtime()
	_kill_gold_budget_runtime.configure_target_multipliers(_contract_reward_hp_multiplier, _contract_reward_multiplier * _contract_kill_gold_multiplier)

func configure_contract_kill_gold_multiplier(multiplier: float) -> void:
	_contract_kill_gold_multiplier = clampf(multiplier, 0.0, 1.0)
	_init_kill_gold_budget_runtime()
	_kill_gold_budget_runtime.configure_target_multipliers(_contract_reward_hp_multiplier, _contract_reward_multiplier * _contract_kill_gold_multiplier)

func _build_contract_spawn_plan(total_hp: int, level_index: int) -> void:
	_contract_spawn_plan.clear()
	_contract_spawn_plan_cursor = 0
	if total_hp <= 0 or _runtime_spawn_states.is_empty():
		return
	var planned_hp := 0
	while planned_hp < total_hp:
		var weighted: Array[Dictionary] = []
		var total_weight := 0.0
		for state in _runtime_spawn_states:
			var entry := _get_state_entry(state)
			if entry == null or entry.enemy == null:
				continue
			var weight := maxf(float(entry.weight), 1.0)
			if _contract_prefer_final_elite and float(planned_hp) / float(total_hp) >= 0.8 and _is_spawn_elite(state):
				weight *= 8.0
			weighted.append({"state": state, "weight": weight})
			total_weight += weight
		if weighted.is_empty() or total_weight <= 0.0:
			break
		var roll := _rng.randf_range(0.0, total_weight)
		var selected := weighted.back()["state"] as Dictionary
		for item in weighted:
			roll -= float(item["weight"])
			if roll <= 0.0:
				selected = item["state"] as Dictionary
				break
		_contract_spawn_plan.append(int(selected.get("id", -1)))
		planned_hp += _resolve_budget_candidate_hp(selected, level_index)

func _get_next_contract_planned_candidate(available: Array[Dictionary]) -> Dictionary:
	if _contract_spawn_plan.is_empty() or _contract_spawn_plan_cursor >= _contract_spawn_plan.size():
		return {}
	if _contract_batch_count > 0:
		var released_count := ceili(float(_contract_spawn_plan.size()) * float(_contract_released_batches) / float(_contract_batch_count))
		if _contract_spawn_plan_cursor >= released_count:
			return {}
	for plan_index in range(_contract_spawn_plan_cursor, _contract_spawn_plan.size()):
		var planned_id := _contract_spawn_plan[plan_index]
		for state in available:
			if int(state.get("id", -1)) != planned_id:
				continue
			if plan_index != _contract_spawn_plan_cursor:
				_contract_spawn_plan[plan_index] = _contract_spawn_plan[_contract_spawn_plan_cursor]
				_contract_spawn_plan[_contract_spawn_plan_cursor] = planned_id
			return state
	return {}

func _get_registered_enemies() -> Array[Node2D]:
	var output: Array[Node2D] = []
	var registry := get_node_or_null("/root/EnemyRegistry")
	if registry != null and registry.has_method("get_enemies"):
		var registered_enemies: Variant = registry.call("get_enemies")
		if registered_enemies is Array:
			for enemy_ref in registered_enemies:
				var enemy := enemy_ref as Node2D
				if enemy != null and is_instance_valid(enemy):
					output.append(enemy)
			return output
	for enemy_ref in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_ref as Node2D
		if enemy != null and is_instance_valid(enemy):
			output.append(enemy)
	return output

func _apply_level_scaling(_state: Dictionary, enemy_instance) -> void:
	if enemy_instance is BaseEnemy:
		var base_enemy : BaseEnemy = enemy_instance
		var level_index = max(PhaseManager.current_level, 0)
		var scaled_stats := calculate_scaled_enemy_stats(base_enemy.hp, base_enemy.damage, level_index)
		base_enemy.hp = int(scaled_stats.get("hp", base_enemy.hp))
		base_enemy.damage = int(scaled_stats.get("damage", base_enemy.damage))

func calculate_scaled_enemy_stats(
	fallback_hp: int,
	fallback_damage: int,
	level_index: int
) -> Dictionary:
	var scaled_hp := maxi(fallback_hp, 1)
	var scaled_damage := maxi(fallback_damage, 0)
	var overflow_level := _resolve_infinite_overflow_level(level_index)
	if overflow_level > 0:
		var profile: SpawnCombatProfile = _get_spawn_combat_profile()
		scaled_hp = max(1, int(round(float(scaled_hp) * pow(1.0 + float(profile.get("infinite_hp_growth_per_level")), float(overflow_level)))))
		scaled_damage = max(1, int(round(float(scaled_damage) * pow(1.0 + float(profile.get("infinite_damage_growth_per_level")), float(overflow_level)))))
	return {"hp": scaled_hp, "damage": scaled_damage}

func _prepare_level_combat_budget(level_index: int, effective_time_out: int) -> void:
	_init_spawn_budget_runtime()
	_spawn_budget_runtime.prepare_level_combat_budget(level_index, effective_time_out)
	if _contract_reward_stage:
		_spawn_budget_runtime.planned_target_total_hp = maxi(int(round(float(_spawn_budget_runtime.planned_target_total_hp) * _contract_reward_hp_multiplier)), 1)
	_sync_spawn_budget_runtime_state()

func _record_enemy_death_for_budget_summary(enemy_instance: Node, was_killed: bool) -> void:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	_spawn_budget_runtime.record_enemy_death_for_budget_summary(enemy_instance, was_killed)
	_sync_spawn_budget_runtime_state()

func _print_spawn_budget_battle_summary(level_index: int, effective_time_out: int) -> void:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	_spawn_budget_runtime.print_spawn_budget_battle_summary(level_index, effective_time_out)
	_sync_spawn_budget_runtime_state()

func print_kill_gold_debug_summary(context: String = "manual") -> void:
	_print_kill_gold_debug_summary(context, maxi(PhaseManager.current_level, 0))

func _print_kill_gold_debug_summary(context: String, level_index: int) -> void:
	_init_kill_gold_budget_runtime()
	_sync_kill_gold_budget_config()
	_sync_kill_gold_owner_state_to_runtime()
	_kill_gold_budget_runtime.print_kill_gold_debug_summary(context, level_index)
	_sync_kill_gold_budget_runtime_state()

func _get_remaining_coin_value() -> int:
	_init_kill_gold_budget_runtime()
	return int(_kill_gold_budget_runtime.get_remaining_coin_value())

func _get_remaining_coin_count() -> int:
	_init_kill_gold_budget_runtime()
	return int(_kill_gold_budget_runtime.get_remaining_coin_count())

func _get_registered_coins() -> Array[Coin]:
	_init_kill_gold_budget_runtime()
	return _kill_gold_budget_runtime.get_registered_coins()

func _is_uncollected_coin(collectable: Node) -> bool:
	_init_kill_gold_budget_runtime()
	return bool(_kill_gold_budget_runtime.is_uncollected_coin(collectable))

func _release_remaining_spawn_budget() -> void:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	_spawn_budget_runtime.release_remaining_spawn_budget()
	_sync_spawn_budget_runtime_state()

func _update_spawn_budget_stop_state() -> void:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	_spawn_budget_runtime.update_spawn_budget_stop_state()
	if _spawn_budget_runtime.spawn_budget_stopped and _contract_continuous_spawning:
		_spawn_budget_runtime.planned_target_total_hp += maxi(_spawn_budget_runtime.planned_target_total_hp, 1)
		_spawn_budget_runtime.spawn_budget_stopped = false
		_spawn_budget_runtime.budget_release_finished = false
	_sync_spawn_budget_runtime_state()
	if _spawn_budget_stopped and not _spawn_budget_stop_emitted:
		_spawn_budget_stop_emitted = true
		spawn_budget_stopped.emit()

func _try_finish_battle_after_spawn_budget_stop() -> void:
	if _contract_external_victory:
		return
	if PhaseManager == null or PhaseManager.current_state() != PhaseManager.BATTLE:
		return
	if not _should_end_after_spawn_budget_stopped():
		return
	var level_index := maxi(PhaseManager.current_level, 0)
	var effective_time_out := get_effective_time_out(_runtime_base_time_out, level_index)
	finish_battle_with_victory(level_index, effective_time_out)

func finish_battle_with_victory(level_index: int = -1, effective_time_out: int = -1) -> void:
	if _battle_victory_transition_active or PhaseManager.current_state() != PhaseManager.BATTLE:
		return
	if level_index < 0:
		level_index = maxi(PhaseManager.current_level, 0)
	if effective_time_out < 0:
		effective_time_out = get_effective_time_out(_runtime_base_time_out, level_index)
	_battle_victory_transition_active = true
	if timer != null:
		timer.stop()
	_print_spawn_budget_battle_summary(level_index, effective_time_out)
	erase_all_enemies()
	var ui := GlobalVariables.ui
	if ui != null and is_instance_valid(ui) and ui.has_method("play_victory_transition"):
		await ui.call("play_victory_transition")
	if PhaseManager.current_state() == PhaseManager.BATTLE:
		PhaseManager.enter_prepare()
	_battle_victory_transition_active = false

func _calculate_pressure_budget_total(release_duration_sec: int) -> float:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	return float(_spawn_budget_runtime.calculate_pressure_budget_total(release_duration_sec))

func _resolve_budget_candidate_hp(state: Dictionary, level_index: int) -> int:
	_init_spawn_budget_runtime()
	return int(_spawn_budget_runtime.resolve_budget_candidate_hp(state, level_index))

func _resolve_budget_candidate_hp_from_spawner(state: Dictionary, level_index: int) -> int:
	var fallback_hp := _get_enemy_scene_default_hp(state)
	var fallback_damage := _get_enemy_scene_default_damage(state)
	var scaled_stats := calculate_scaled_enemy_stats(fallback_hp, fallback_damage, level_index)
	return maxi(int(scaled_stats.get("hp", fallback_hp)), 1)

func _get_enemy_scene_default_hp(state: Dictionary) -> int:
	var entry := _get_state_entry(state)
	if entry == null:
		return 1
	var metadata := _get_enemy_metadata(_get_spawn_scene_path(state), entry.enemy)
	return maxi(int(metadata.get("base_hp", 1)), 1)

func _get_enemy_scene_default_damage(state: Dictionary) -> int:
	var entry := _get_state_entry(state)
	if entry == null:
		return 0
	var metadata := _get_enemy_metadata(_get_spawn_scene_path(state), entry.enemy)
	return maxi(int(metadata.get("base_damage", 0)), 0)

func _get_same_type_batch_limit(_scene_path: String, profile: SpawnCombatProfile) -> int:
	var base_limit := maxi(int(profile.get("max_same_type_per_batch")), 1)
	return base_limit

func _is_combat_budget_ready() -> bool:
	_init_spawn_budget_runtime()
	_sync_spawn_budget_owner_state_to_runtime()
	return bool(_spawn_budget_runtime.is_combat_budget_ready())

func get_effective_time_out(base_time_out: int, level_index: int) -> int:
	if _contract_duration_override_sec > 0:
		return _contract_duration_override_sec
	var safe_base: int = max(base_time_out, 1)
	return safe_base

func _debug_log_spawned_enemy(enemy_instance) -> void:
	if not debug_print_spawn_stats:
		return
	if enemy_instance is BaseEnemy:
		var base_enemy := enemy_instance as BaseEnemy
		print(
			"[Spawn] level=%s enemy=%s hp=%s damage=%s"
			% [PhaseManager.current_level, base_enemy.name, base_enemy.hp, base_enemy.damage]
		)

func _build_runtime_spawn_context(level_index: int) -> bool:
	if instance_list.is_empty():
		return false
	var safe_level_index := maxi(level_index, 0)
	if safe_level_index < instance_list.size():
		_runtime_spawn_states = _build_runtime_states(instance_list[safe_level_index])
		_apply_reward_stage_spawn_override()
		var fallback_timeout := 30
		var level_config := SpawnData.level_list[safe_level_index]
		if level_config != null:
			fallback_timeout = max(1, int(level_config.time_out_sec))
		_runtime_base_time_out = _resolve_level_time_out_for_budget(safe_level_index, fallback_timeout)
		return not _runtime_spawn_states.is_empty()
	var mixed_spawns: Array = []
	for level_spawns_variant in instance_list:
		if not (level_spawns_variant is Array):
			continue
		for entry in level_spawns_variant as Array:
			mixed_spawns.append(entry)
	_runtime_spawn_states = _build_runtime_states(mixed_spawns)
	_apply_reward_stage_spawn_override()
	var overflow_fallback := 30
	if not SpawnData.level_list.is_empty():
		var last_level_config: LevelCombatPlan = SpawnData.level_list.back() as LevelCombatPlan
		if last_level_config != null:
			overflow_fallback = max(1, int(last_level_config.time_out_sec))
	_runtime_base_time_out = _resolve_level_time_out_for_budget(safe_level_index, overflow_fallback)
	return not _runtime_spawn_states.is_empty()

func _apply_reward_stage_spawn_override() -> void:
	if not _contract_reward_stage:
		return
	var entry := EnemySpawnEntry.new()
	entry.enemy = REWARD_ENEMY_SCENE
	entry.start_sec = 1
	entry.weight = 1
	_runtime_spawn_states = _build_runtime_states([entry])

func _resolve_level_time_out_for_budget(level_index: int, fallback_time_out: int) -> int:
	var safe_fallback: int = maxi(int(fallback_time_out), 1)
	var budget_profile: SpawnCombatProfile = _get_spawn_combat_profile()
	if budget_profile == null or not budget_profile.has_method("get_level_time_out"):
		return safe_fallback
	return max(1, int(budget_profile.call("get_level_time_out", level_index, safe_fallback)))

func _build_runtime_states(entries: Array) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var idx := 0
	for entry_variant in entries:
		var entry := entry_variant as EnemySpawnEntry
		if entry == null:
			continue
		states.append({
			"id": idx,
			"entry": entry,
			"alive": 0,
			"cooldown": 0,
		})
		idx += 1
	return states

func _resolve_infinite_overflow_level(level_index: int) -> int:
	return int(_get_spawn_combat_profile().call("get_infinite_overflow_level", level_index))

func debug_get_infinite_overflow_level(level_index: int) -> int:
	return _resolve_infinite_overflow_level(level_index)

func debug_get_runtime_spawn_pool_size_for_level(level_index: int) -> int:
	if not _build_runtime_spawn_context(level_index):
		return 0
	return _runtime_spawn_states.size()

func _get_spawn_combat_profile() -> SpawnCombatProfile:
	var profile: SpawnCombatProfile = SpawnData.get_spawn_combat_profile()
	if profile != null:
		return profile
	_fallback_spawn_combat_profile.sanitize()
	return _fallback_spawn_combat_profile
