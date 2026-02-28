extends Node
class_name CellObjectiveModule

@export var objective_enabled := false
@export var reward_type_override: int = -1
@export var bonus_scene: PackedScene = preload("res://Board/Cells/Bonus/objective_reward_bonus.tscn")
@export var reset_on_reward_phase := true
@export var debug_mode := false
@export var debug_print_interval := 0.5

var _cell: Cell
var _completed := false
var _bonus_module: CellBonusModule
var _debug_elapsed := 0.0

func _ready() -> void:
	_cell = get_parent().get_parent() as Cell if get_parent() and get_parent().name == "Modules" else get_parent() as Cell
	if _cell == null:
		push_warning("CellObjectiveModule must be a child of Cell or Cell/Modules.")
		return
	_bonus_module = _resolve_bonus_module()
	if _bonus_module:
		_bonus_module.setup(_cell)
	_cell.enemy_killed_in_cell.connect(_on_enemy_killed_in_cell)
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))

func _exit_tree() -> void:
	if _bonus_module:
		_bonus_module.reset_runtime()
	if PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.disconnect("phase_changed", Callable(self, "_on_phase_changed"))

func _process(delta: float) -> void:
	if not _is_active_phase():
		return
	if debug_mode:
		_debug_elapsed += delta
		if _debug_elapsed >= maxf(debug_print_interval, 0.1):
			_debug_elapsed = 0.0
			_on_debug_tick()
	if not _is_objective_active():
		return
	_process_objective(delta)

func reset_objective_runtime() -> void:
	_completed = false
	if _bonus_module:
		_bonus_module.reset_runtime()
	_debug_elapsed = 0.0

func _on_enemy_killed_in_cell(cell: Cell, _enemy: BaseEnemy) -> void:
	if cell != _cell:
		return
	if not _is_active_phase():
		return
	if not _is_objective_active():
		return
	_on_objective_enemy_killed(_enemy)

func _complete_objective() -> void:
	if not _is_active_phase():
		return
	if _completed:
		return
	_completed = true
	_cell.emit_objective_completed()
	if debug_mode:
		_on_debug_completed(_resolve_reward_type())
	_grant_reward()

func _grant_reward() -> void:
	if _bonus_module == null:
		return
	_bonus_module.grant_reward(_resolve_reward_type())

func _resolve_reward_type() -> int:
	if reward_type_override >= 0:
		return reward_type_override
	return _cell.reward_type

func _is_objective_active() -> bool:
	return (objective_enabled or _cell.objective_enabled) and not _completed

func _on_phase_changed(new_phase: String) -> void:
	if _bonus_module:
		_bonus_module.on_phase_changed(new_phase)
	if not reset_on_reward_phase:
		return
	if new_phase == PhaseManager.REWARD:
		reset_objective_runtime()

func _is_active_phase() -> bool:
	return PhaseManager.current_state() == PhaseManager.BATTLE

func _process_objective(_delta: float) -> void:
	pass

func _on_objective_enemy_killed(_enemy: BaseEnemy) -> void:
	pass

func _on_debug_tick() -> void:
	pass

func _on_debug_completed(_reward_type: int) -> void:
	pass

func _resolve_bonus_module() -> CellBonusModule:
	for child in get_children():
		if child is CellBonusModule:
			return child as CellBonusModule
	if bonus_scene == null:
		return null
	var bonus_instance = bonus_scene.instantiate()
	if bonus_instance is CellBonusModule:
		add_child(bonus_instance)
		return bonus_instance as CellBonusModule
	if bonus_instance:
		bonus_instance.queue_free()
	push_warning("bonus_scene must instantiate CellBonusModule.")
	return null

func set_task_parameters(params: Dictionary) -> void:
	# Override in subclasses
	pass

func set_bonus_parameters(params: Dictionary) -> void:
	if _bonus_module and _bonus_module.has_method("apply_parameters"):
		_bonus_module.apply_parameters(params)
