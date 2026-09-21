extends Node

# The production target is forty simultaneous enemies. Start the existing
# bounded-cadence path before that target is saturated instead of waiting for a
# stress-only population that normal encounters never reach.
const DENSE_CROWD_THRESHOLD := 24
const INVALID_PRUNE_INTERVAL_SEC := 0.5

var _enemies: Array[BaseEnemy] = []
var _ids: Dictionary = {}
var _enemy_index_by_id: Dictionary = {}
var _cursor := 0
var _invalid_prune_remaining := 0.0
var _last_step_usec := 0
var _peak_step_usec := 0
var _processed_last_frame := 0
var _total_step_usec := 0
var _physics_tick_count := 0
var _prune_total_usec := 0
var _enemy_call_total_usec := 0
var _movement_separation_usec := 0
var _movement_slide_usec := 0
var _movement_accept_usec := 0
var _movement_sync_usec := 0
var _movement_calls := 0
var _constraint_total_usec := 0
var _constraint_calls := 0
var _constraint_full_refreshes := 0
var detailed_profiling_enabled := false


func get_registered_enemy_count() -> int:
	# The central scheduler owns this compact live set and prunes it once at the
	# start of every physics tick. Density LOD callers should use this O(1)
	# snapshot instead of asking EnemyRegistry to rescan its index per enemy.
	return _enemies.size()

func register_enemy(enemy: Node) -> bool:
	if not _is_eligible(enemy):
		return false
	if not enemy.is_inside_tree() or enemy.is_queued_for_deletion():
		return false
	var base_enemy := enemy as BaseEnemy
	if base_enemy == null:
		return false
	var instance_id := enemy.get_instance_id()
	if _ids.has(instance_id):
		return true
	_ids[instance_id] = true
	_enemy_index_by_id[instance_id] = _enemies.size()
	_enemies.append(base_enemy)
	enemy.set_physics_process(false)
	# Central enemies synchronize position-dependent presentation from the same
	# batched step, so they do not also need one render callback per instance.
	enemy.set_process(false)
	return true

func unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	var instance_id := enemy.get_instance_id()
	if not _ids.erase(instance_id):
		return
	_remove_enemy_at(int(_enemy_index_by_id.get(instance_id, -1)), instance_id)
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		enemy.set_process(true)
	_cursor = mini(_cursor, maxi(_enemies.size() - 1, 0))

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_invalid_prune_remaining -= maxf(delta, 0.0)
	if _invalid_prune_remaining <= 0.0:
		_invalid_prune_remaining = INVALID_PRUNE_INTERVAL_SEC
		_prune_invalid()
	_prune_total_usec += Time.get_ticks_usec() - started
	_processed_last_frame = 0
	if _enemies.is_empty():
		_record_time(started)
		return
	# Every entity keeps cached movement each tick. Expensive AI work remains
	# governed by BaseEnemy.consume_ai_update_delta and its staggered LOD tiers.
	var count := _enemies.size()
	var calls_started := Time.get_ticks_usec()
	for offset in count:
		var index := (_cursor + offset) % count
		if index >= _enemies.size():
			continue
		var enemy := _enemies[index]
		if not _can_simulate(enemy):
			continue
		enemy.simulation_physics_step(delta)
		_processed_last_frame += 1
	_enemy_call_total_usec += Time.get_ticks_usec() - calls_started
	_cursor = (_cursor + 1) % count
	_record_time(started)

func get_metrics_snapshot() -> Dictionary:
	return {
		"registered": _enemies.size(),
		"processed_last_frame": _processed_last_frame,
		"last_step_ms": float(_last_step_usec) / 1000.0,
		"peak_step_ms": float(_peak_step_usec) / 1000.0,
		"total_step_ms": float(_total_step_usec) / 1000.0,
		"physics_tick_count": _physics_tick_count,
		"prune_total_ms": float(_prune_total_usec) / 1000.0,
		"enemy_call_total_ms": float(_enemy_call_total_usec) / 1000.0,
		"movement_separation_ms": float(_movement_separation_usec) / 1000.0,
		"movement_slide_ms": float(_movement_slide_usec) / 1000.0,
		"movement_accept_ms": float(_movement_accept_usec) / 1000.0,
		"movement_sync_ms": float(_movement_sync_usec) / 1000.0,
		"movement_calls": _movement_calls,
		"constraint_total_ms": float(_constraint_total_usec) / 1000.0,
		"constraint_calls": _constraint_calls,
		"constraint_full_refreshes": _constraint_full_refreshes,
	}

func reset_metrics() -> void:
	_last_step_usec = 0
	_peak_step_usec = 0
	_processed_last_frame = 0
	_total_step_usec = 0
	_physics_tick_count = 0
	_prune_total_usec = 0
	_enemy_call_total_usec = 0
	_movement_separation_usec = 0
	_movement_slide_usec = 0
	_movement_accept_usec = 0
	_movement_sync_usec = 0
	_movement_calls = 0
	_constraint_total_usec = 0
	_constraint_calls = 0
	_constraint_full_refreshes = 0

func record_movement_timing(separation_usec: int, slide_usec: int, accept_usec: int, sync_usec: int) -> void:
	_movement_separation_usec += separation_usec
	_movement_slide_usec += slide_usec
	_movement_accept_usec += accept_usec
	_movement_sync_usec += sync_usec
	_movement_calls += 1

func record_constraint_timing(elapsed_usec: int, full_refresh: bool) -> void:
	_constraint_total_usec += maxi(elapsed_usec, 0)
	_constraint_calls += 1
	if full_refresh:
		_constraint_full_refreshes += 1

func _is_eligible(enemy: Node) -> bool:
	if enemy == null or not enemy.has_method("simulation_physics_step"):
		return false
	if not enemy.has_method("_physics_process"):
		return false
	if enemy.has_method("uses_central_simulation") and not bool(enemy.call("uses_central_simulation")):
		return false
	if bool(enemy.get("is_boss")) or enemy.is_in_group(&"boss"):
		return false
	return not enemy.is_in_group(&"central_simulation_exempt")

func _prune_invalid() -> void:
	# Normal lifecycle exits unregister synchronously. This low-frequency pass is
	# only a safety net for externally freed nodes, avoiding an O(N) sweep on
	# every physics tick while still recovering from broken teardown paths.
	for instance_id_value in _enemy_index_by_id.keys():
		var instance_id := int(instance_id_value)
		if not is_instance_id_valid(instance_id):
			_ids.erase(instance_id)
			_remove_enemy_at(int(_enemy_index_by_id.get(instance_id, -1)), instance_id)

func _remove_enemy_at(index: int, instance_id: int) -> void:
	_enemy_index_by_id.erase(instance_id)
	if index < 0 or index >= _enemies.size():
		return
	var last_index := _enemies.size() - 1
	if index != last_index:
		var moved := _enemies[last_index]
		_enemies[index] = moved
		if moved != null and is_instance_valid(moved):
			_enemy_index_by_id[moved.get_instance_id()] = index
	_enemies.pop_back()

func _can_simulate(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy.is_inside_tree() or enemy.is_queued_for_deletion():
		return false
	# Spawn materialization and other lifecycle locks deliberately disable the
	# enemy's process mode. Central scheduling must honor that same contract.
	return enemy.can_process()

func _record_time(started: int) -> void:
	_last_step_usec = Time.get_ticks_usec() - started
	_peak_step_usec = maxi(_peak_step_usec, _last_step_usec)
	_total_step_usec += _last_step_usec
	_physics_tick_count += 1
