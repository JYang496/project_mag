extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()

	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	var ui := UI_SCENE.instantiate() as UI
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	ui.ensure_warehouse_management()
	await get_tree().process_frame

	var module_instance := MODULE_SCENE.instantiate() as Module
	var obtain_result := InventoryData.obtain_module(module_instance)
	if not bool(obtain_result.get("ok", false)):
		_fail("obtain_module failed: %s" % str(obtain_result))
		return

	ui.module_warehouse_controller.open_tab(&"module")
	var view: ModuleManagementView = ui.module_warehouse_controller.module_management_view
	if view == null:
		_fail("module management view missing")
		return
	var module_button := _find_temporary_module_button(view, module_instance)
	if module_button == null:
		_fail("right-side temporary module button missing")
		return
	module_button.pressed.emit()
	await get_tree().process_frame
	if view.module_sell_button == null:
		_fail("module sell button missing")
		return
	if view.module_sell_button.disabled:
		_fail("right-side temporary module sell button disabled")
		return
	view.module_sell_button.pressed.emit()
	await get_tree().process_frame
	if ui.module_action_dialog == null or not ui.module_action_dialog.visible:
		_fail("right-side temporary module sell confirmation not visible")
		return

	var gold_before := PlayerData.player_gold
	var ok_button := ui.module_action_dialog.get_ok_button()
	if ok_button == null:
		_fail("sell confirmation ok button missing")
		return
	ok_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	if is_instance_valid(module_instance):
		if not InventoryData.temporary_modules.has(module_instance):
			_fail("right-side temporary module instance stayed valid after sale")
			return
		var controller = ui.module_transaction_dialog_controller
		_fail("right-side temporary module remained after ok button; active=%s pending=%s visible=%s count=%d" % [
			str(controller.active_dialog_id),
			str(controller.pending_module_action.is_valid()),
			str(ui.module_action_dialog.visible),
			InventoryData.temporary_modules.size(),
		])
		return
	if PlayerData.player_gold <= gold_before:
		_fail("right-side temporary module sale did not add gold")
		return

	InventoryData.reset_runtime_state()
	print("PASS temporary module sell")
	await TEST_TEARDOWN.finish(self, 0, _reset_runtime_state)

func _fail(message: String) -> void:
	push_error(message)
	print("FAIL: ", message)
	await TEST_TEARDOWN.finish(self, 1, _reset_runtime_state)

func _reset_runtime_state() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()

func _find_temporary_module_button(view: ModuleManagementView, module_instance: Module) -> Button:
	if view == null or module_instance == null:
		return null
	var right_list := view.get("_right_list") as VBoxContainer
	if right_list == null:
		return null
	for child in right_list.get_children():
		var button := child as Button
		if button == null:
			continue
		var payload = button.get("drag_payload")
		if payload is Dictionary and payload.get("module", null) == module_instance:
			return button
	return null
