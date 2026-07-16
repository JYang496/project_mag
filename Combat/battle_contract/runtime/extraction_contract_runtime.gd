extends RefCounted

signal snapshot_changed(snapshot: Dictionary)
signal completed(snapshot: Dictionary)

const HOLDING := &"holding"
const EXTRACTING := &"extracting"

var port
var phase: StringName = HOLDING
var duration_sec := 32.0
var remaining_sec := 32.0
var escape_duration_sec := 18.0
var escape_remaining_sec := 18.0
var overtime_sec := 0.0
var pursuit_wave_min := 6
var pursuit_wave_max := 10
var player_inside := false
var elapsed_sec := 0.0
var extraction_started_sec := 0.0
var time_to_reach_zone_sec := 0.0
var _completion_guard := false

func start(combat_port, parameters: Dictionary) -> void:
	port = combat_port
	port.request_external_victory_control(true)
	port.request_configure_continuous_spawning(true)
	var level := int(port.get_level_index())
	duration_sec = float(parameters.get("survival_duration_early_sec", 32.0)) if level < 4 else (float(parameters.get("survival_duration_mid_sec", 40.0)) if level < 8 else float(parameters.get("survival_duration_late_sec", 48.0)))
	remaining_sec = duration_sec
	escape_duration_sec = float(parameters.get("escape_duration_early_sec", 18.0)) if level < 4 else (float(parameters.get("escape_duration_mid_sec", 16.0)) if level < 8 else float(parameters.get("escape_duration_late_sec", 14.0)))
	escape_duration_sec = maxf(escape_duration_sec, 1.0)
	escape_remaining_sec = escape_duration_sec
	pursuit_wave_min = maxi(int(parameters.get("pursuit_wave_min", 6)), 0)
	pursuit_wave_max = maxi(int(parameters.get("pursuit_wave_max", 10)), pursuit_wave_min)
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
		time_to_reach_zone_sec = elapsed_sec - extraction_started_sec
		escape_remaining_sec = maxf(escape_remaining_sec - delta, 0.0)
		overtime_sec = maxf(time_to_reach_zone_sec - escape_duration_sec, 0.0)
	_emit_snapshot()

func _open_extraction() -> void:
	phase = EXTRACTING
	extraction_started_sec = elapsed_sec
	port.request_configure_continuous_spawning(false)
	port.request_stop_spawning()
	port.request_configure_threat_multiplier(1.0)
	var points: PackedVector2Array = port.get_battlefield_capabilities().get("extraction_points", PackedVector2Array())
	if points.is_empty():
		push_warning("Extraction contract has no legal extraction point.")
		return
	port.request_spawn_objective(1, points[0])
	port.request_update_beacon(1, 1.0)
	port.request_spawn_pursuit_wave(pursuit_wave_min, pursuit_wave_max)

func _on_presence_changed(snapshot: Dictionary) -> void:
	if phase != EXTRACTING or int(snapshot.get("beacon_id", 0)) != 1:
		return
	player_inside = bool(snapshot.get("player_inside", false))
	if player_inside:
		_complete()

func _complete() -> void:
	if _completion_guard:
		return
	_completion_guard = true
	port.request_stop_spawning()
	port.request_evacuate_enemies({"grant_kill_rewards": false})
	var result := _snapshot()
	var arrival_ratio := clampf(time_to_reach_zone_sec / escape_duration_sec, 0.0, 1.0)
	result["performance_ratio"] = lerpf(1.0, 0.6, arrival_ratio)
	result["reward_type"] = &"gold"
	completed.emit(result)

func _snapshot() -> Dictionary:
	return {
		"contract_id": &"extraction",
		"phase": phase,
		"remaining_sec": remaining_sec,
		"duration_sec": duration_sec,
		"escape_remaining_sec": escape_remaining_sec,
		"escape_duration_sec": escape_duration_sec,
		"overtime_sec": overtime_sec,
		"player_inside": player_inside,
		"elapsed_sec": elapsed_sec,
		"time_to_reach_zone_sec": time_to_reach_zone_sec,
	}

func _emit_snapshot() -> void:
	snapshot_changed.emit(_snapshot())
