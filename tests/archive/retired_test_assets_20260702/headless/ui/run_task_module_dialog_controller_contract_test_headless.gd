extends Node

const MODAL_DIALOG_CONTROLLER_SCRIPT := preload("res://UI/scripts/components/modal_dialog_controller.gd")
const TASK_MODULE_DIALOG_CONTROLLER_SCRIPT := preload("res://UI/scripts/components/task_module_dialog_controller.gd")

var _failures := PackedStringArray()
var _gui_root: Control
var _modal_dialog_controller
var _controller
var _first_confirm_count := 0
var _second_confirm_count := 0
var _cancel_count := 0
var _replacement_indices := PackedInt32Array()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	CellTaskModuleRuntime.load_definitions()
	CellTaskModuleRuntime.reset_runtime_state()
	_gui_root = Control.new()
	_gui_root.name = "TaskModuleDialogContractRoot"
	add_child(_gui_root)
	_modal_dialog_controller = MODAL_DIALOG_CONTROLLER_SCRIPT.new()
	_modal_dialog_controller.bind(self, _gui_root)
	_controller = TASK_MODULE_DIALOG_CONTROLLER_SCRIPT.new()
	_controller.bind(_modal_dialog_controller)

	_assert_injection_contract()
	await _test_repeated_open_and_callback_once()
	await _test_cancel_paths()
	await _test_replacement_buttons_and_selection()
	_finish()

func _assert_injection_contract() -> void:
	if _controller.modal_dialog_controller != _modal_dialog_controller:
		_record("controller did not retain the injected ModalDialogController")
	for property in _controller.get_property_list():
		if str(property.get("name", "")) == "owner_ui":
			_record("controller exposes a forbidden owner_ui dependency")

func _test_repeated_open_and_callback_once() -> void:
	_first_confirm_count = 0
	_second_confirm_count = 0
	if not _controller.request_unassigned_confirmation(
		1,
		Callable(self, "_on_first_confirmed"),
		Callable(self, "_on_cancelled")
	):
		_record("first unassigned confirmation did not open")
		return
	if not _controller.request_unassigned_confirmation(
		2,
		Callable(self, "_on_second_confirmed"),
		Callable(self, "_on_cancelled")
	):
		_record("repeated unassigned confirmation did not open")
		return
	await get_tree().process_frame
	var dialog := _modal_dialog_controller.dialog as ConfirmationDialog
	if dialog == null or not dialog.visible:
		_record("repeated unassigned confirmation is not visible")
		return
	dialog.emit_signal("confirmed")
	await _settle_deferred_callbacks()
	if _first_confirm_count != 0:
		_record("repeated open retained the superseded confirm callback")
	if _second_confirm_count != 1:
		_record("latest confirm callback ran %d times instead of once" % _second_confirm_count)
	dialog.emit_signal("confirmed")
	await _settle_deferred_callbacks()
	if _second_confirm_count != 1:
		_record("confirm callback ran more than once")

func _test_cancel_paths() -> void:
	for mode in ["cancel", "right_click", "esc"]:
		_first_confirm_count = 0
		_cancel_count = 0
		if not _controller.request_unassigned_confirmation(
			1,
			Callable(self, "_on_first_confirmed"),
			Callable(self, "_on_cancelled")
		):
			_record("unassigned confirmation did not open for %s" % mode)
			continue
		await get_tree().process_frame
		var dialog := _modal_dialog_controller.dialog as ConfirmationDialog
		match mode:
			"cancel":
				_modal_dialog_controller.cancel_visible_dialog()
			"right_click":
				var right_click := InputEventMouseButton.new()
				right_click.button_index = MOUSE_BUTTON_RIGHT
				right_click.pressed = true
				dialog.emit_signal("window_input", right_click)
			"esc":
				var escape := InputEventAction.new()
				escape.action = "CANCEL"
				escape.pressed = true
				dialog.emit_signal("window_input", escape)
		await _settle_deferred_callbacks()
		if _first_confirm_count != 0:
			_record("%s cancel path ran the confirm callback" % mode)
		if _cancel_count != 1:
			_record("%s cancel callback ran %d times instead of once" % [mode, _cancel_count])
		dialog.emit_signal("canceled")
		await _settle_deferred_callbacks()
		if _cancel_count != 1:
			_record("%s cancel callback ran more than once" % mode)

func _test_replacement_buttons_and_selection() -> void:
	CellTaskModuleRuntime.reset_runtime_state()
	CellTaskModuleRuntime.grant_module("task_kill_common")
	CellTaskModuleRuntime.grant_module("task_hold_common")
	CellTaskModuleRuntime.grant_module("task_clear_rare")
	_replacement_indices.clear()
	if not _controller.request_replacement(
		"task_kill_common",
		Callable(self, "_on_replacement_selected")
	):
		_record("replacement dialog did not open")
		return
	await get_tree().process_frame
	if _controller.replacement_custom_buttons.size() != 2:
		_record(
			"expected 2 dynamic replacement buttons, got %d"
			% _controller.replacement_custom_buttons.size()
		)
	var dialog := _modal_dialog_controller.dialog as ConfirmationDialog
	dialog.emit_signal("custom_action", &"discard_slot_1")
	await _settle_deferred_callbacks()
	if _replacement_indices != PackedInt32Array([1]):
		_record("custom replacement action did not select slot 1 exactly once")
	if not _controller.replacement_custom_buttons.is_empty():
		_record("dynamic replacement buttons were not cleared after selection")
	dialog.emit_signal("custom_action", &"discard_slot_2")
	await _settle_deferred_callbacks()
	if _replacement_indices != PackedInt32Array([1]):
		_record("replacement callback ran again after state was cleared")

	if not _controller.request_replacement(
		"task_hold_common",
		Callable(self, "_on_replacement_selected")
	):
		_record("replacement dialog did not reopen for primary action")
		return
	await get_tree().process_frame
	dialog.emit_signal("confirmed")
	await _settle_deferred_callbacks()
	if _replacement_indices != PackedInt32Array([1, 0]):
		_record("primary replacement action did not select slot 0")
	if not _controller.replacement_custom_buttons.is_empty():
		_record("dynamic replacement buttons were not cleared after primary confirmation")

	if not _controller.request_replacement(
		"task_clear_rare",
		Callable(self, "_on_replacement_selected")
	):
		_record("replacement dialog did not reopen for cancellation")
		return
	await get_tree().process_frame
	_modal_dialog_controller.cancel_visible_dialog()
	await _settle_deferred_callbacks()
	if _replacement_indices != PackedInt32Array([1, 0]):
		_record("replacement cancellation invoked the replacement callback")
	if not _controller.replacement_custom_buttons.is_empty():
		_record("dynamic replacement buttons were not cleared after cancellation")

func _settle_deferred_callbacks() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _on_first_confirmed() -> void:
	_first_confirm_count += 1

func _on_second_confirmed() -> void:
	_second_confirm_count += 1

func _on_cancelled() -> void:
	_cancel_count += 1

func _on_replacement_selected(index: int) -> void:
	_replacement_indices.append(index)

func _record(message: String) -> void:
	_failures.append(message)
	push_error("TaskModuleDialogControllerContractTest: " + message)

func _finish() -> void:
	if _controller != null:
		_controller.dispose()
	CellTaskModuleRuntime.reset_runtime_state()
	if _failures.is_empty():
		print("TaskModuleDialogControllerContractTest: PASS")
		get_tree().quit(0)
		return
	print("TaskModuleDialogControllerContractTest: FAIL (%d)" % _failures.size())
	for failure in _failures:
		print(" - " + failure)
	get_tree().quit(1)
