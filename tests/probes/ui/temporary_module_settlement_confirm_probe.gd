extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")

var _completed := 0
var _previous_confirmation_enabled := true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()

	var player := PLAYER_SCENE.instantiate() as Player
	get_tree().root.add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	var ui := UI_SCENE.instantiate() as UI
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	_previous_confirmation_enabled = ui.module_transaction_dialog_controller.is_temporary_module_confirmation_enabled()
	ui.module_transaction_dialog_controller.set_temporary_module_confirmation_enabled(true)

	var module_instance := MODULE_SCENE.instantiate() as Module
	var obtain_result := InventoryData.obtain_module(module_instance)
	if not bool(obtain_result.get("ok", false)):
		_fail("failed to add temporary module")
		return

	var opened := ui.request_temporary_module_settlement(Callable(self, "_on_complete"))
	if not opened:
		_fail("settlement dialog did not open")
		return
	if not ui.is_world_interaction_blocked():
		_fail("settlement dialog did not block world interaction before confirm")
		return

	ui.temporary_module_settlement_checkbox.button_pressed = true
	ui.temporary_module_settlement_dialog.emit_signal("confirmed")
	await get_tree().process_frame
	await get_tree().process_frame

	if _completed != 1:
		_fail("battle-start callback was not called after confirmation")
		return
	if not InventoryData.temporary_modules.is_empty():
		_fail("temporary modules were not sold on confirmation")
		return
	if ui.module_transaction_dialog_controller.pending_battle_start.is_valid() \
			or ui.module_transaction_dialog_controller.pending_battle_start_cancel.is_valid():
		_fail("controller kept pending battle callbacks after confirmation")
		return
	if ui.get("_pending_battle_start").is_valid() or ui.get("_pending_battle_start_cancel").is_valid():
		_fail("UI compatibility pending callbacks stayed stale after confirmation")
		return
	if ui.module_transaction_dialog_controller.is_temporary_module_confirmation_enabled():
		_fail("do-not-show checkbox did not persist after settlement confirmation")
		return
	if ui.is_world_interaction_blocked():
		_fail("world interaction remained blocked after settlement confirmation")
		return
	if ui.temporary_module_settlement_dialog.visible:
		_fail("settlement dialog stayed visible after confirmation")
		return

	ui.module_transaction_dialog_controller.set_temporary_module_confirmation_enabled(true)
	var sell_module := MODULE_SCENE.instantiate() as Module
	var sell_result := InventoryData.obtain_module(sell_module)
	if not bool(sell_result.get("ok", false)):
		_fail("failed to add temporary module for single sell")
		return
	var temporary_count_before_sell := InventoryData.temporary_modules.size()
	var gold_before_sell := PlayerData.player_gold
	if not ui.request_temporary_module_sell_confirmation(sell_module):
		_fail("single temporary module sell confirmation did not open")
		return
	await get_tree().process_frame
	if not ui.is_world_interaction_blocked():
		_fail("single sell dialog did not block world interaction before confirm")
		return
	ui.module_action_dialog.emit_signal("confirmed")
	await get_tree().process_frame
	await get_tree().process_frame
	if InventoryData.temporary_modules.size() != temporary_count_before_sell - 1:
		_fail("single temporary module was not sold after confirmation")
		return
	if PlayerData.player_gold < gold_before_sell:
		_fail("single temporary module sell reduced player gold")
		return
	if ui.is_world_interaction_blocked():
		_fail("world interaction remained blocked after single sell confirmation")
		return
	if ui.module_action_dialog.visible:
		_fail("single sell dialog stayed visible after confirmation")
		return

	_restore(ui)
	print("PASS temporary_module_settlement_confirm_probe")
	printerr("PASS temporary_module_settlement_confirm_probe")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)

func _on_complete() -> void:
	_completed += 1

func _fail(message: String) -> void:
	var ui := GlobalVariables.ui as UI
	if ui != null:
		_restore(ui)
	push_error(message)
	print("FAIL: ", message)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(1)

func _restore(ui: UI) -> void:
	if ui != null and ui.module_transaction_dialog_controller != null:
		ui.module_transaction_dialog_controller.set_temporary_module_confirmation_enabled(_previous_confirmation_enabled)
	InventoryData.reset_runtime_state()
