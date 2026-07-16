extends RefCounted

signal snapshot_changed(snapshot: Dictionary)
signal completed(snapshot: Dictionary)

const HOLDING := &"holding"
const EXTRACTING := &"extracting"

var port
var phase: StringName = HOLDING
var duration_sec := 32.0
var remaining_sec := 32.0
var charge_duration_sec := 6.0
var progress := 0.0
var player_inside := false
var enemy_count := 0
var elapsed_sec := 0.0
var extraction_started_sec := 0.0
var time_to_reach_zone_sec := 0.0
var _reached_zone := false
var _completion_guard := false

func start(combat_port, parameters: Dictionary) -> void:
	port = combat_port
	port.request_external_victory_control(true)
	port.request_configure_continuous_spawning(true)
	var level := int(port.get_level_index())
	duration_sec = float(parameters.get("survival_duration_early_sec", 32.0)) if level < 4 else (float(parameters.get("survival_duration_mid_sec", 40.0)) if level < 8 else float(parameters.get("survival_duration_late_sec", 48.0)))
	remaining_sec = duration_sec
	charge_duration_sec = maxf(float(parameters.get("extraction_charge_sec", 6.0)), 1.0)
	# Spawn pressure must be released across the holding phase. External victory
	# control already allows the extraction phase to continue past this timer.
	port.request_configure_duration(duration_sec)
	port.battle_tick.connect(_on_tick)
	port.beacon_presence_changed.connect(_on_presence_changed)
	_emit_snapshot()

func stop() -> void:
	if port != null:
		if port.battle_tick.is_connected(_on_tick): port.battle_tick.disconnect(_on_tick)
		if port.beacon_presence_changed.is_connected(_on_presence_changed): port.beacon_presence_changed.disconnect(_on_presence_changed)
		port.request_remove_beacons()
		port.request_configure_continuous_spawning(false)
		port.request_configure_threat_multiplier(1.0)
		port.request_external_victory_control(false)
	port = null

func _on_tick(snapshot: Dictionary) -> void:
	if _completion_guard:
		return
	var delta := float(snapshot.get("delta_sec", 0.0))
	if delta <= 0.0:
		return
	elapsed_sec += delta
	if phase == HOLDING:
		remaining_sec = maxf(remaining_sec - delta, 0.0)
		var ratio := 1.0 - remaining_sec / maxf(duration_sec, 1.0)
		port.request_configure_threat_multiplier(1.0 + ratio * 0.25)
		if remaining_sec <= 0.0:
			_open_extraction()
	else:
		if not _reached_zone:
			time_to_reach_zone_sec = elapsed_sec - extraction_started_sec
		if player_inside:
			_reached_zone = true
			var speed := maxf(1.0 - 0.15 * float(enemy_count), 0.35)
			progress = minf(progress + delta * speed / charge_duration_sec, 1.0)
			port.request_update_beacon(1, progress)
		if progress >= 1.0:
			_complete()
	_emit_snapshot()

func _open_extraction() -> void:
	phase = EXTRACTING
	extraction_started_sec = elapsed_sec
	port.request_configure_threat_multiplier(1.45)
	var points: PackedVector2Array = port.get_battlefield_capabilities().get("extraction_points", PackedVector2Array())
	if points.is_empty():
		push_warning("Extraction contract has no legal extraction point.")
		return
	port.request_spawn_objective(1, points[0])

func _on_presence_changed(snapshot: Dictionary) -> void:
	if phase != EXTRACTING or int(snapshot.get("beacon_id", 0)) != 1:
		return
	player_inside = bool(snapshot.get("player_inside", false))
	enemy_count = int(snapshot.get("enemy_count", 0))

func _complete() -> void:
	if _completion_guard:
		return
	_completion_guard = true
	port.request_stop_spawning()
	port.request_evacuate_enemies({"grant_kill_rewards": false})
	var result := _snapshot()
	result["performance_ratio"] = clampf(1.0 - time_to_reach_zone_sec / 20.0, 0.0, 1.0)
	result["reward_type"] = &"gold"
	completed.emit(result)

func _snapshot() -> Dictionary:
	return {
		"contract_id": &"extraction",
		"phase": phase,
		"remaining_sec": remaining_sec,
		"duration_sec": duration_sec,
		"progress": progress,
		"player_inside": player_inside,
		"enemy_count": enemy_count,
		"elapsed_sec": elapsed_sec,
		"time_to_reach_zone_sec": time_to_reach_zone_sec,
	}

func _emit_snapshot() -> void:
	snapshot_changed.emit(_snapshot())
