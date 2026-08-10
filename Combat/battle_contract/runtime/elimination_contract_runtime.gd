extends RefCounted

signal snapshot_changed(snapshot: Dictionary)
signal completed(snapshot: Dictionary)

var port
var total_batches := 3
var current_batch := 1
var planned_hp := 0
var spawned_count := 0
var alive_count := 0
var killed_count := 0
var killed_hp := 0
var planned_enemy_count := 0
var budget_exhausted := false
var elapsed_sec := 0.0
var standard_duration_sec := 45.0
var early_release_ratio := 0.8
var batch_wait_timeout_sec := 12.0
var _batch_spawned := 0
var _batch_killed := 0
var _batch_wait_sec := 0.0
var _configured := false
var _completion_guard := false
var _guidance_enabled := false

func start(combat_port, parameters: Dictionary) -> void:
	port = combat_port
	port.request_configure_spawn_policy(
		&"finite",
		float(parameters.get("spawn_soft_cap_multiplier", 1.0)),
		float(parameters.get("spawn_hard_cap_multiplier", 1.10))
	)
	port.request_monitor_enemy_stalls(true)
	port.request_external_victory_control(true)
	port.request_prefer_elite_final_batch(true)
	var minimum_batches := maxi(int(parameters.get("batch_count_min", 3)), 1)
	var maximum_batches := maxi(int(parameters.get("batch_count_max", 5)), minimum_batches)
	var levels_per_batch_step := maxi(int(parameters.get("levels_per_batch_step", 4)), 1)
	total_batches = mini(minimum_batches + port.get_level_index() / levels_per_batch_step, maximum_batches)
	standard_duration_sec = maxf(float(parameters.get("standard_duration_sec", 45.0)), 1.0)
	early_release_ratio = clampf(float(parameters.get("early_release_ratio", 0.8)), 0.0, 1.0)
	batch_wait_timeout_sec = maxf(float(parameters.get("batch_wait_timeout_sec", 12.0)), 0.1)
	port.enemy_spawned.connect(_on_enemy_spawned)
	port.enemy_died.connect(_on_enemy_died)
	port.spawn_budget_exhausted.connect(_on_budget_exhausted)
	port.battle_tick.connect(_on_tick)
	_emit_snapshot()

func stop() -> void:
	_disconnect_all()
	if port != null:
		port.request_set_elimination_guidance(false)
		port.request_monitor_enemy_stalls(false)
		port.request_external_victory_control(false)
		port.request_prefer_elite_final_batch(false)
	_guidance_enabled = false
	port = null

func _on_enemy_spawned(snapshot: Dictionary) -> void:
	spawned_count += 1
	alive_count += 1
	_batch_spawned += 1
	planned_hp = maxi(planned_hp, int(port.get_spawn_budget_snapshot().get("planned_total_hp", 0)))
	_emit_snapshot()
	_refresh_enemy_guidance()

func _on_enemy_died(snapshot: Dictionary) -> void:
	alive_count = maxi(alive_count - 1, 0)
	if bool(snapshot.get("was_killed", false)):
		killed_count += 1
		_batch_killed += 1
		killed_hp += int(snapshot.get("scaled_hp", 0))
	_try_merge_serial_tail()
	_try_advance_batch()
	_try_complete()
	_refresh_enemy_guidance()

func _on_budget_exhausted(_snapshot: Dictionary) -> void:
	budget_exhausted = true
	current_batch = total_batches
	_try_complete()
	_refresh_enemy_guidance()

func _on_tick(snapshot: Dictionary) -> void:
	var delta := float(snapshot.get("delta_sec", 0.0))
	if not _configured:
		var budget: Dictionary = port.get_spawn_budget_snapshot()
		planned_hp = int(budget.get("planned_total_hp", 0))
		if planned_hp > 0:
			port.request_configure_finite_budget(planned_hp, total_batches)
			planned_enemy_count = int(port.get_spawn_budget_snapshot().get("planned_enemy_count", 0))
			_configured = true
			_try_merge_serial_tail()
	elapsed_sec += delta
	_batch_wait_sec += delta
	_reconcile_alive_count_after_budget_exhaustion()
	_try_advance_batch()
	_try_complete()
	_emit_snapshot()
	_refresh_enemy_guidance()

func _reconcile_alive_count_after_budget_exhaustion() -> void:
	if not budget_exhausted or port == null:
		return
	var actual_alive := maxi(int(port.get_active_enemy_count()), 0)
	if actual_alive == alive_count:
		return
	push_warning(
		"Elimination enemy count recovered from lifecycle drift: protocol=%d actual=%d"
		% [alive_count, actual_alive]
	)
	alive_count = actual_alive

func _try_advance_batch() -> void:
	if current_batch >= total_batches or _batch_spawned <= 0:
		return
	if float(_batch_killed) / float(_batch_spawned) >= early_release_ratio or _batch_wait_sec >= batch_wait_timeout_sec:
		current_batch += 1
		_batch_spawned = 0
		_batch_killed = 0
		_batch_wait_sec = 0.0
		port.request_release_next_batch()
		_refresh_enemy_guidance()

func _try_merge_serial_tail() -> void:
	if port == null or current_batch >= total_batches:
		return
	var remaining_planned := maxi(planned_enemy_count - killed_count, 0)
	var remaining_batches := total_batches - current_batch + 1
	# Merge only when the rest of the contract has degraded to at most one
	# target per batch. Larger, meaningful formations retain normal pacing.
	if remaining_planned <= 1 or remaining_planned > remaining_batches:
		return
	while current_batch < total_batches:
		current_batch += 1
		port.request_release_next_batch()
	_batch_spawned = 0
	_batch_killed = 0
	_batch_wait_sec = 0.0
	_refresh_enemy_guidance()

func _refresh_enemy_guidance() -> void:
	if port == null:
		return
	var remaining := int(_snapshot().get("remaining_enemies", 0)) if _configured else 0
	var desired := remaining > 0 and remaining < 5
	if desired == _guidance_enabled:
		return
	_guidance_enabled = desired
	port.request_set_elimination_guidance(desired)

func _try_complete() -> void:
	if _completion_guard or not _configured or port == null:
		return
	var queued_enemies := 0 if budget_exhausted else maxi(planned_enemy_count - spawned_count, 0)
	var actual_alive := maxi(int(port.get_active_enemy_count()), 0)
	if queued_enemies > 0 or actual_alive > 0:
		return
	alive_count = actual_alive
	_completion_guard = true
	var result := _snapshot()
	result["remaining_enemies"] = 0
	result["actual_completion_sec"] = elapsed_sec
	result["standard_duration_sec"] = standard_duration_sec
	completed.emit(result)

func _snapshot() -> Dictionary:
	var remaining_enemies := alive_count if budget_exhausted else (maxi(planned_enemy_count - killed_count, 0) if planned_enemy_count > 0 else alive_count)
	var queued_enemies := 0 if budget_exhausted else maxi(planned_enemy_count - spawned_count, 0)
	return {"contract_id": &"elimination", "remaining_enemies": remaining_enemies, "active_enemies": alive_count, "queued_enemies": queued_enemies, "planned_enemies": planned_enemy_count, "current_batch": current_batch, "total_batches": total_batches, "planned_hp": planned_hp, "spawned": spawned_count, "kills": killed_count, "killed_hp": killed_hp, "budget_exhausted": budget_exhausted}

func _emit_snapshot() -> void:
	snapshot_changed.emit(_snapshot())

func _disconnect_all() -> void:
	if port == null:
		return
	for pair in [[port.enemy_spawned, _on_enemy_spawned], [port.enemy_died, _on_enemy_died], [port.spawn_budget_exhausted, _on_budget_exhausted], [port.battle_tick, _on_tick]]:
		if pair[0].is_connected(pair[1]): pair[0].disconnect(pair[1])
