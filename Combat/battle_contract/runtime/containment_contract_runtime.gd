extends RefCounted

signal snapshot_changed(snapshot: Dictionary)
signal completed(snapshot: Dictionary)

var port
var rift_count := 3
var seal_duration_sec := 8.0
var reinforcement_interval_sec := 9.0
var progress_by_id: Dictionary = {}
var presence_by_id: Dictionary = {}
var sealed_by_id: Dictionary = {}
var reinforcement_elapsed_by_id: Dictionary = {}
var sealed_count := 0
var active_rift_id := 0
var elapsed_sec := 0.0
var reinforcement_waves := 0
var _surge_remaining_sec := 0.0
var _completion_guard := false
var _objectives_spawned := false

func start(combat_port, parameters: Dictionary) -> void:
	port = combat_port
	port.request_external_victory_control(true)
	port.request_configure_continuous_spawning(true)
	var available_points: PackedVector2Array = port.get_battlefield_capabilities().get("containment_points", PackedVector2Array())
	rift_count = mini(clampi(int(parameters.get("rift_count", 3)), 1, 3), available_points.size())
	seal_duration_sec = maxf(float(parameters.get("seal_duration_sec", 8.0)), 1.0)
	reinforcement_interval_sec = maxf(float(parameters.get("reinforcement_interval_sec", 9.0)), 3.0)
	port.request_configure_duration(float(rift_count) * seal_duration_sec + 12.0)
	port.beacon_presence_changed.connect(_on_presence_changed)
	port.battle_tick.connect(_on_tick)
	_apply_threat()
	_emit_snapshot()

func stop() -> void:
	if port != null:
		if port.beacon_presence_changed.is_connected(_on_presence_changed): port.beacon_presence_changed.disconnect(_on_presence_changed)
		if port.battle_tick.is_connected(_on_tick): port.battle_tick.disconnect(_on_tick)
		port.request_remove_beacons()
		port.request_configure_continuous_spawning(false)
		port.request_configure_threat_multiplier(1.0)
		port.request_external_victory_control(false)
	port = null

func _on_tick(snapshot: Dictionary) -> void:
	if _completion_guard:
		return
	if not _objectives_spawned:
		_try_spawn_objectives()
	if not _objectives_spawned:
		return
	var delta := float(snapshot.get("delta_sec", 0.0))
	if delta <= 0.0:
		return
	elapsed_sec += delta
	_surge_remaining_sec = maxf(_surge_remaining_sec - delta, 0.0)
	active_rift_id = 0
	for rift_id in progress_by_id:
		if bool(sealed_by_id.get(rift_id, false)):
			continue
		var presence: Dictionary = presence_by_id.get(rift_id, {})
		if bool(presence.get("player_inside", false)):
			active_rift_id = int(rift_id)
			var enemy_count := int(presence.get("enemy_count", 0))
			var speed := maxf(1.0 / (1.0 + 0.18 * float(enemy_count)), 0.35)
			progress_by_id[rift_id] = minf(float(progress_by_id[rift_id]) + delta * speed / seal_duration_sec, 1.0)
			port.request_update_beacon(int(rift_id), float(progress_by_id[rift_id]))
		if float(progress_by_id[rift_id]) >= 1.0:
			_seal_rift(int(rift_id))
			if _completion_guard:
				return
			continue
		reinforcement_elapsed_by_id[rift_id] = float(reinforcement_elapsed_by_id[rift_id]) + delta
		if float(reinforcement_elapsed_by_id[rift_id]) >= reinforcement_interval_sec:
			reinforcement_elapsed_by_id[rift_id] = 0.0
			reinforcement_waves += 1
			_surge_remaining_sec = 2.0
			port.request_release_reinforcement_budget(2.0)
	_apply_threat()
	_emit_snapshot()

func _try_spawn_objectives() -> void:
	var current_points: PackedVector2Array = port.get_battlefield_capabilities().get("containment_points", PackedVector2Array())
	if rift_count <= 0 or current_points.size() < rift_count:
		return
	for index in rift_count:
		var rift_id := index + 1
		progress_by_id[rift_id] = 0.0
		presence_by_id[rift_id] = {"player_inside": false, "enemy_count": 0}
		sealed_by_id[rift_id] = false
		reinforcement_elapsed_by_id[rift_id] = 0.0
		port.request_spawn_objective(rift_id, current_points[index])
	_objectives_spawned = true

func _on_presence_changed(snapshot: Dictionary) -> void:
	var rift_id := int(snapshot.get("beacon_id", 0))
	if not presence_by_id.has(rift_id) or bool(sealed_by_id.get(rift_id, false)):
		return
	presence_by_id[rift_id] = {
		"player_inside": bool(snapshot.get("player_inside", false)),
		"enemy_count": int(snapshot.get("enemy_count", 0)),
	}

func _seal_rift(rift_id: int) -> void:
	if bool(sealed_by_id.get(rift_id, false)):
		return
	sealed_by_id[rift_id] = true
	sealed_count += 1
	port.request_update_beacon(rift_id, 1.0)
	if sealed_count >= rift_count:
		_completion_guard = true
		port.request_stop_spawning()
		port.request_evacuate_enemies({"grant_kill_rewards": false})
		var result := _snapshot()
		result["performance_ratio"] = clampf(1.0 - float(reinforcement_waves) / float(maxi(rift_count * 4, 1)), 0.0, 1.0)
		result["reward_type"] = &"gold"
		completed.emit(result)

func _apply_threat() -> void:
	if port == null:
		return
	var remaining := maxi(rift_count - sealed_count, 0)
	var multiplier := 1.0 + 0.12 * float(maxi(remaining - 1, 0))
	if _surge_remaining_sec > 0.0:
		multiplier += 0.25
	port.request_configure_threat_multiplier(multiplier)

func _snapshot() -> Dictionary:
	var progress := float(progress_by_id.get(active_rift_id, 0.0)) if active_rift_id > 0 else 0.0
	var presence: Dictionary = presence_by_id.get(active_rift_id, {})
	return {
		"contract_id": &"containment",
		"sealed_count": sealed_count,
		"total_rifts": rift_count,
		"active_rift": active_rift_id,
		"progress": progress,
		"player_inside": bool(presence.get("player_inside", false)),
		"enemy_count": int(presence.get("enemy_count", 0)),
		"reinforcement_waves": reinforcement_waves,
		"surge_active": _surge_remaining_sec > 0.0,
		"elapsed_sec": elapsed_sec,
	}

func _emit_snapshot() -> void:
	snapshot_changed.emit(_snapshot())
