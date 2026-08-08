extends Node

signal pacing_event_recorded(event: Dictionary)

const MAX_EVENTS := 256
var _events: Array[Dictionary] = []
var _run_started_msec := 0

func _ready() -> void:
	reset_runtime_state()
	if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.connect(_on_phase_changed)

func record_event(event_name: StringName, payload: Dictionary = {}) -> void:
	if _run_started_msec <= 0:
		_run_started_msec = Time.get_ticks_msec()
	var event := {
		"name": event_name,
		"elapsed_msec": Time.get_ticks_msec() - _run_started_msec,
		"level_index": int(PhaseManager.current_level),
		"phase": PhaseManager.current_state(),
		"payload": payload.duplicate(true),
	}
	_events.append(event)
	if _events.size() > MAX_EVENTS:
		_events.pop_front()
	pacing_event_recorded.emit(event.duplicate(true))

func get_events() -> Array[Dictionary]:
	return _events.duplicate(true)

func reset_runtime_state() -> void:
	_events.clear()
	_run_started_msec = Time.get_ticks_msec()

func _on_phase_changed(new_phase: String) -> void:
	match new_phase:
		PhaseManager.BATTLE_STARTING:
			record_event(&"battle_deployment_started")
		PhaseManager.BATTLE:
			record_event(&"battle_started")
		PhaseManager.SETTLEMENT:
			record_event(&"battle_completed", {"settlement_type": PhaseManager.get_settlement_type()})
		PhaseManager.REST:
			record_event(&"chapter_rest_entered", {"settlement_type": PhaseManager.get_settlement_type()})
		PhaseManager.RUN_COMPLETE:
			record_event(&"run_completed")
		PhaseManager.GAMEOVER:
			record_event(&"run_failed")

