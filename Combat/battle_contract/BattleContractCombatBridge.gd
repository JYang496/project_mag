extends "res://Combat/battle_contract/BattleContractCombatPort.gd"
class_name BattleContractCombatBridge

var _spawner: Node
var _next_enemy_id := 1
var _enemy_by_id: Dictionary = {}
var _requested_config: Dictionary = {}
var _enemy_motion: Dictionary = {}
var _monitor_enemy_stalls := false
var _stall_sample_elapsed_sec := 0.0
const ENEMY_RECOVERY_TIMEOUT_SEC := 8.0
const ENEMY_RECOVERY_MIN_DISTANCE := 900.0
const ENEMY_RECOVERY_APPROACH_EPSILON := 1.0
var _beacons: Dictionary = {}
var _beacon_beam: Line2D
const BEACON_SCENE := preload("res://World/battle_contract/tactical_beacon.tscn")
const CONTRACT_MORTAR_STRIKE := preload("res://Combat/battle_contract/hazards/contract_mortar_strike.gd")
var _contract_hazards: Array[Node] = []
const EliminationIndicatorLayer := preload("res://UI/scripts/components/elimination_enemy_indicator_layer.gd")
const ELIMINATION_INDICATOR_CANVAS_NAME := "EliminationEnemyIndicators"
var _elimination_indicator_canvas: CanvasLayer
var _elimination_indicator: Control

func bind(spawner: EnemySpawner) -> void:
	unbind()
	_spawner = spawner
	if _spawner == null:
		return
	_spawner.combat_tick.connect(_on_combat_tick)
	_spawner.enemy_spawned.connect(_on_enemy_spawned)
	_spawner.enemy_died.connect(_on_enemy_died)
	_spawner.spawn_budget_stopped.connect(_on_spawn_budget_stopped)
	_spawner.combat_frame.connect(_on_combat_frame)
	PhaseManager.phase_changed.connect(_on_phase_changed)

func unbind() -> void:
	if _spawner != null:
		_disconnect(_spawner.combat_tick, _on_combat_tick)
		_disconnect(_spawner.enemy_spawned, _on_enemy_spawned)
		_disconnect(_spawner.enemy_died, _on_enemy_died)
		_disconnect(_spawner.spawn_budget_stopped, _on_spawn_budget_stopped)
		_disconnect(_spawner.combat_frame, _on_combat_frame)
	_disconnect(PhaseManager.phase_changed, _on_phase_changed)
	_spawner = null
	_enemy_by_id.clear()
	_enemy_motion.clear()
	_monitor_enemy_stalls = false
	_stall_sample_elapsed_sec = 0.0
	_remove_elimination_indicator()
	request_remove_beacons()
	request_clear_contract_hazards()

func get_level_index() -> int:
	return maxi(PhaseManager.current_level, 0)

func get_level_duration_sec() -> float:
	var plan := _get_level_plan()
	return float(maxi(plan.time_out_sec, 1)) if plan != null else 30.0

func is_boss_battle() -> bool:
	var plan := _get_level_plan()
	return plan != null and plan.is_boss

func get_battle_intro_snapshot() -> Dictionary:
	var plan := _get_level_plan()
	if plan == null:
		return {}
	return {
		"is_boss": plan.is_boss,
		"time_out_sec": plan.time_out_sec,
		"target_total_hp": plan.target_total_hp,
		"level": get_level_index() + 1,
	}

func get_allowed_contracts() -> Array[StringName]:
	var plan := _get_level_plan()
	var allowed_contracts: Array[StringName] = []
	if plan != null:
		allowed_contracts.assign(plan.allowed_contracts)
	return allowed_contracts

func get_battlefield_capabilities() -> Dictionary:
	var points := PackedVector2Array()
	var objective_points := PackedVector2Array()
	if _spawner != null:
		points = _spawner.get_contract_beacon_points()
		objective_points = _spawner.get_contract_objective_points()
	return {
		"allowed_contracts": get_allowed_contracts(),
		"legal_region_count": points.size(),
		"supports_operation": points.size() >= 2,
		"operation_beacon_points": points,
		"supports_containment": objective_points.size() >= 3,
		"containment_points": objective_points,
		"supports_extraction": not objective_points.is_empty(),
		"extraction_points": objective_points,
	}

func request_start_spawning() -> void:
	if _spawner != null:
		_spawner.start_timer()

func request_stop_spawning() -> void:
	if _spawner != null:
		_spawner.stop_spawning()

func request_external_victory_control(enabled: bool) -> void:
	if _spawner != null:
		_spawner.configure_contract_external_victory(enabled)

func request_configure_finite_budget(total_budget: float, batch_count: int) -> void:
	_requested_config["finite_budget"] = maxf(total_budget, 0.0)
	_requested_config["batch_count"] = maxi(batch_count, 1)
	if _spawner != null:
		_spawner.configure_contract_finite_budget(total_budget)
		_spawner.configure_contract_batches(batch_count)

func request_prefer_elite_final_batch(enabled: bool) -> void:
	if _spawner != null:
		_spawner.configure_contract_prefer_final_elite(enabled)

func request_set_elimination_guidance(enabled: bool) -> void:
	if not enabled:
		_remove_elimination_indicator()
		return
	_ensure_elimination_indicator()
	_sync_elimination_indicator_targets()

func request_release_next_batch() -> void:
	if _spawner != null:
		_spawner.release_contract_next_batch()

func request_configure_continuous_spawning(enabled: bool) -> void:
	_requested_config["continuous_spawning"] = enabled
	if _spawner != null:
		_spawner.configure_contract_continuous_spawning(enabled)

func request_configure_spawn_policy(
	mode: StringName,
	soft_cap_multiplier: float,
	hard_cap_multiplier: float
) -> void:
	_requested_config["spawn_policy"] = {
		"mode": mode,
		"soft_cap_multiplier": soft_cap_multiplier,
		"hard_cap_multiplier": hard_cap_multiplier,
	}
	if _spawner != null:
		_spawner.configure_contract_spawn_policy(mode, soft_cap_multiplier, hard_cap_multiplier)

func request_configure_duration(duration_sec: float) -> void:
	_requested_config["duration_sec"] = maxf(duration_sec, 1.0)
	if _spawner != null:
		_spawner.configure_contract_duration(duration_sec)

func request_configure_threat_multiplier(multiplier: float) -> void:
	_requested_config["threat_multiplier"] = maxf(multiplier, 0.0)
	if _spawner != null:
		_spawner.configure_contract_threat_multiplier(multiplier)

func request_configure_spawn_frequency_multiplier(multiplier: float) -> void:
	_requested_config["spawn_frequency_multiplier"] = maxf(multiplier, 0.1)
	if _spawner != null:
		_spawner.configure_contract_spawn_frequency_multiplier(multiplier)

func request_release_reinforcement_budget(multiplier: float = 1.0) -> void:
	if _spawner != null:
		_spawner.release_contract_reinforcement_budget(multiplier)

func request_spawn_pursuit_wave(min_count: int, max_count: int) -> int:
	if _spawner == null:
		return 0
	return _spawner.spawn_contract_pursuit_wave(min_count, max_count)

func request_spawn_contract_elite(target_hp: int) -> bool:
	return _spawner.spawn_contract_elite(target_hp) if _spawner != null else false

func request_spawn_mortar_barrage(options: Dictionary) -> int:
	if _spawner == null or PlayerData.player == null:
		return 0
	_contract_hazards = _contract_hazards.filter(func(item): return item != null and is_instance_valid(item))
	var minimum := maxi(int(options.get("strike_count_min", 2)), 1)
	var maximum := maxi(int(options.get("strike_count_max", 3)), minimum)
	var count := randi_range(minimum, maximum)
	var spread := maxf(float(options.get("spread_radius", 110.0)), 0.0)
	var player_position := (PlayerData.player as Node2D).global_position
	for index in count:
		var angle := TAU * float(index) / float(maxi(count, 1)) + randf_range(-0.35, 0.35)
		var radius := randf_range(spread * 0.45, spread)
		var strike := CONTRACT_MORTAR_STRIKE.new()
		strike.global_position = player_position + Vector2.from_angle(angle) * radius
		strike.warning_duration_sec = maxf(float(options.get("warning_duration_sec", 1.5)), 0.1)
		strike.blast_radius = maxf(float(options.get("blast_radius", 62.0)), 8.0)
		strike.damage = maxi(int(round(float(PlayerData.player_max_hp) * float(options.get("player_max_hp_ratio", 0.12)))), 1)
		_spawner.get_parent().add_child(strike)
		_contract_hazards.append(strike)
	return count

func request_clear_contract_hazards() -> void:
	for hazard in _contract_hazards:
		if hazard != null and is_instance_valid(hazard): hazard.queue_free()
	_contract_hazards.clear()

func request_configure_contract_economy(kill_gold_multiplier: float) -> void:
	if _spawner != null:
		_spawner.configure_contract_kill_gold_multiplier(kill_gold_multiplier)

func request_configure_reward_stage(enabled: bool, hp_budget_multiplier: float = 2.0, reward_multiplier: float = 2.0) -> void:
	if _spawner != null:
		_spawner.configure_contract_reward_stage(enabled, hp_budget_multiplier, reward_multiplier)

func get_active_enemy_count() -> int:
	return _spawner.get_active_enemy_count() if _spawner != null else 0

func get_spawn_budget_snapshot() -> Dictionary:
	return _spawner.get_spawn_budget_snapshot() if _spawner != null else {}

func request_evacuate_enemies(_options: Dictionary = {}) -> void:
	if _spawner != null:
		_spawner.erase_all_enemies()

func request_relocate_enemies(options: Dictionary = {}) -> void:
	if _spawner == null:
		return
	var enemy_id := int(options.get("enemy_id", 0))
	var enemy := _enemy_by_id.get(enemy_id) as Node2D
	if enemy != null and is_instance_valid(enemy):
		enemy.global_position = _spawner.get_random_position()
		EnemyRegistry.update_enemy_position(enemy)

func request_monitor_enemy_stalls(enabled: bool) -> void:
	_monitor_enemy_stalls = enabled
	_stall_sample_elapsed_sec = 0.0
	if not enabled:
		_enemy_motion.clear()

func request_finish_battle(_result: Dictionary = {}) -> void:
	if _spawner != null:
		_spawner.finish_battle_with_victory()

func request_player_heal(amount: int) -> void:
	if amount > 0:
		PlayerData.player_hp = mini(PlayerData.player_hp + amount, PlayerData.player_max_hp)

func request_spawn_beacon(beacon_id: int, position: Vector2) -> void:
	if _spawner == null or _beacons.has(beacon_id):
		return
	var previous_position := Vector2.INF
	if not _beacons.is_empty():
		var previous = _beacons.values()[0]
		if previous != null and is_instance_valid(previous): previous_position = previous.position
	request_remove_beacons()
	var beacon = BEACON_SCENE.instantiate()
	beacon.position = position
	beacon.beacon_id = beacon_id
	beacon.visual_kind = &"operation"
	beacon.presence_changed.connect(_on_beacon_presence_changed)
	_spawner.get_parent().add_child(beacon)
	_beacons[beacon_id] = beacon
	if previous_position != Vector2.INF:
		_beacon_beam = Line2D.new()
		_beacon_beam.width = 5.0
		_beacon_beam.default_color = Color(0.91, 0.79, 0.42, 0.9)
		_beacon_beam.points = PackedVector2Array([previous_position, position])
		_spawner.get_parent().add_child(_beacon_beam)
		var tween := _beacon_beam.create_tween()
		tween.tween_property(_beacon_beam, "modulate:a", 0.0, 0.8)
		tween.finished.connect(_beacon_beam.queue_free)

func request_spawn_objective(objective_id: int, position: Vector2, visual_kind: StringName = &"containment") -> void:
	if _spawner == null or _beacons.has(objective_id):
		return
	var beacon = BEACON_SCENE.instantiate()
	beacon.position = position
	beacon.beacon_id = objective_id
	beacon.visual_kind = visual_kind
	beacon.presence_changed.connect(_on_beacon_presence_changed)
	_spawner.get_parent().add_child(beacon)
	_beacons[objective_id] = beacon

func request_update_beacon(beacon_id: int, progress: float) -> void:
	var beacon = _beacons.get(beacon_id)
	if beacon != null and is_instance_valid(beacon):
		beacon.set_progress(progress)

func request_complete_beacon(beacon_id: int) -> void:
	var beacon = _beacons.get(beacon_id)
	if beacon != null and is_instance_valid(beacon):
		beacon.play_completion()

func request_remove_beacons() -> void:
	for beacon in _beacons.values():
		if beacon != null and is_instance_valid(beacon):
			if beacon.is_inside_tree() and beacon.is_visually_completed():
				beacon.play_completion_and_remove()
			else:
				beacon.queue_free()
	_beacons.clear()
	if _beacon_beam != null and is_instance_valid(_beacon_beam):
		_beacon_beam.queue_free()
	_beacon_beam = null

func _ensure_elimination_indicator() -> void:
	if _elimination_indicator != null and is_instance_valid(_elimination_indicator):
		return
	if _spawner == null or not is_instance_valid(_spawner):
		return
	_elimination_indicator_canvas = CanvasLayer.new()
	_elimination_indicator_canvas.name = ELIMINATION_INDICATOR_CANVAS_NAME
	_elimination_indicator_canvas.layer = 5
	_spawner.get_tree().root.add_child(_elimination_indicator_canvas)
	_elimination_indicator = EliminationIndicatorLayer.new()
	_elimination_indicator.name = "IndicatorLayer"
	_elimination_indicator_canvas.add_child(_elimination_indicator)

func _sync_elimination_indicator_targets() -> void:
	if _elimination_indicator != null and is_instance_valid(_elimination_indicator):
		_elimination_indicator.call("set_targets", _enemy_by_id)

func _remove_elimination_indicator() -> void:
	if _elimination_indicator_canvas != null and is_instance_valid(_elimination_indicator_canvas):
		_elimination_indicator_canvas.queue_free()
	_elimination_indicator_canvas = null
	_elimination_indicator = null

func _get_level_plan() -> LevelCombatPlan:
	SpawnData.ensure_loaded()
	var level_index := get_level_index()
	if level_index < 0 or level_index >= SpawnData.level_list.size():
		return null
	return SpawnData.level_list[level_index] as LevelCombatPlan

func _on_combat_tick() -> void:
	battle_tick.emit({
		"elapsed_sec": PhaseManager.battle_time,
		"remaining_sec": PhaseManager.get_battle_time_remaining(),
		"active_enemy_count": get_active_enemy_count(),
	})

func _on_enemy_spawned(enemy: Node) -> void:
	if enemy == null:
		return
	var enemy_id := _next_enemy_id
	_next_enemy_id += 1
	_enemy_by_id[enemy_id] = enemy
	_sync_elimination_indicator_targets()
	if _monitor_enemy_stalls:
		_enemy_motion[enemy_id] = _new_enemy_motion_snapshot(enemy)
	enemy.set_meta("_battle_contract_enemy_id", enemy_id)
	enemy_spawned.emit(_enemy_snapshot(enemy, enemy_id))

func _on_enemy_died(enemy: Node, was_killed: bool) -> void:
	var enemy_id := int(enemy.get_meta("_battle_contract_enemy_id", 0)) if enemy != null else 0
	var snapshot := _enemy_snapshot(enemy, enemy_id)
	snapshot["was_killed"] = was_killed
	enemy_died.emit(snapshot)
	_enemy_by_id.erase(enemy_id)
	_enemy_motion.erase(enemy_id)
	_sync_elimination_indicator_targets()

func _on_spawn_budget_stopped() -> void:
	spawn_budget_exhausted.emit(get_spawn_budget_snapshot())

func _on_combat_frame(delta_sec: float) -> void:
	battle_tick.emit({"delta_sec": delta_sec, "active_enemy_count": get_active_enemy_count()})
	if not _monitor_enemy_stalls:
		return
	_stall_sample_elapsed_sec += delta_sec
	if _stall_sample_elapsed_sec < 0.25:
		return
	var sample_delta := _stall_sample_elapsed_sec
	_stall_sample_elapsed_sec = 0.0
	var player := PlayerData.player as Node2D
	for enemy_id in _enemy_by_id:
		var enemy := _enemy_by_id[enemy_id] as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var motion: Dictionary = _enemy_motion.get(enemy_id, _new_enemy_motion_snapshot(enemy))
		var previous: Vector2 = motion.get("position", enemy.global_position)
		var stalled := float(motion.get("stalled_sec", 0.0))
		stalled = stalled + sample_delta if previous.distance_squared_to(enemy.global_position) < 4.0 else 0.0
		var stranded := float(motion.get("stranded_sec", 0.0))
		var distance_to_player := enemy.global_position.distance_to(player.global_position) if player != null and is_instance_valid(player) else 0.0
		var previous_distance := float(motion.get("distance_to_player", distance_to_player))
		if distance_to_player >= ENEMY_RECOVERY_MIN_DISTANCE and previous_distance - distance_to_player < ENEMY_RECOVERY_APPROACH_EPSILON:
			stranded += sample_delta
		else:
			stranded = 0.0
		if stalled >= ENEMY_RECOVERY_TIMEOUT_SEC or stranded >= ENEMY_RECOVERY_TIMEOUT_SEC:
			enemy.global_position = _spawner.get_random_position()
			EnemyRegistry.update_enemy_position(enemy)
			stalled = 0.0
			stranded = 0.0
			distance_to_player = enemy.global_position.distance_to(player.global_position) if player != null and is_instance_valid(player) else 0.0
		motion["position"] = enemy.global_position
		motion["stalled_sec"] = stalled
		motion["stranded_sec"] = stranded
		motion["distance_to_player"] = distance_to_player
		_enemy_motion[enemy_id] = motion

func _new_enemy_motion_snapshot(enemy: Node2D) -> Dictionary:
	var player := PlayerData.player as Node2D
	var distance_to_player := enemy.global_position.distance_to(player.global_position) if player != null and is_instance_valid(player) else 0.0
	return {"position": enemy.global_position, "stalled_sec": 0.0, "stranded_sec": 0.0, "distance_to_player": distance_to_player}

func _on_beacon_presence_changed(beacon_id: int, player_inside: bool, enemy_count: int) -> void:
	beacon_presence_changed.emit({"beacon_id": beacon_id, "player_inside": player_inside, "enemy_count": enemy_count})

func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.GAMEOVER:
		battle_aborted.emit({"reason": "game_over"})
		request_stop_spawning()
		request_evacuate_enemies()
		request_remove_beacons()
		request_clear_contract_hazards()
		_remove_elimination_indicator()
		_spawner.reset_contract_configuration()
	elif new_phase == PhaseManager.SETTLEMENT:
		request_stop_spawning()
		_enemy_by_id.clear()
		request_remove_beacons()
		request_clear_contract_hazards()
		_remove_elimination_indicator()
		_spawner.reset_contract_configuration()

func _enemy_snapshot(enemy: Node, enemy_id: int) -> Dictionary:
	if enemy == null:
		return {"enemy_id": enemy_id, "scaled_hp": 0, "is_elite": false}
	var tags: Array = enemy.get("spawn_tags") if enemy.get("spawn_tags") is Array else []
	return {
		"enemy_id": enemy_id,
		"scaled_hp": maxi(int(enemy.get_meta("_spawn_budget_scaled_hp", 1)), 1),
		"is_elite": tags.has(BaseEnemy.SPAWN_TAG_ELITE),
	}

func _disconnect(source_signal: Signal, callback: Callable) -> void:
	if source_signal.is_connected(callback):
		source_signal.disconnect(callback)
