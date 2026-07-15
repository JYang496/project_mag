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
var budget_exhausted := false
var elapsed_sec := 0.0
var standard_duration_sec := 45.0
var _batch_spawned := 0
var _batch_killed := 0
var _batch_wait_sec := 0.0
var _configured := false

func start(combat_port, _parameters: Dictionary) -> void:
	port = combat_port
	port.request_external_victory_control(true)
	port.request_prefer_elite_final_batch(true)
	total_batches = clampi(3 + port.get_level_index() / 4, 3, 5)
	port.enemy_spawned.connect(_on_enemy_spawned)
	port.enemy_died.connect(_on_enemy_died)
	port.spawn_budget_exhausted.connect(_on_budget_exhausted)
	port.battle_tick.connect(_on_tick)
	_emit_snapshot()

func stop() -> void:
	_disconnect_all()
	if port != null:
		port.request_external_victory_control(false)
		port.request_prefer_elite_final_batch(false)
	port = null

func _on_enemy_spawned(snapshot: Dictionary) -> void:
	spawned_count += 1
	alive_count += 1
	_batch_spawned += 1
	planned_hp = maxi(planned_hp, int(port.get_spawn_budget_snapshot().get("planned_total_hp", 0)))
	_emit_snapshot()

func _on_enemy_died(snapshot: Dictionary) -> void:
	alive_count = maxi(alive_count - 1, 0)
	if bool(snapshot.get("was_killed", false)):
		killed_count += 1
		_batch_killed += 1
		killed_hp += int(snapshot.get("scaled_hp", 0))
	_try_advance_batch()
	_try_complete()

func _on_budget_exhausted(_snapshot: Dictionary) -> void:
	budget_exhausted = true
	current_batch = total_batches
	_try_complete()

func _on_tick(snapshot: Dictionary) -> void:
	var delta := float(snapshot.get("delta_sec", 0.0))
	if not _configured:
		var budget: Dictionary = port.get_spawn_budget_snapshot()
		planned_hp = int(budget.get("planned_total_hp", 0))
		if planned_hp > 0:
			port.request_configure_finite_budget(planned_hp, total_batches)
			_configured = true
	elapsed_sec += delta
	_batch_wait_sec += delta
	for enemy_state in snapshot.get("enemy_states", []):
		if float(enemy_state.get("stalled_sec", 0.0)) >= 8.0:
			port.request_relocate_enemies({"enemy_id": int(enemy_state.get("enemy_id", 0))})
	_try_advance_batch()
	_emit_snapshot()

func _try_advance_batch() -> void:
	if current_batch >= total_batches or _batch_spawned <= 0:
		return
	if float(_batch_killed) / float(_batch_spawned) >= 0.8 or _batch_wait_sec >= 12.0:
		current_batch += 1
		_batch_spawned = 0
		_batch_killed = 0
		_batch_wait_sec = 0.0
		port.request_release_next_batch()

func _try_complete() -> void:
	if budget_exhausted and alive_count <= 0:
		var result := _snapshot()
		result["actual_completion_sec"] = elapsed_sec
		result["standard_duration_sec"] = standard_duration_sec
		completed.emit(result)

func _snapshot() -> Dictionary:
	return {"contract_id": &"elimination", "remaining_enemies": alive_count, "current_batch": current_batch, "total_batches": total_batches, "planned_hp": planned_hp, "spawned": spawned_count, "kills": killed_count, "killed_hp": killed_hp, "budget_exhausted": budget_exhausted}

func _emit_snapshot() -> void:
	snapshot_changed.emit(_snapshot())

func _disconnect_all() -> void:
	if port == null:
		return
	for pair in [[port.enemy_spawned, _on_enemy_spawned], [port.enemy_died, _on_enemy_died], [port.spawn_budget_exhausted, _on_budget_exhausted], [port.battle_tick, _on_tick]]:
		if pair[0].is_connected(pair[1]): pair[0].disconnect(pair[1])
