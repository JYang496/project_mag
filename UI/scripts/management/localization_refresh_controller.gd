extends RefCounted
class_name LocalizationRefreshController

var owner_ui: UI

func bind(ui: UI) -> void:
	owner_ui = ui

func refresh_texts() -> void:
	if owner_ui == null:
		return
	owner_ui._init_purchase_management_controller()
	owner_ui.purchase_management_controller.refresh_texts()
	owner_ui._init_upgrade_management_controller()
	owner_ui.upgrade_management_controller.refresh_texts()
	owner_ui._init_module_warehouse_controller()
	owner_ui.module_warehouse_controller.refresh_texts()
	refresh_board_edit_primary_texts()
	owner_ui._init_management_ui_bootstrap_controller()
	owner_ui.management_ui_bootstrap_controller.style_primary_menu_controls()
	owner_ui._init_pause_ui_controller()
	owner_ui.pause_ui_controller.refresh_texts()

func refresh_board_edit_primary_texts() -> void:
	if owner_ui == null or owner_ui.board_edit_primary_panel == null:
		return
	var title := owner_ui.board_edit_primary_panel.get_node_or_null("Title") as Label
	if title:
		title.text = LocalizationManager.tr_key("ui.cell_management.title", "Board")
	var subtitle := owner_ui.board_edit_primary_panel.get_node_or_null("SubTitle") as Label
	if subtitle:
		subtitle.text = LocalizationManager.tr_key(
			"ui.cell_management.subtitle",
			"Install cell effects or deploy task modules."
		)
	var grid_button := owner_ui.board_edit_primary_panel.get_node_or_null(
		"OpenGridManagementButton"
	) as Button
	if grid_button:
		grid_button.text = LocalizationManager.tr_key(
			"ui.cell_management.board_entry",
			"Grid Management"
		)
	var task_button := owner_ui.board_edit_primary_panel.get_node_or_null(
		"OpenTaskManagementButton"
	) as Button
	if task_button:
		task_button.text = LocalizationManager.tr_key(
			"ui.cell_management.task_entry",
			"Task Management"
		)
