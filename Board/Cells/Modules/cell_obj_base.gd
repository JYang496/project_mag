extends Node
class_name CellObjectiveModule

signal task_status_changed(cell_id: int)

@export var objective_enabled := false
@export var reward_type_override: int = -1
@export var bonus_scene: PackedScene = preload("res://Board/Cells/Bonus/objective_reward_bonus.tscn")
@export var reset_on_prepare_phase := true
@export var debug_mode := false
@export var debug_print_interval := 0.5

var _cell: Cell
var _completed := false
var _bonus_module: CellBonusModule
var _debug_elapsed := 0.0
var _last_status_signature := ""

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
	_emit_task_status_changed()

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
	TaskRewardManager.notify_objective_completed(_cell.name)
	_emit_task_status_changed()

func _grant_reward() -> void:
	# Legacy immediate reward hook retained for future reward modes.
	if _bonus_module == null:
		return
	var reward_type := _resolve_reward_type()
	_bonus_module.grant_reward(reward_type)
	_show_reward_message(reward_type)

func _show_reward_message(reward_type: int) -> void:
	if GlobalVariables.ui == null:
		return
	if not GlobalVariables.ui.has_method("show_item_message"):
		return
	var reward_summary := _bonus_module.get_reward_summary(reward_type)
	var message := "Objective Complete"
	if reward_summary.strip_edges() != "":
		message += "  " + reward_summary
	GlobalVariables.ui.show_item_message(message, 2.6)

func _resolve_reward_type() -> int:
	if reward_type_override >= 0:
		return reward_type_override
	return _cell.reward_type

func _is_objective_active() -> bool:
	if _cell == null:
		return false
	return (objective_enabled or _cell.objective_enabled) and not _completed

func get_combat_task_status() -> Dictionary:
	return _build_combat_task_status("fallback", "fallback", "", 0.0, "", false)

func _build_combat_task_status(task_type: String, icon_key: String, label: String, progress: float, value_text: String, active: bool = false, instruction_key: String = "") -> Dictionary:
	var resolved_instruction_key := instruction_key.strip_edges()
	if resolved_instruction_key == "":
		resolved_instruction_key = _instruction_key_for_status_type(task_type)
	return {
		"cell_id": _safe_cell_id(),
		"module_id": _safe_module_id(),
		"type": task_type,
		"icon_key": icon_key,
		"label": label,
		"instruction_key": resolved_instruction_key,
		"instruction": _localized_instruction_for_status_type(task_type, resolved_instruction_key),
		"progress": _clamped_progress(progress),
		"value_text": value_text,
		"state": _resolve_task_status_state(active)
	}

func _instruction_key_for_status_type(status_type: String) -> String:
	match status_type:
		"kill":
			return "ui.task_objective.instruction.kill"
		"hold":
			return "ui.task_objective.instruction.hold"
		"clear":
			return "ui.task_objective.instruction.clear"
		"hunt":
			return "ui.task_objective.instruction.hunt"
		"dodge":
			return "ui.task_objective.instruction.dodge"
		_:
			return ""

func _localized_instruction_for_status_type(status_type: String, instruction_key: String) -> String:
	var fallback := _instruction_fallback_for_status_type(status_type)
	if instruction_key.strip_edges() == "":
		return fallback
	return LocalizationManager.tr_key(instruction_key, fallback)

func _instruction_fallback_for_status_type(status_type: String) -> String:
	match status_type:
		"kill":
			return "Kill enemies"
		"hold":
			return "Stay inside the marked cell"
		"clear":
			return "Clear enemies near this cell"
		"hunt":
			return "Defeat the marked elite"
		"dodge":
			return "Avoid damage until timer ends"
		_:
			return ""

func _safe_cell_id() -> int:
	if _cell == null:
		return 0
	return int(_cell.logical_id)

func _safe_module_id() -> String:
	var cell_id := _safe_cell_id()
	if cell_id > 0 and CellTaskModuleRuntime != null:
		return CellTaskModuleRuntime.get_active_task_module_id(cell_id)
	return ""

func _clamped_progress(value: float) -> float:
	return clampf(value, 0.0, 1.0)

func _resolve_task_status_state(active: bool = false) -> String:
	if _completed:
		return "complete"
	if _cell == null:
		return "blocked"
	if not _is_active_phase():
		return "waiting"
	if _cell.state == Cell.CellState.LOCKED or not _cell.board_enabled:
		return "blocked"
	if active and _is_objective_active():
		return "active"
	return "waiting"

func _emit_task_status_changed() -> void:
	var status := get_combat_task_status()
	var signature := JSON.stringify(status)
	if signature == _last_status_signature:
		return
	_last_status_signature = signature
	task_status_changed.emit(_safe_cell_id())

func _on_phase_changed(new_phase: String) -> void:
	if _bonus_module:
		_bonus_module.on_phase_changed(new_phase)
	if not reset_on_prepare_phase:
		return
	if new_phase == PhaseManager.PREPARE:
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
