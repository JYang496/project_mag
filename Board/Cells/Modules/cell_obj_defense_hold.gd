extends CellObjectiveModule
class_name DefenseHoldObjectiveModule

@export var required_hold_seconds: float = 8.0
@export var required_progress: int = 50

var _hold_time := 0.0
var _last_debug_snapshot := ""

func set_task_parameters(params: Dictionary) -> void:
	if params.has("required_hold_seconds"):
		required_hold_seconds = params["required_hold_seconds"]
	if params.has("required_progress"):
		required_progress = params["required_progress"]
	_emit_task_status_changed()

func reset_objective_runtime() -> void:
	super.reset_objective_runtime()
	_hold_time = 0.0
	_last_debug_snapshot = ""
	_emit_task_status_changed()

func get_combat_task_status() -> Dictionary:
	var hold_total := maxf(required_hold_seconds, 0.1)
	var hold_progress := clampf(_hold_time / hold_total, 0.0, 1.0)
	var capture_total := maxi(required_progress, 1)
	var capture_progress := 0.0
	if _cell != null:
		capture_progress = clampf(float(_cell.progress) / float(capture_total), 0.0, 1.0)
	if capture_progress > hold_progress:
		var captured := 0
		if _cell != null:
			captured = mini(int(_cell.progress), capture_total)
		return _build_combat_task_status("hold", "hold", "占领", capture_progress, "%d/%d%%" % [captured, capture_total], capture_progress > 0.0)
	var elapsed := clampf(_hold_time, 0.0, hold_total)
	return _build_combat_task_status("hold", "hold", "守点", hold_progress, "%.0f/%.0f秒" % [floor(elapsed), ceil(hold_total)], _cell != null and _cell.has_player_inside())

func _process_objective(delta: float) -> void:
	if _cell.has_player_inside():
		_hold_time += delta
	_emit_task_status_changed()
	if _hold_time >= required_hold_seconds:
		_complete_objective()
		return
	if _cell.progress >= required_progress:
		_complete_objective()

func _on_debug_tick() -> void:
	if _cell == null:
		return
	if not _cell.has_player_inside():
		return
	var snapshot := "hold=%.1f/%.1f progress=%d/%d" % [_hold_time, required_hold_seconds, _cell.progress, required_progress]
	if _completed:
		snapshot += " completed=true"
	if snapshot == _last_debug_snapshot:
		return
	_last_debug_snapshot = snapshot
	print("[CellObjective][PROGRESS] cell=%s state=%s type=HOLD_OR_PROGRESS %s" % [_cell.name, _cell_state_name(_cell.state), snapshot])

func _on_debug_completed(reward_type: int) -> void:
	print("[CellObjective][DONE] cell=%s state=%s objective=HOLD_OR_PROGRESS reward=%s" % [_cell.name, _cell_state_name(_cell.state), _reward_name(reward_type)])

func _reward_name(value: int) -> String:
	match value:
		Cell.RewardType.COMBAT:
			return "COMBAT"
		Cell.RewardType.ECONOMY:
			return "ECONOMY"
		_:
			return "NONE"

func _cell_state_name(value: int) -> String:
	match value:
		Cell.CellState.IDLE:
			return "IDLE"
		Cell.CellState.PLAYER:
			return "PLAYER"
		Cell.CellState.CONTESTED:
			return "CONTESTED"
		Cell.CellState.LOCKED:
			return "LOCKED"
		_:
			return "UNKNOWN"
