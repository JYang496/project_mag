extends Node
class_name CellObjectiveModule

enum ObjectiveType {NONE, KILL_X_IN_CELL, HOLD_OR_PROGRESS}

@export var objective_enabled := false
@export var objective_type: int = ObjectiveType.NONE
@export var required_kill_count: int = 5
@export var required_hold_seconds: float = 8.0
@export var required_progress: int = 50
@export var count_kill_only_when_player_inside := true
@export var task_type_override: int = -1
@export var reward_type_override: int = -1
@export var combat_bonus_speed: float = 20.0
@export var combat_bonus_duration: float = 10.0
@export var economy_bonus_gold: int = 20
@export var reset_on_reward_phase := true
@export var debug_mode := false
@export var debug_print_interval := 0.5

var _cell: Cell
var _hold_time := 0.0
var _kill_count := 0
var _completed := false
var _combat_reward_active := false
var _combat_reward_timer: Timer
var _debug_elapsed := 0.0
var _last_debug_snapshot := ""

func _ready() -> void:
	_cell = get_parent().get_parent() as Cell if get_parent() and get_parent().name == "Modules" else get_parent() as Cell
	if _cell == null:
		push_warning("CellObjectiveModule must be a child of Cell or Cell/Modules.")
		return
	_cell.enemy_killed_in_cell.connect(_on_enemy_killed_in_cell)
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))

func _exit_tree() -> void:
	_clear_combat_reward()
	if PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.disconnect("phase_changed", Callable(self, "_on_phase_changed"))

func _process(delta: float) -> void:
	if not _is_active_phase():
		return
	if debug_mode:
		_debug_elapsed += delta
		if _debug_elapsed >= maxf(debug_print_interval, 0.1):
			_debug_elapsed = 0.0
			_debug_print_progress()
	if not _is_objective_active():
		return
	if _resolve_objective_type() != ObjectiveType.HOLD_OR_PROGRESS:
		return
	if _cell.has_player_inside():
		_hold_time += delta
	if _hold_time >= required_hold_seconds:
		_complete_objective()
		return
	if _cell.progress >= required_progress:
		_complete_objective()

func reset_objective_runtime() -> void:
	_hold_time = 0.0
	_kill_count = 0
	_completed = false
	_clear_combat_reward()
	_last_debug_snapshot = ""
	_debug_elapsed = 0.0

func _on_enemy_killed_in_cell(cell: Cell, _enemy: BaseEnemy) -> void:
	if cell != _cell:
		return
	if not _is_active_phase():
		return
	if not _is_objective_active():
		return
	if _resolve_objective_type() != ObjectiveType.KILL_X_IN_CELL:
		return
	if count_kill_only_when_player_inside and not _cell.has_player_inside():
		return
	_kill_count += 1
	if _kill_count >= required_kill_count:
		_complete_objective()

func _complete_objective() -> void:
	if not _is_active_phase():
		return
	if _completed:
		return
	_completed = true
	_cell.emit_objective_completed()
	if debug_mode:
		print("[CellObjective][DONE] cell=%s state=%s owner=%s objective=%s reward=%s" % [_cell.name, _cell_state_name(_cell.state), _cell_owner_name(_cell.cell_owner), _objective_name(_resolve_objective_type()), _reward_name(_resolve_reward_type())])
	_grant_reward()

func _grant_reward() -> void:
	var reward := _resolve_reward_type()
	if reward == Cell.RewardType.COMBAT:
		if PlayerData.player == null:
			return
		PlayerData.player_bonus_speed += combat_bonus_speed
		_combat_reward_active = true
		if combat_bonus_duration > 0.0:
			if _combat_reward_timer == null:
				_combat_reward_timer = Timer.new()
				_combat_reward_timer.one_shot = true
				add_child(_combat_reward_timer)
				_combat_reward_timer.timeout.connect(_clear_combat_reward)
			_combat_reward_timer.start(combat_bonus_duration)
	elif reward == Cell.RewardType.ECONOMY:
		PlayerData.player_gold += economy_bonus_gold

func _clear_combat_reward() -> void:
	if not _combat_reward_active:
		return
	PlayerData.player_bonus_speed -= combat_bonus_speed
	_combat_reward_active = false

func _resolve_objective_type() -> int:
	if objective_type != ObjectiveType.NONE:
		return objective_type
	var task_type := task_type_override if task_type_override >= 0 else _cell.task_type
	if task_type == Cell.TaskType.OFFENSE:
		return ObjectiveType.KILL_X_IN_CELL
	if task_type == Cell.TaskType.DEFENSE:
		return ObjectiveType.HOLD_OR_PROGRESS
	return ObjectiveType.NONE

func _resolve_reward_type() -> int:
	if reward_type_override >= 0:
		return reward_type_override
	return _cell.reward_type

func _is_objective_active() -> bool:
	return (objective_enabled or _cell.objective_enabled) and not _completed

func _on_phase_changed(new_phase: String) -> void:
	if new_phase != PhaseManager.BATTLE:
		_clear_combat_reward()
	if not reset_on_reward_phase:
		return
	if new_phase == PhaseManager.REWARD:
		reset_objective_runtime()

func _is_active_phase() -> bool:
	return PhaseManager.current_state() == PhaseManager.BATTLE

func _debug_print_progress() -> void:
	if _cell == null:
		return
	if not _cell.has_player_inside():
		return
	var objective_type_now := _resolve_objective_type()
	if objective_type_now == ObjectiveType.NONE:
		return
	var snapshot := ""
	if objective_type_now == ObjectiveType.KILL_X_IN_CELL:
		snapshot = "kills=%d/%d" % [_kill_count, required_kill_count]
	elif objective_type_now == ObjectiveType.HOLD_OR_PROGRESS:
		snapshot = "hold=%.1f/%.1f progress=%d/%d" % [_hold_time, required_hold_seconds, _cell.progress, required_progress]
	if _completed:
		snapshot += " completed=true"
	if snapshot == _last_debug_snapshot:
		return
	_last_debug_snapshot = snapshot
	print("[CellObjective][PROGRESS] cell=%s state=%s owner=%s type=%s %s" % [_cell.name, _cell_state_name(_cell.state), _cell_owner_name(_cell.cell_owner), _objective_name(objective_type_now), snapshot])

func _objective_name(value: int) -> String:
	match value:
		ObjectiveType.KILL_X_IN_CELL:
			return "KILL_X_IN_CELL"
		ObjectiveType.HOLD_OR_PROGRESS:
			return "HOLD_OR_PROGRESS"
		_:
			return "NONE"

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
