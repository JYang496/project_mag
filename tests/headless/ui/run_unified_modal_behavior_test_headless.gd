extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const CELL_SCENE := preload("res://Board/Cells/cell.tscn")
const TEST_MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")

var _failures: PackedStringArray = PackedStringArray()
var _ui: UI
var _board: BoardCellGenerator
var _task_replacement_index := -1
var _unassigned_confirmed := false
var _unassigned_cancelled := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	get_tree().current_scene = self
	_reset_global_state()
	if not InputMap.has_action("CANCEL"):
		_record("CANCEL input action is missing.")
		_finish()
		return
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_record("failed to instantiate player")
		_finish()
		return
	get_tree().root.add_child(player)
	_ui = UI_SCENE.instantiate() as UI
	if _ui == null:
		_record("failed to instantiate UI")
		_finish()
		return
	get_tree().root.add_child(_ui)
	_board = _make_board()
	add_child(_board)
	await get_tree().process_frame
	await get_tree().process_frame

	await _test_inventory_replacement_dialog()
	await _test_cell_overwrite_dialog_paths()
	await _test_unassigned_start_battle_confirmation()
	await _test_temporary_module_sell_semantic_action()
	await _test_single_blocking_modal_and_semantic_destructive_actions()
	_finish()

func _test_inventory_replacement_dialog() -> void:
	CellTaskModuleRuntime.reset_runtime_state()
	CellTaskModuleRuntime.grant_module("task_kill_common")
	CellTaskModuleRuntime.grant_module("task_hold_common")
	_task_replacement_index = -1
	if not _ui.request_task_module_replacement("task_clear_rare", Callable(self, "_on_task_replacement_selected")):
		_record("task inventory replacement dialog did not open")
		return
	await get_tree().process_frame
	var dialog := _get_dialog()
	if dialog == null or not dialog.visible:
		_record("task inventory replacement dialog is not visible")
		return
	if not _is_semantic_destructive_action(dialog.get_ok_button().text):
		_record("task inventory replacement action uses non-semantic text '%s'" % dialog.get_ok_button().text)
	if _task_replacement_index != -1:
		_record("task inventory replacement callback fired before confirmation")
	dialog.emit_signal("confirmed")
	await get_tree().process_frame
	await get_tree().process_frame
	if _task_replacement_index != 0:
		_record("task inventory replacement confirm did not select slot 0")

	for cancel_mode in ["cancel", "right_click", "esc"]:
		CellTaskModuleRuntime.reset_runtime_state()
		CellTaskModuleRuntime.grant_module("task_kill_common")
		_task_replacement_index = -1
		if not _ui.request_task_module_replacement("task_hold_common", Callable(self, "_on_task_replacement_selected")):
			_record("task inventory replacement dialog did not reopen for %s" % cancel_mode)
			continue
		await get_tree().process_frame
		await _cancel_dialog(cancel_mode)
		await get_tree().process_frame
		await get_tree().process_frame
		if _task_replacement_index != -1:
			_record("task inventory replacement %s path still replaced slot %d" % [cancel_mode, _task_replacement_index])

func _test_cell_overwrite_dialog_paths() -> void:
	for mode in ["confirm", "cancel", "right_click", "window_right_click", "esc"]:
		CellTaskModuleRuntime.reset_runtime_state()
		PhaseManager.phase = PhaseManager.PREPARE
		CellTaskModuleRuntime.grant_module("task_kill_common")
		CellTaskModuleRuntime.grant_module("task_hold_common")
		var result := CellTaskModuleRuntime.deploy_inventory_module(0, 5, _board)
		if not bool(result.get("ok", false)):
			_record("failed to seed deployed task for %s overwrite path: %s" % [mode, str(result)])
			continue
		if not _ui.open_cell_management_panel(&"task"):
			_record("failed to open task management panel for %s overwrite path" % mode)
			continue
		await get_tree().process_frame
		var panel := _ui.cell_management_panel
		var drag_data: Dictionary = panel.call("build_drag_data", {"kind": "task_inventory_module", "inventory_index": 0, "module_id": "task_hold_common"}, null)
		if not bool(panel.call("drop_payload", {"kind": "task_cell", "cell_id": 5}, drag_data)):
			_record("dropping replacement task module did not open overwrite path for %s" % mode)
			continue
		await get_tree().process_frame
		var dialog := _get_dialog()
		if dialog == null or not dialog.visible:
			_record("cell overwrite confirmation is not visible for %s" % mode)
			continue
		if not _is_semantic_destructive_action(dialog.get_ok_button().text):
			_record("cell overwrite action uses non-semantic text '%s'" % dialog.get_ok_button().text)
		var before := CellTaskModuleRuntime.get_deployment_snapshot()
		if str(before.get("5", "")) != "task_kill_common":
			_record("cell overwrite replaced before confirmation on %s path" % mode)
		if mode == "confirm":
			dialog.emit_signal("confirmed")
		else:
			await _cancel_dialog(mode)
		await get_tree().process_frame
		await get_tree().process_frame
		var after := CellTaskModuleRuntime.get_deployment_snapshot()
		if mode == "confirm":
			if str(after.get("5", "")) != "task_hold_common":
				_record("cell overwrite confirm did not replace deployment")
		elif str(after.get("5", "")) != "task_kill_common":
			_record("cell overwrite %s path replaced deployment" % mode)
		_ui.request_close_cell_management_panel()
		await get_tree().process_frame

func _test_unassigned_start_battle_confirmation() -> void:
	for mode in ["cancel", "confirm"]:
		CellTaskModuleRuntime.reset_runtime_state()
		CellTaskModuleRuntime.grant_module("task_kill_common")
		_unassigned_confirmed = false
		_unassigned_cancelled = false
		if not _ui.request_task_module_unassigned_confirmation(
			CellTaskModuleRuntime.get_inventory_size(),
			Callable(self, "_on_unassigned_confirmed"),
			Callable(self, "_on_unassigned_cancelled")
		):
			_record("unassigned task module start-battle confirmation did not open")
			continue
		await get_tree().process_frame
		var dialog := _get_dialog()
		if dialog == null or not dialog.visible:
			_record("unassigned task module start-battle confirmation is not visible")
			continue
		if not _is_semantic_destructive_action(dialog.get_ok_button().text):
			_record("unassigned start-battle action uses non-semantic text '%s'" % dialog.get_ok_button().text)
		if mode == "confirm":
			dialog.emit_signal("confirmed")
		else:
			dialog.emit_signal("canceled")
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		if mode == "cancel":
			if _unassigned_confirmed:
				_record("unassigned start-battle cancel continued original callback")
		elif not _unassigned_confirmed or _unassigned_cancelled:
			_record("unassigned start-battle confirm did not continue original callback")

func _test_temporary_module_sell_semantic_action() -> void:
	InventoryData.reset_runtime_state()
	var module_instance := TEST_MODULE_SCENE.instantiate() as Module
	if module_instance == null:
		_record("failed to instantiate temporary module for sell confirmation")
		return
	InventoryData.obtain_module(module_instance)
	if not _ui.request_temporary_module_sell_confirmation(module_instance):
		_record("temporary module sell confirmation did not open")
		return
	await get_tree().process_frame
	var dialog := _get_dialog()
	if dialog == null or not dialog.visible:
		_record("temporary module sell confirmation is not visible")
		return
	if not _is_semantic_destructive_action(dialog.get_ok_button().text):
		_record("temporary module sell action uses non-semantic text '%s'" % dialog.get_ok_button().text)
	await _cancel_dialog("cancel")
	await get_tree().process_frame

func _test_single_blocking_modal_and_semantic_destructive_actions() -> void:
	CellTaskModuleRuntime.reset_runtime_state()
	CellTaskModuleRuntime.grant_module("task_kill_common")
	_unassigned_confirmed = false
	_unassigned_cancelled = false
	_ui.request_task_module_unassigned_confirmation(
		CellTaskModuleRuntime.get_inventory_size(),
		Callable(self, "_on_unassigned_confirmed"),
		Callable(self, "_on_unassigned_cancelled")
	)
	await get_tree().process_frame
	_ui.request_confirmation(
		&"second_blocking_modal",
		"Second Modal",
		"Only one blocking modal should exist.",
		"Continue",
		"Cancel",
		Callable(),
		Callable(),
		true,
		Vector2i(420, 180)
	)
	await get_tree().process_frame
	var visible_dialog_count := _count_visible_confirmation_dialogs()
	if visible_dialog_count != 1:
		_record("expected exactly one visible blocking modal, got %d" % visible_dialog_count)
	var dialog := _get_dialog()
	if dialog != null and not _is_semantic_destructive_action(dialog.get_ok_button().text):
		_record("second destructive action uses non-semantic text '%s'" % dialog.get_ok_button().text)
	if dialog != null:
		dialog.hide()

func _make_board() -> BoardCellGenerator:
	var board := BoardCellGenerator.new()
	board.name = "Board"
	board.cell_scene = CELL_SCENE
	board.auto_assign_enemy_on_battle = false
	for _index in range(9):
		board.initial_cell_profiles.append(CellProfile.new())
	return board

func _reset_global_state() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	CellTaskModuleRuntime.load_definitions()
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 0

func _get_dialog() -> ConfirmationDialog:
	if _ui == null or _ui.modal_dialog_controller == null:
		return null
	return _ui.modal_dialog_controller.dialog as ConfirmationDialog

func _count_visible_confirmation_dialogs() -> int:
	var count := 0
	for node in get_tree().root.find_children("*", "ConfirmationDialog", true, false):
		var dialog := node as ConfirmationDialog
		if dialog != null and dialog.visible:
			count += 1
	return count

func _cancel_dialog(mode: String) -> void:
	var dialog := _get_dialog()
	if dialog == null:
		return
	match mode:
		"cancel":
			if _ui != null:
				_ui.cancel_visible_dialog()
			else:
				dialog.emit_signal("canceled")
		"right_click":
			var right_click := InputEventMouseButton.new()
			right_click.button_index = MOUSE_BUTTON_RIGHT
			right_click.pressed = true
			Input.parse_input_event(right_click)
		"window_right_click":
			var window_right_click := InputEventMouseButton.new()
			window_right_click.button_index = MOUSE_BUTTON_RIGHT
			window_right_click.pressed = true
			if dialog.has_signal("window_input"):
				dialog.emit_signal("window_input", window_right_click)
		"esc":
			var escape := InputEventAction.new()
			escape.action = "CANCEL"
			escape.pressed = true
			Input.parse_input_event(escape)

func _on_task_replacement_selected(index: int) -> void:
	_task_replacement_index = index

func _on_unassigned_confirmed() -> void:
	_unassigned_confirmed = true

func _on_unassigned_cancelled() -> void:
	_unassigned_cancelled = true

func _is_semantic_destructive_action(text: String) -> bool:
	var stripped := text.strip_edges()
	return stripped == "Sell" \
		or stripped == "Replace" \
		or stripped == "Continue" \
		or stripped == "Discard" \
		or stripped.begins_with("Discard ") \
		or stripped == "出售" \
		or stripped == "替换" \
		or stripped == "继续" \
		or stripped == "丢弃" \
		or stripped.begins_with("丢弃槽位")

func _record(message: String) -> void:
	_failures.append(message)
	push_error("UnifiedModalBehaviorTest: " + message)

func _finish() -> void:
	CellTaskModuleRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	InventoryData.reset_runtime_state()
	if _failures.is_empty():
		print("UnifiedModalBehaviorTest: PASS")
		get_tree().quit(0)
		return
	print("UnifiedModalBehaviorTest: FAIL (%d)" % _failures.size())
	for failure in _failures:
		print(" - " + failure)
	get_tree().quit(1)
