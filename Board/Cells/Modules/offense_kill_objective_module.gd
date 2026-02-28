extends CellObjectiveModule
class_name OffenseKillObjectiveModule

@export var required_kill_count: int = 10
@export var count_kill_only_when_player_inside := true

var _kill_count := 0
var _last_debug_snapshot := ""

func set_task_parameters(params: Dictionary) -> void:
	if params.has("required_kill_count"):
		required_kill_count = params["required_kill_count"]
	if params.has("count_kill_only_when_player_inside"):
		count_kill_only_when_player_inside = params["count_kill_only_when_player_inside"]

func reset_objective_runtime() -> void:
	super.reset_objective_runtime()
	_kill_count = 0
	_last_debug_snapshot = ""

func _on_objective_enemy_killed(_enemy: BaseEnemy) -> void:
	if count_kill_only_when_player_inside and not _cell.has_player_inside():
		return
	_kill_count += 1
	if _kill_count >= required_kill_count:
		_complete_objective()

func _on_debug_tick() -> void:
	if _cell == null:
		return
	if not _cell.has_player_inside():
		return
	var snapshot := "kills=%d/%d" % [_kill_count, required_kill_count]
	if _completed:
		snapshot += " completed=true"
	if snapshot == _last_debug_snapshot:
		return
	_last_debug_snapshot = snapshot
	print("[CellObjective][PROGRESS] cell=%s state=%s owner=%s type=KILL_X_IN_CELL %s" % [_cell.name, _cell_state_name(_cell.state), _cell_owner_name(_cell.cell_owner), snapshot])

func _on_debug_completed(reward_type: int) -> void:
	print("[CellObjective][DONE] cell=%s state=%s owner=%s objective=KILL_X_IN_CELL reward=%s" % [_cell.name, _cell_state_name(_cell.state), _cell_owner_name(_cell.cell_owner), _reward_name(reward_type)])

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
