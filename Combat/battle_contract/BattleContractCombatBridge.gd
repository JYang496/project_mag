extends "res://Combat/battle_contract/BattleContractCombatPort.gd"
class_name BattleContractCombatBridge

var _spawner: Node
var _next_enemy_id := 1
var _enemy_by_id: Dictionary = {}
var _requested_config: Dictionary = {}
var _enemy_motion: Dictionary = {}
var _monitor_enemy_stalls := false
var _stall_sample_elapsed_sec := 0.0
var _beacons: Dictionary = {}
var _beacon_beam: Line2D
const BEACON_SCENE := preload("res://World/battle_contract/tactical_beacon.tscn")

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
	request_remove_beacons()

func get_level_index() -> int:
	return maxi(PhaseManager.current_level, 0)

func is_boss_battle() -> bool:
	var plan := _get_level_plan()
	return plan != null and plan.is_boss

func get_allowed_contracts() -> Array[StringName]:
	var plan := _get_level_plan()
	return plan.allowed_contracts.duplicate() if plan != null else []

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

func request_release_next_batch() -> void:
	if _spawner != null:
		_spawner.release_contract_next_batch()

func request_configure_continuous_spawning(enabled: bool) -> void:
	_requested_config["continuous_spawning"] = enabled
	if _spawner != null:
		_spawner.configure_contract_continuous_spawning(enabled)

func request_configure_duration(duration_sec: float) -> void:
	_requested_config["duration_sec"] = maxf(duration_sec, 1.0)
	if _spawner != null:
		_spawner.configure_contract_duration(duration_sec)

func request_configure_threat_multiplier(multiplier: float) -> void:
	_requested_config["threat_multiplier"] = maxf(multiplier, 0.0)
	if _spawner != null:
		_spawner.configure_contract_threat_multiplier(multiplier)

func request_release_reinforcement_budget(multiplier: float = 1.0) -> void:
	if _spawner != null:
		_spawner.release_contract_reinforcement_budget(multiplier)

func request_spawn_pursuit_wave(min_count: int, max_count: int) -> int:
	if _spawner == null:
		return 0
	return _spawner.spawn_contract_pursuit_wave(min_count, max_count)

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

func request_spawn_objective(objective_id: int, position: Vector2) -> void:
	if _spawner == null or _beacons.has(objective_id):
		return
	var beacon = BEACON_SCENE.instantiate()
	beacon.position = position
	beacon.beacon_id = objective_id
	beacon.presence_changed.connect(_on_beacon_presence_changed)
	_spawner.get_parent().add_child(beacon)
	_beacons[objective_id] = beacon

func request_update_beacon(beacon_id: int, progress: float) -> void:
	var beacon = _beacons.get(beacon_id)
	if beacon != null and is_instance_valid(beacon):
		beacon.set_progress(progress)

func request_remove_beacons() -> void:
	for beacon in _beacons.values():
		if beacon != null and is_instance_valid(beacon):
			beacon.queue_free()
	_beacons.clear()
	if _beacon_beam != null and is_instance_valid(_beacon_beam):
		_beacon_beam.queue_free()
	_beacon_beam = null

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
	if _monitor_enemy_stalls:
		_enemy_motion[enemy_id] = {"position": enemy.global_position, "stalled_sec": 0.0}
	enemy.set_meta("_battle_contract_enemy_id", enemy_id)
	enemy_spawned.emit(_enemy_snapshot(enemy, enemy_id))

func _on_enemy_died(enemy: Node, was_killed: bool) -> void:
	var enemy_id := int(enemy.get_meta("_battle_contract_enemy_id", 0)) if enemy != null else 0
	var snapshot := _enemy_snapshot(enemy, enemy_id)
	snapshot["was_killed"] = was_killed
	enemy_died.emit(snapshot)
	_enemy_by_id.erase(enemy_id)
	_enemy_motion.erase(enemy_id)

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
	for enemy_id in _enemy_by_id:
		var enemy := _enemy_by_id[enemy_id] as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var motion: Dictionary = _enemy_motion.get(enemy_id, {"position": enemy.global_position, "stalled_sec": 0.0})
		var previous: Vector2 = motion.get("position", enemy.global_position)
		var stalled := float(motion.get("stalled_sec", 0.0))
		stalled = stalled + sample_delta if previous.distance_squared_to(enemy.global_position) < 4.0 else 0.0
		if stalled >= 8.0:
			enemy.global_position = _spawner.get_random_position()
			stalled = 0.0
		motion["position"] = enemy.global_position
		motion["stalled_sec"] = stalled
		_enemy_motion[enemy_id] = motion

func _on_beacon_presence_changed(beacon_id: int, player_inside: bool, enemy_count: int) -> void:
	beacon_presence_changed.emit({"beacon_id": beacon_id, "player_inside": player_inside, "enemy_count": enemy_count})

func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.GAMEOVER:
		battle_aborted.emit({"reason": "game_over"})
		request_stop_spawning()
		request_evacuate_enemies()
		request_remove_beacons()
		_spawner.reset_contract_configuration()
	elif new_phase == PhaseManager.PREPARE:
		request_stop_spawning()
		_enemy_by_id.clear()
		request_remove_beacons()
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
