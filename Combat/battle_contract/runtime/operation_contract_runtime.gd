extends RefCounted

signal snapshot_changed(snapshot: Dictionary)
signal completed(snapshot: Dictionary)

var port
var points := PackedVector2Array()
var beacon_index := 0
var progress := 0.0
var charge_duration_sec := 12.0
var player_inside := false
var enemy_count := 0
var available_progress_sec := 0.0
var actual_progress_sec := 0.0
var stalled_sec := 0.0
var _started := false

func start(combat_port, parameters: Dictionary) -> void:
	port = combat_port
	port.request_external_victory_control(true)
	points = port.get_battlefield_capabilities().get("operation_beacon_points", PackedVector2Array())
	charge_duration_sec = clampf(float(parameters.get("charge_time_sec", 12.0)), 10.0, 14.0)
	port.battle_tick.connect(_on_tick)
	port.beacon_presence_changed.connect(_on_presence_changed)
	_emit_snapshot()

func stop() -> void:
	if port != null:
		if port.battle_tick.is_connected(_on_tick): port.battle_tick.disconnect(_on_tick)
		if port.beacon_presence_changed.is_connected(_on_presence_changed): port.beacon_presence_changed.disconnect(_on_presence_changed)
		port.request_remove_beacons()
		port.request_external_victory_control(false)
	port = null

func _on_tick(snapshot: Dictionary) -> void:
	var delta := float(snapshot.get("delta_sec", 0.0))
	if not _started and points.size() >= 2:
		_started = true
		port.request_spawn_beacon(1, points[0])
	if not _started:
		return
	available_progress_sec += delta
	if player_inside:
		var speed := maxf(1.0 - 0.2 * float(enemy_count), 0.35)
		var gained := delta * speed
		actual_progress_sec += gained
		progress = minf(progress + gained / charge_duration_sec, 1.0)
		port.request_update_beacon(beacon_index + 1, progress)
	elif available_progress_sec - actual_progress_sec > 3.0:
		stalled_sec += delta
	_emit_snapshot()
	if progress >= 1.0:
		_advance_beacon()

func _on_presence_changed(snapshot: Dictionary) -> void:
	if int(snapshot.get("beacon_id", 0)) != beacon_index + 1:
		return
	player_inside = bool(snapshot.get("player_inside", false))
	enemy_count = int(snapshot.get("enemy_count", 0))

func _advance_beacon() -> void:
	beacon_index += 1
	progress = 0.0
	player_inside = false
	enemy_count = 0
	if beacon_index >= 2:
		port.request_stop_spawning()
		port.request_evacuate_enemies({"grant_kill_rewards": false})
		completed.emit(_snapshot())
		return
	port.request_spawn_beacon(2, points[1])

func _snapshot() -> Dictionary:
	return {"contract_id": &"operation", "current_beacon": mini(beacon_index + 1, 2), "total_beacons": 2, "progress": progress, "available_progress_sec": available_progress_sec, "actual_progress_sec": actual_progress_sec, "stalled_sec": stalled_sec}

func _emit_snapshot() -> void:
	snapshot_changed.emit(_snapshot())
