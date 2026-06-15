extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const TEST_MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_fail(1, "TemporaryModuleSettlementDialogTest: failed to instantiate player.")
		return
	get_tree().root.add_child(player)
	var ui := UI_SCENE.instantiate() as UI
	if ui == null:
		_fail(2, "TemporaryModuleSettlementDialogTest: failed to instantiate UI.")
		return
	get_tree().root.add_child(ui)
	await get_tree().process_frame

	var module_instance := TEST_MODULE_SCENE.instantiate() as Module
	if module_instance == null:
		_fail(3, "TemporaryModuleSettlementDialogTest: failed to instantiate module.")
		return
	InventoryData.obtain_module(module_instance)
	ui.request_temporary_module_settlement(Callable(self, "_noop"))

	var dialog := ui.temporary_module_settlement_dialog
	var viewport_size := get_viewport().get_visible_rect().size
	var confirm_button := dialog.get_ok_button()
	if dialog.wrap_controls:
		_fail(4, "TemporaryModuleSettlementDialogTest: settlement dialog still auto-wraps controls.")
		return
	if dialog.size.y >= viewport_size.y:
		_fail(
			5,
			"TemporaryModuleSettlementDialogTest: first popup height %d covers viewport height %d." %
				[dialog.size.y, int(viewport_size.y)]
		)
		return
	await get_tree().process_frame
	if confirm_button.position.y + confirm_button.size.y > dialog.size.y:
		_fail(
			6,
			"TemporaryModuleSettlementDialogTest: confirm button bottom %.1f exceeds dialog height %d." %
				[confirm_button.position.y + confirm_button.size.y, dialog.size.y]
		)
		return
	dialog.hide()
	await get_tree().process_frame
	ui.request_temporary_module_settlement(Callable(self, "_noop"))
	await get_tree().process_frame
	if dialog.size.y >= viewport_size.y:
		_fail(
			7,
			"TemporaryModuleSettlementDialogTest: second popup height %d covers viewport height %d." %
				[dialog.size.y, int(viewport_size.y)]
		)
		return
	if confirm_button.position.y + confirm_button.size.y > dialog.size.y:
		_fail(
			8,
			"TemporaryModuleSettlementDialogTest: second popup confirm button is outside the dialog."
		)
		return

	InventoryData.reset_runtime_state()
	print("TemporaryModuleSettlementDialogTest: PASS")
	get_tree().quit(0)

func _noop() -> void:
	pass

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
