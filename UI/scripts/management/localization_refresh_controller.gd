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
	owner_ui._refresh_board_edit_primary_texts()
	owner_ui._style_primary_menu_controls()
	owner_ui._init_pause_ui_controller()
	owner_ui.pause_ui_controller.refresh_texts()
