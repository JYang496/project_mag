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
	if not ui.board_edit_primary_root.visible:
		_fail("board edit primary menu is not visible after zone entry")
		return
	if not ui.is_rest_area_zone_navigation_allowed():
		_fail("board edit primary menu should allow switching rest-area zones")
		return
	var board_primary_panel := ui.board_edit_primary_panel
	var open_grid_button := board_primary_panel.get_node_or_null("OpenGridManagementButton") as Button
	if open_grid_button == null:
		_fail("board edit primary menu is missing the grid management entry")
		return
	open_grid_button.emit_signal("pressed")
	await get_tree().create_timer(0.25).timeout
	if ui.board_edit_panel == null or not ui.board_edit_panel.visible:
		_fail("board edit panel is not visible after selecting grid management")
		return
	if ui.is_rest_area_zone_navigation_allowed():
		_fail("board edit secondary panel should lock rest-area zone switching")
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
	if empty_label != null:
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
	if not ui.board_edit_primary_root.visible:
		_fail("board edit cancel did not return to the board edit primary menu")
		return
	rest_area._handle_right_click()
	await get_tree().create_timer(0.25).timeout
	if ui.board_edit_primary_root.visible or rest_area.menu_open:
		_fail("board edit primary cancel did not close the panel and rest-area menu state")
		return

	if not ui.rest_area_ui_controller.open_board_edit_panel():
		_fail("board edit zone controller did not reopen the primary menu")
		return
	var open_task_button := ui.board_edit_primary_panel.get_node_or_null("OpenTaskManagementButton") as Button
	if open_task_button == null:
		_fail("board edit primary menu is missing the task management entry")
		return
	open_task_button.emit_signal("pressed")
	await get_tree().create_timer(0.25).timeout
	if ui.cell_management_panel == null or not ui.cell_management_panel.visible:
		_fail("task management panel is not visible after selecting task management")
		return
	if ui.is_rest_area_zone_navigation_allowed():
		_fail("task management secondary panel should lock rest-area zone switching")
		return
	var task_panel := ui.cell_management_panel.get_node_or_null("TaskManagementPanel") as Panel
	if task_panel == null:
		_fail("task management panel root is missing")
		return
	get_viewport().warp_mouse(Vector2(8, 8))
	await get_tree().process_frame
	if not rest_area._is_mouse_over_ui():
		_fail("task management secondary menu did not block rest-area map hover outside the panel")
		return
	CellTaskModuleRuntime.reset_runtime_state()
	var task_grant_result: Dictionary = CellTaskModuleRuntime.grant_module("task_kill_common")
	if not bool(task_grant_result.get("ok", false)):
		_fail("failed to grant task module for panel size test")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var task_inventory_list := ui.cell_management_panel.find_child("TaskInventoryList", true, false) as VBoxContainer
	if task_inventory_list == null or task_inventory_list.get_child_count() <= 0:
		_fail("task management inventory list missing module button for panel size test")
		return
	var task_button := task_inventory_list.get_child(0) as Button
	if task_button == null:
		_fail("task management inventory entry is not a button")
		return
	if _node_tree_text_contains(task_button, "Deploy to an active cell"):
		_fail("task management inventory card should not show detailed task descriptions")
		return
	task_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	if task_panel.size.y > 600.0:
		_fail("task management panel grew beyond its fixed height after selecting a task module")
		return
	ui.cell_management_panel.call("clear_selection_if_any")
	await get_tree().process_frame
	var task_drag_payload: Dictionary = task_button.get("drag_payload")
	var task_drag_data: Dictionary = ui.cell_management_panel.call("build_drag_data", task_drag_payload, null)
	if task_drag_data.is_empty():
		_fail("task management inventory entry did not build drag data")
		return
	if not bool(ui.cell_management_panel.call("can_drop_payload", {"kind": "task_cell", "cell_id": 5}, task_drag_data)):
		_fail("task management cell did not accept a valid dragged task module")
		return
	var dropped_task := bool(ui.cell_management_panel.call("drop_payload", {"kind": "task_cell", "cell_id": 5}, task_drag_data))
	if not dropped_task:
		_fail("dragging a task module onto an empty cell did not deploy it")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var deployments := CellTaskModuleRuntime.get_deployment_snapshot()
	if str(deployments.get("5", "")) != "task_kill_common":
		_fail("dragging a task module onto an empty cell deployed the wrong module")
		return
	if task_panel.size.y > 600.0:
		_fail("task management panel grew beyond its fixed height after deployment")
		return
	var deployed_cell_button: Button = null
	for child in ui.cell_management_panel.find_children("*", "Button", true, false):
		var button := child as Button
		for nested in button.find_children("*", "Label", true, false):
			var label := nested as Label
			if label != null and label.text == "Cell 5":
				deployed_cell_button = button
				break
		if deployed_cell_button != null:
			break
	if deployed_cell_button == null:
		_fail("task management could not find deployed cell 5 preview button")
		return
	ui.cell_management_panel.call("_on_cell_hovered", 5)
	await get_tree().process_frame
	var task_detail_window := ui.cell_management_panel.find_child("TaskDetailWindow", true, false) as Control
	if task_detail_window == null or not task_detail_window.visible:
		_fail("hovering a deployed task cell should show the task detail window")
		return
	if not _node_tree_text_contains(task_detail_window, "Cell 5") or not _node_tree_text_contains(task_detail_window, "Kill Task Module"):
		_fail("task detail hover window title does not identify the cell and task module")
		return
	if not _node_tree_text_contains(task_detail_window, "Complete to receive a cell task reward."):
		_fail("task detail window is missing the reward summary")
		return
	ui.cell_management_panel.call("_on_cell_unhovered", 5)
	await get_tree().process_frame
	if task_detail_window.visible:
		_fail("task detail hover window should close when hover leaves without a locked cell")
		return
	ui.cell_management_panel.call("_on_cell_pressed", 5)
	await get_tree().process_frame
	if not task_detail_window.visible:
		_fail("clicking a deployed task cell should lock the task detail window open")
		return
	deployments = CellTaskModuleRuntime.get_deployment_snapshot()
	if not deployments.has("5"):
		_fail("clicking a deployed task cell without inventory selection should not cancel deployment")
		return
	if deployed_cell_button.toggle_mode or deployed_cell_button.button_pressed:
		_fail("clicking a cell without inventory selection should not change button pressed UI state")
		return
	if not bool(ui.cell_management_panel.call("clear_selection_if_any")) or task_detail_window.visible:
		_fail("task detail window should close through the panel cancel path")
		return
	task_grant_result = CellTaskModuleRuntime.grant_module("task_hold_common")
	if not bool(task_grant_result.get("ok", false)):
		_fail("failed to grant replacement task module for overwrite test")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	task_inventory_list = ui.cell_management_panel.find_child("TaskInventoryList", true, false) as VBoxContainer
	if task_inventory_list == null or task_inventory_list.get_child_count() <= 0:
		_fail("task management inventory list missing replacement module button")
		return
	task_button = task_inventory_list.get_child(0) as Button
	if task_button == null:
		_fail("task management replacement inventory entry is not a button")
		return
	task_drag_payload = task_button.get("drag_payload")
	task_drag_data = ui.cell_management_panel.call("build_drag_data", task_drag_payload, null)
	if task_drag_data.is_empty():
		_fail("task management replacement inventory entry did not build drag data")
		return
	if not bool(ui.cell_management_panel.call("drop_payload", {"kind": "task_cell", "cell_id": 5}, task_drag_data)):
		_fail("dragging a task module onto an occupied cell should open overwrite confirmation")
		return
	await get_tree().process_frame
	var overwrite_dialog := ui.cell_management_panel.find_child("TaskOverwriteConfirmDialog", true, false) as ConfirmationDialog
	if overwrite_dialog == null or not overwrite_dialog.visible:
		_fail("task management overwrite should request confirmation before replacing a deployed task")
		return
	deployments = CellTaskModuleRuntime.get_deployment_snapshot()
	if str(deployments.get("5", "")) != "task_kill_common":
		_fail("task management overwrite replaced deployment before confirmation")
		return
	overwrite_dialog.emit_signal("confirmed")
	await get_tree().process_frame
	deployments = CellTaskModuleRuntime.get_deployment_snapshot()
	if str(deployments.get("5", "")) != "task_hold_common":
		_fail("task management overwrite confirmation did not replace deployed task")
		return
	CellTaskModuleRuntime.reset_runtime_state()
	rest_area.menu_open = true
	rest_area.selected_zone_id = 6
	rest_area._handle_right_click()
	await get_tree().process_frame
	if ui.cell_management_panel.visible or not ui.board_edit_primary_root.visible:
		_fail("task management cancel did not return to the board edit primary menu")
		return
	LocalizationManager.set_locale("en", false)
	await get_tree().process_frame

	PhaseManager.phase = PhaseManager.BATTLE
	TaskRewardManager.notify_objective_completed("5")
	PhaseManager.phase = PhaseManager.PREPARE
	await get_tree().process_frame
	if rest_area.is_processing_input():
		_fail("rest area input stayed enabled while objective reward was pending")
		return
	TaskRewardManager.reset_runtime_state()
	await get_tree().process_frame
	if not rest_area.is_processing_input():
		_fail("rest area input did not recover after objective reward was cleared")
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
	if ui.equipped_shop != null and ui.equipped_shop.visible:
		_fail("first purchase weapon panel open still shows legacy equipped-grid UI")
		return
	if ui.shop_detail_panel == null or not ui.shop_detail_panel.visible:
		_fail("first purchase weapon panel open should show the purchase detail panel")
		return
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

func _node_tree_text_contains(root: Node, text: String) -> bool:
	if root == null:
		return false
	var label := root as Label
	if label != null and label.text.contains(text):
		return true
	var button := root as Button
	if button != null and button.text.contains(text):
		return true
	for child in root.get_children():
		if _node_tree_text_contains(child, text):
			return true
	return false

func _fail(message: String) -> void:
	push_error("RestAreaZoneHintTest: " + message)
	InventoryData.reset_runtime_state()
	get_tree().quit(1)
