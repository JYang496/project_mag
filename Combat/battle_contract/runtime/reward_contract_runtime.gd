extends RefCounted

signal snapshot_changed(snapshot: Dictionary)
signal completed(snapshot: Dictionary)

var port
var duration_sec := 45.0
var remaining_sec := 45.0
var spawned_count := 0
var killed_count := 0
var alive_count := 0
var budget_exhausted := false
var _completion_guard := false

func start(combat_port, parameters: Dictionary) -> void:
	port = combat_port
	duration_sec = maxf(float(parameters.get("duration_sec", 45.0)), 1.0)
	remaining_sec = duration_sec
	port.request_external_victory_control(true)
	port.request_configure_duration(duration_sec)
	port.request_configure_reward_stage(
		true,
		float(parameters.get("hp_budget_multiplier", 2.0)),
		float(parameters.get("reward_multiplier", 2.0))
	)
	port.battle_tick.connect(_on_tick)
	port.enemy_spawned.connect(_on_enemy_spawned)
	port.enemy_died.connect(_on_enemy_died)
	port.spawn_budget_exhausted.connect(_on_budget_exhausted)
	_emit_snapshot()

func stop() -> void:
	if port == null:
		return
	for pair in [[port.battle_tick, _on_tick], [port.enemy_spawned, _on_enemy_spawned], [port.enemy_died, _on_enemy_died], [port.spawn_budget_exhausted, _on_budget_exhausted]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	port.request_configure_reward_stage(false)
	port.request_external_victory_control(false)
	port = null

func _on_tick(snapshot: Dictionary) -> void:
	if _completion_guard:
		return
	remaining_sec = maxf(remaining_sec - float(snapshot.get("delta_sec", 0.0)), 0.0)
	_emit_snapshot()
	if remaining_sec <= 0.0:
		_finish(&"timeout")

func _on_enemy_spawned(_snapshot: Dictionary) -> void:
	spawned_count += 1
	alive_count += 1
	_emit_snapshot()

func _on_enemy_died(snapshot: Dictionary) -> void:
	alive_count = maxi(alive_count - 1, 0)
	if bool(snapshot.get("was_killed", false)):
		killed_count += 1
	_emit_snapshot()
	if budget_exhausted and alive_count <= 0:
		_finish(&"all_enemies_defeated")

func _on_budget_exhausted(_snapshot: Dictionary) -> void:
	budget_exhausted = true
	if alive_count <= 0:
		_finish(&"all_enemies_defeated")

func _finish(reason: StringName) -> void:
	if _completion_guard:
		return
	_completion_guard = true
	port.request_stop_spawning()
	if reason == &"timeout":
		port.request_evacuate_enemies({"grant_kill_rewards": false})
	var result := _snapshot()
	result["completion_reason"] = reason
	completed.emit(result)

func _snapshot() -> Dictionary:
	return {
		"contract_id": &"reward",
		"remaining_sec": remaining_sec,
		"duration_sec": duration_sec,
		"spawned": spawned_count,
		"kills": killed_count,
		"remaining_enemies": alive_count,
		"budget_exhausted": budget_exhausted,
	}

func _emit_snapshot() -> void:
	snapshot_changed.emit(_snapshot())
