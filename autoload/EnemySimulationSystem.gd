extends Node

var _enemies: Array[Node] = []
var _ids: Dictionary = {}
var _cursor := 0
var _last_step_usec := 0
var _peak_step_usec := 0
var _processed_last_frame := 0

func register_enemy(enemy: Node) -> bool:
	if not _is_eligible(enemy):
		return false
	if not enemy.is_inside_tree() or enemy.is_queued_for_deletion():
		return false
	var instance_id := enemy.get_instance_id()
	if _ids.has(instance_id):
		return true
	_ids[instance_id] = true
	_enemies.append(enemy)
	enemy.set_physics_process(false)
	return true

func unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	var instance_id := enemy.get_instance_id()
	if not _ids.erase(instance_id):
		return
	_enemies.erase(enemy)
	_cursor = mini(_cursor, maxi(_enemies.size() - 1, 0))

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_prune_invalid()
	_processed_last_frame = 0
	if _enemies.is_empty():
		_record_time(started)
		return
	# Every entity keeps cached movement each tick. Expensive AI work remains
	# governed by BaseEnemy.consume_ai_update_delta and its staggered LOD tiers.
	var count := _enemies.size()
	for offset in count:
		var index := (_cursor + offset) % count
		var enemy := _enemies[index]
		if not _can_simulate(enemy):
			continue
		if enemy.has_method("simulation_physics_step"):
			enemy.call("simulation_physics_step", delta)
		_processed_last_frame += 1
	_cursor = (_cursor + 1) % count
	_record_time(started)

func get_metrics_snapshot() -> Dictionary:
	return {
		"registered": _enemies.size(),
		"processed_last_frame": _processed_last_frame,
		"last_step_ms": float(_last_step_usec) / 1000.0,
		"peak_step_ms": float(_peak_step_usec) / 1000.0,
	}

func reset_metrics() -> void:
	_last_step_usec = 0
	_peak_step_usec = 0
	_processed_last_frame = 0

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
	for index in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[index]
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion():
			_enemies.remove_at(index)
	_ids.clear()
	for enemy in _enemies:
		_ids[enemy.get_instance_id()] = true

func _can_simulate(enemy: Node) -> bool:
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
