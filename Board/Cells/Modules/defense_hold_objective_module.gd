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

func reset_objective_runtime() -> void:
	super.reset_objective_runtime()
	_hold_time = 0.0
	_last_debug_snapshot = ""

func _process_objective(delta: float) -> void:
	if _cell.has_player_inside():
		_hold_time += delta
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
	print("[CellObjective][PROGRESS] cell=%s state=%s owner=%s type=HOLD_OR_PROGRESS %s" % [_cell.name, _cell_state_name(_cell.state), _cell_owner_name(_cell.cell_owner), snapshot])

func _on_debug_completed(reward_type: int) -> void:
	print("[CellObjective][DONE] cell=%s state=%s owner=%s objective=HOLD_OR_PROGRESS reward=%s" % [_cell.name, _cell_state_name(_cell.state), _cell_owner_name(_cell.cell_owner), _reward_name(reward_type)])

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

func _cell_owner_name(value: int) -> String:
	match value:
		Cell.CellOwner.NONE:
			return "NONE"
		Cell.CellOwner.PLAYER:
			return "PLAYER"
		_:
			return "UNKNOWN"
