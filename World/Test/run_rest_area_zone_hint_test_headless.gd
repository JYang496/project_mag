extends Node

const REST_AREA_SCENE := preload("res://World/rest_area.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const TEST_MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("RestAreaZoneHintTest: START")
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	var player := PLAYER_SCENE.instantiate() as Player
	get_tree().root.add_child(player)
	await get_tree().process_frame
	var ui := UI_SCENE.instantiate() as UI
	get_tree().root.add_child(ui)
	var rest_area := REST_AREA_SCENE.instantiate() as RestArea
	add_child(rest_area)
	await get_tree().process_frame

	var merchant := rest_area.get_node("MerchantHintLabel") as Label
	var smith := rest_area.get_node("SmithHintLabel") as Label
	var module := rest_area.get_node("ModuleHintLabel") as Label
	if not merchant.text.contains("\n") or not smith.text.contains("\n") or not module.text.contains("\n"):
		_fail("zone hints are not rendered as title/status cards")
		return
	if merchant.get_theme_stylebox("normal") == null:
		_fail("zone hint card style is missing")
		return

	ui.rest_area_ui_controller.open_menu(&"purchase")
	rest_area.menu_open = true
	rest_area.selected_zone_id = 0
	await get_tree().process_frame
	rest_area._handle_right_click()
	await get_tree().process_frame
	if rest_area.menu_open:
		_fail("primary menu cancel left the rest-area menu state open")
		return
	if ui.rest_area_ui_controller.is_purchase_active():
		_fail("primary menu cancel did not close the UI menu")
		return

	ui.rest_area_ui_controller.open_menu(&"purchase")
	rest_area.menu_open = true
	rest_area.selected_zone_id = 0
	ui.rest_area_ui_controller.open_purchase_weapon_panel()
	await get_tree().create_timer(0.25).timeout
	ui.rest_area_ui_controller.close_purchase_panel()
	await get_tree().process_frame
	rest_area._sync_menu_open_with_ui()
	if rest_area.menu_open:
		_fail("purchase panel exit left the rest-area menu state open")
		return

	ui.rest_area_ui_controller.open_menu(&"upgrade")
	rest_area.menu_open = true
	rest_area.selected_zone_id = 1
	ui.rest_area_ui_controller.open_upgrade_panel()
	await get_tree().create_timer(0.25).timeout
	ui.rest_area_ui_controller.close_upgrade_panel()
	await get_tree().process_frame
	rest_area._sync_menu_open_with_ui()
	if rest_area.menu_open:
		_fail("upgrade panel exit left the rest-area menu state open")
		return

	ui.rest_area_ui_controller.open_menu(&"warehouse")
	rest_area.menu_open = true
	rest_area.selected_zone_id = 2
	ui.rest_area_ui_controller.open_warehouse_management_panel()
	await get_tree().create_timer(0.25).timeout
	ui.rest_area_ui_controller.close_warehouse_panel()
	ui.warehouse_primary_root.visible = false
	await get_tree().process_frame
	rest_area._sync_menu_open_with_ui()
	if rest_area.menu_open:
		_fail("module warehouse exit left the rest-area menu state open")
		return

	ui.rest_area_ui_controller.open_menu(&"warehouse")
	rest_area.menu_open = true
	rest_area.selected_zone_id = 2
	ui.warehouse_primary_root.visible = false
	await get_tree().process_frame
	rest_area._sync_menu_open_with_ui()
	if rest_area.menu_open:
		_fail("warehouse menu hidden state left the rest-area menu state open")
		return

	var module_instance := TEST_MODULE_SCENE.instantiate() as Module
	InventoryData.obtain_module(module_instance)
	await get_tree().process_frame
	if not module.text.contains("1"):
		_fail("pending module count did not refresh")
		return

	ui.warehouse_management_root.visible = true
	await get_tree().process_frame
	if not merchant.visible or not smith.visible or not module.visible:
		_fail("zone hints were hidden while a rest-area menu was open")
		return
	get_viewport().warp_mouse(Vector2(8, 8))
	await get_tree().process_frame
	if not rest_area._is_mouse_over_ui():
		_fail("warehouse secondary menu did not block rest-area map clicks outside the panel")
		return

	InventoryData.reset_runtime_state()
	print("RestAreaZoneHintTest: PASS")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RestAreaZoneHintTest: " + message)
	InventoryData.reset_runtime_state()
	get_tree().quit(1)
