extends Node

const REST_AREA_SCENE := preload("res://World/rest_area.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const TEST_MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")
const CELL_SCENE := preload("res://Board/Cells/cell.tscn")

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
	var board_label := rest_area.get_node("BoardHintLabel") as Label
	if not merchant.text.contains("\n") or not smith.text.contains("\n") or not module.text.contains("\n") or not board_label.text.contains("\n"):
		_fail("zone hints are not rendered as title/status cards")
		return
	if merchant.get_theme_stylebox("normal") == null:
		_fail("zone hint card style is missing")
		return
	if board_label.get_theme_stylebox("normal") == null:
		_fail("board edit zone hint card style is missing")
		return
	if not rest_area._zone_opens_interaction(6):
		_fail("board edit zone is not routed as a rest-area interaction")
		return
	LocalizationManager.set_locale("zh_CN", false)
	await get_tree().process_frame
	if not board_label.text.contains("格子"):
		_fail("board edit zone hint did not localize to zh_CN")
		return
	LocalizationManager.set_locale("en", false)
	await get_tree().process_frame

	var board := BoardCellGenerator.new()
	board.name = "Board"
	board.cell_scene = CELL_SCENE
	for _index in range(9):
		board.initial_cell_profiles.append(CellProfile.new())
	add_child(board)
	await get_tree().process_frame
	LocalizationManager.set_locale("zh_CN", false)
	await get_tree().process_frame
	if not ui.rest_area_ui_controller.open_board_edit_panel():
		_fail("board edit zone controller did not open the panel")
		return
	if ui.cell_management_panel == null or not ui.cell_management_panel.visible:
		_fail("cell management primary menu is not visible after zone entry")
		return
	var cell_primary_panel := ui.cell_management_panel.get_node_or_null("PrimaryMenu/Panel") as Panel
	if cell_primary_panel == null:
		_fail("cell management primary menu panel is missing")
		return
	var open_grid_button := cell_primary_panel.get_node_or_null("OpenGridManagementButton") as Button
	if open_grid_button == null:
		_fail("cell management primary menu is missing the grid management entry")
		return
	open_grid_button.emit_signal("pressed")
	await get_tree().process_frame
	if ui.board_edit_panel == null or not ui.board_edit_panel.visible:
		_fail("board edit panel is not visible after selecting grid management")
		return
	var board_panel := ui.board_edit_panel.get_node_or_null("BoardEditPanel") as PanelContainer
	if board_panel == null:
		_fail("board edit panel root is missing")
		return
	var board_style := board_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if board_style == null or not board_style.bg_color.is_equal_approx(Color(0.045, 0.065, 0.09, 0.98)):
		_fail("board edit panel does not use the management panel style")
		return
	var detail_label := board_panel.get_node_or_null("ContentMargin/MainLayout/Body/SideContent/DetailLabel") as Label
	if detail_label == null:
		_fail("board edit detail label is missing")
		return
	if detail_label.text.contains("then click") or not detail_label.text.contains("格子效果"):
		_fail("board edit detail hint did not localize cleanly to zh_CN")
		return
	if detail_label.custom_minimum_size.x < 300.0:
		_fail("board edit detail label can collapse into narrow vertical text")
		return
	var empty_label := board_panel.get_node_or_null("ContentMargin/MainLayout/Body/SideContent/InventoryScroll/InventoryList/EmptyInventoryLabel") as Label
	if empty_label == null:
		_fail("board edit empty inventory label is missing")
		return
	if empty_label.text.contains("then click") or not empty_label.text.contains("暂无格子效果"):
		_fail("board edit empty inventory text did not localize cleanly to zh_CN")
		return
	if empty_label.custom_minimum_size.x < 300.0:
		_fail("board edit empty inventory label can collapse into narrow vertical text")
		return
	rest_area.menu_open = true
	rest_area.selected_zone_id = 6
	rest_area._handle_right_click()
	await get_tree().process_frame
	if ui.board_edit_panel.visible:
		_fail("board edit cancel did not close the board edit panel")
		return
	if ui.cell_management_panel == null or not ui.cell_management_panel.visible:
		_fail("board edit cancel did not return to the cell primary menu")
		return
	rest_area._handle_right_click()
	await get_tree().process_frame
	if ui.cell_management_panel.visible or rest_area.menu_open:
		_fail("cell primary cancel did not close the panel and rest-area menu state")
		return
	LocalizationManager.set_locale("en", false)
	await get_tree().process_frame

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
