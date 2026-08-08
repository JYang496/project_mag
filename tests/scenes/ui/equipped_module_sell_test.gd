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

	if PlayerData.player_weapon_list.is_empty():
		_fail("player has no weapon for equipped module sale")
		return
	var weapon := PlayerData.player_weapon_list[0] as Weapon
	if weapon == null or weapon.modules == null:
		_fail("weapon has no module container")
		return

	var ui := UI_SCENE.instantiate() as UI
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	ui.ensure_warehouse_management()
	await get_tree().process_frame

	var module_instance := MODULE_SCENE.instantiate() as Module
	weapon.modules.add_child(module_instance)
	module_instance.set_module_level(1)
	weapon.calculate_status()

	ui.module_warehouse_controller.open_tab(&"module")
	var view: ModuleManagementView = ui.module_warehouse_controller.module_management_view
	await get_tree().process_frame
	var left_list := view.get("_left_list") as VBoxContainer
	var weapon_card: PanelContainer
	for child in left_list.get_children():
		var candidate := child as PanelContainer
		if candidate != null and candidate.get_meta("weapon", null) == weapon:
			weapon_card = candidate
			break
	if weapon_card == null or weapon_card.find_child("WeaponIcon", true, false) == null:
		_fail("module weapon card missing visual weapon anchor")
		return
	var slot_row := weapon_card.find_child("ModuleSlots", true, false) as HBoxContainer
	if slot_row == null or slot_row.get_child_count() != int(weapon.MAX_MODULE_NUMBER):
		_fail("module weapon card did not render every socket")
		return
	for slot in slot_row.get_children():
		if slot.find_child("SlotBadge", true, false) == null or slot.find_child("ModuleIcon", true, false) == null:
			_fail("module socket missing icon-led state cues")
			return
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
	print("PASS equipped module sell")
	await TEST_TEARDOWN.finish(self, 0, _reset_runtime_state)

func _fail(message: String) -> void:
	push_error(message)
	print("FAIL: ", message)
	await TEST_TEARDOWN.finish(self, 1, _reset_runtime_state)

func _reset_runtime_state() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
