extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")
const RESULT_PATH := "user://equipped_module_sell_probe_result.txt"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_write_result("RUNNING")
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()

	var player := PLAYER_SCENE.instantiate() as Player
	get_tree().root.add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	if PlayerData.player_weapon_list.is_empty():
		_fail("player has no weapon for equipped module sale")
		return
	var weapon := PlayerData.player_weapon_list[0] as Weapon
	if weapon == null or weapon.modules == null:
		_fail("weapon has no module container")
		return

	var ui := UI_SCENE.instantiate() as UI
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	var module_instance := MODULE_SCENE.instantiate() as Module
	weapon.modules.add_child(module_instance)
	module_instance.set_module_level(1)
	weapon.calculate_status()

	ui.module_warehouse_controller.open_tab(&"module")
	var view: ModuleManagementView = ui.module_warehouse_controller.module_management_view
	view.selected_module = null
	view.selected_equipped_module = module_instance
	view.selected_equipped_module_weapon = weapon
	view.refresh_action()

	if view.module_sell_button.disabled:
		_fail("sell button stayed disabled for equipped module")
		return
	if not ui.request_temporary_module_sell_confirmation(module_instance):
		_fail("equipped module sell confirmation did not open")
		return

	var gold_before := PlayerData.player_gold
	ui.module_action_dialog.emit_signal("confirmed")
	await get_tree().process_frame
	await get_tree().process_frame

	if is_instance_valid(module_instance):
		_fail("equipped module still exists after sale")
		return
	if weapon.modules.get_child_count() != 0:
		_fail("equipped module stayed in weapon slot after sale")
		return
	if PlayerData.player_gold <= gold_before:
		_fail("equipped module sale did not add gold")
		return

	InventoryData.reset_runtime_state()
	_write_result("PASS equipped_module_sell_probe")
	print("PASS equipped_module_sell_probe")
	printerr("PASS equipped_module_sell_probe")
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0)

func _fail(message: String) -> void:
	InventoryData.reset_runtime_state()
	_write_result("FAIL: %s" % message)
	push_error(message)
	print("FAIL: ", message)
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(1)

func _write_result(message: String) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(message)
