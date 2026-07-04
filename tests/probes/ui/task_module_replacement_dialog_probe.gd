extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")

var _selected_index := -1

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	CellTaskModuleRuntime.reset_runtime_state()
	CellTaskModuleRuntime.load_definitions()
	PhaseManager.reset_runtime_state()

	var player := PLAYER_SCENE.instantiate() as Player
	get_tree().root.add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	var ui := UI_SCENE.instantiate() as UI
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	var first_grant := CellTaskModuleRuntime.grant_module("task_kill_common")
	if not bool(first_grant.get("ok", false)):
		_fail("failed to grant first task module: %s" % str(first_grant))
		return
	var second_grant := CellTaskModuleRuntime.grant_module("task_hold_common")
	if not bool(second_grant.get("ok", false)):
		_fail("failed to grant second task module: %s" % str(second_grant))
		return

	if not ui.request_task_module_replacement("task_clear_rare", Callable(self, "_on_replace")):
		_fail("task module replacement dialog did not open")
		return
	if not ui.is_dialog_visible():
		_fail("shared replacement dialog not visible")
		return
	if ui.modal_dialog_controller.custom_action_buttons.size() != 1:
		_fail("replacement dialog did not use shared custom action buttons")
		return

	ui.modal_dialog_controller.dialog.emit_signal("custom_action", &"discard_slot_1")
	await get_tree().process_frame
	await get_tree().process_frame

	if _selected_index != 1:
		_fail("custom action selected index %d instead of 1" % _selected_index)
		return
	if ui.is_dialog_visible():
		_fail("shared replacement dialog stayed visible after custom action")
		return
	if not ui.modal_dialog_controller.custom_action_buttons.is_empty():
		_fail("shared custom action buttons were not cleared")
		return

	CellTaskModuleRuntime.reset_runtime_state()
	print("PASS task_module_replacement_dialog_probe")
	printerr("PASS task_module_replacement_dialog_probe")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)

func _on_replace(index: int) -> void:
	_selected_index = index

func _fail(message: String) -> void:
	CellTaskModuleRuntime.reset_runtime_state()
	push_error(message)
	print("FAIL: ", message)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1)
