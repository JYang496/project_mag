extends RefCounted

signal snapshot_changed(snapshot: Dictionary)
signal completed(snapshot: Dictionary)

var port
var duration_sec := 45.0
var remaining_sec := 45.0
var threat_level := 1
var effective_kills := 0
var killed_hp := 0
var resolve := 0
var resolve_triggers := 0
const RESOLVE_THRESHOLD := 250
const RESOLVE_TRIGGER_CAP := 3

func start(combat_port, _parameters: Dictionary) -> void:
	port = combat_port
	port.request_external_victory_control(true)
	var level: int = int(port.get_level_index())
	duration_sec = 45.0 if level < 4 else (55.0 if level < 8 else 65.0)
	remaining_sec = duration_sec
	port.request_configure_duration(duration_sec)
	port.request_configure_continuous_spawning(true)
	port.battle_tick.connect(_on_tick)
	port.enemy_died.connect(_on_enemy_died)
	_emit_snapshot()

func stop() -> void:
	if port != null:
		if port.battle_tick.is_connected(_on_tick): port.battle_tick.disconnect(_on_tick)
		if port.enemy_died.is_connected(_on_enemy_died): port.enemy_died.disconnect(_on_enemy_died)
		port.request_configure_continuous_spawning(false)
		port.request_external_victory_control(false)
		port.request_configure_threat_multiplier(1.0)
	port = null

func _on_tick(snapshot: Dictionary) -> void:
	remaining_sec = maxf(remaining_sec - float(snapshot.get("delta_sec", 0.0)), 0.0)
	var next_threat := mini(int(floor((duration_sec - remaining_sec) / 15.0)) + 1, 5)
	if next_threat != threat_level:
		threat_level = next_threat
		port.request_configure_threat_multiplier(1.0 + 0.15 * float(threat_level - 1))
	_emit_snapshot()
	if remaining_sec <= 0.0:
		port.request_stop_spawning()
		port.request_evacuate_enemies({"grant_kill_rewards": false})
		completed.emit(_snapshot())

func _on_enemy_died(snapshot: Dictionary) -> void:
	if not bool(snapshot.get("was_killed", false)):
		return
	effective_kills += 1
	killed_hp += int(snapshot.get("scaled_hp", 0))
	resolve += maxi(int(snapshot.get("scaled_hp", 0)), 1)
	if resolve >= RESOLVE_THRESHOLD and resolve_triggers < RESOLVE_TRIGGER_CAP:
		resolve -= RESOLVE_THRESHOLD
		resolve_triggers += 1
		port.request_player_heal(5)

func _snapshot() -> Dictionary:
	return {"contract_id": &"survival", "remaining_sec": remaining_sec, "duration_sec": duration_sec, "threat_level": threat_level, "effective_kills": effective_kills, "killed_hp": killed_hp, "resolve_triggers": resolve_triggers}

func _emit_snapshot() -> void:
	snapshot_changed.emit(_snapshot())
