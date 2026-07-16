extends RefCounted
class_name LocalizationRefreshController

var owner_ui: UI

func bind(ui: UI) -> void:
	owner_ui = ui

func refresh_texts() -> void:
	if owner_ui == null:
		return
	refresh_purchase_primary_texts()
	refresh_upgrade_primary_texts()
	refresh_warehouse_primary_texts()
	if owner_ui.purchase_management_controller != null:
		owner_ui.purchase_management_controller.refresh_texts()
	if owner_ui.upgrade_management_controller != null:
		owner_ui.upgrade_management_controller.refresh_texts()
	if owner_ui.module_warehouse_controller != null:
		owner_ui.module_warehouse_controller.refresh_texts()
	refresh_board_edit_primary_texts()
	refresh_battle_start_primary_texts()
	if owner_ui.management_ui_bootstrap_controller != null:
		owner_ui.management_ui_bootstrap_controller.style_primary_menu_controls()
	owner_ui._init_pause_ui_controller()
	owner_ui.pause_ui_controller.refresh_texts()

func refresh_purchase_primary_texts() -> void:
	if owner_ui.purchase_primary_panel == null:
		return
	var title := owner_ui.purchase_primary_panel.get_node_or_null("Title") as Label
	if title:
		title.text = LocalizationManager.tr_key("ui.merchant.purchase.title", "Purchase")
	var subtitle := owner_ui.purchase_primary_panel.get_node_or_null("SubTitle") as Label
	if subtitle:
		subtitle.text = LocalizationManager.tr_key("ui.merchant.purchase.subtitle", "Choose purchase category")
	var weapon_button := owner_ui.purchase_primary_panel.get_node_or_null("OpenBuyButton") as Button
	if weapon_button:
		weapon_button.text = LocalizationManager.tr_key("ui.purchase.weapons", "Buy Weapons")
	var module_button := owner_ui.purchase_primary_panel.get_node_or_null("OpenBuyModuleButton") as Button
	if module_button:
		module_button.text = LocalizationManager.tr_key("ui.purchase.modules", "Buy Modules")

func refresh_upgrade_primary_texts() -> void:
	if owner_ui.upgrade_primary_panel == null:
		return
	var title := owner_ui.upgrade_primary_panel.get_node_or_null("Title") as Label
	if title:
		title.text = LocalizationManager.tr_key("ui.smith.upgrade.title", "Upgrade")
	var subtitle := owner_ui.upgrade_primary_panel.get_node_or_null("SubTitle") as Label
	if subtitle:
		subtitle.text = LocalizationManager.tr_key("ui.smith.upgrade.subtitle", "Choose upgrade category")
	var weapon_button := owner_ui.upgrade_primary_panel.get_node_or_null("OpenUpgradeButton") as Button
	if weapon_button:
		weapon_button.text = LocalizationManager.tr_key("ui.smith.upgrade.weapon", "Weapon")
	if owner_ui.upgrade_module_button:
		owner_ui.upgrade_module_button.text = LocalizationManager.tr_key("ui.smith.upgrade.module", "Module")

func refresh_warehouse_primary_texts() -> void:
	if owner_ui.warehouse_primary_panel == null:
		return
	var title := owner_ui.warehouse_primary_panel.get_node_or_null("Title") as Label
	if title:
		title.text = LocalizationManager.tr_key("ui.management.menu.title", "Warehouse Management")
	var subtitle := owner_ui.warehouse_primary_panel.get_node_or_null("SubTitle") as Label
	if subtitle:
		subtitle.text = LocalizationManager.tr_key("ui.management.menu.subtitle", "Open weapon and module warehouses")
	var module_button := owner_ui.warehouse_primary_panel.get_node_or_null("OpenModuleButton") as Button
	if module_button:
		module_button.text = LocalizationManager.tr_key("ui.module.warehouse.title", "Module Warehouse")
	if owner_ui.weapon_warehouse_button:
		owner_ui.weapon_warehouse_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.title", "Weapon Warehouse")

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

func refresh_battle_start_primary_texts() -> void:
	if owner_ui == null or owner_ui.battle_start_primary_panel == null:
		return
	var title := owner_ui.battle_start_primary_panel.get_node_or_null("Title") as Label
	if title:
		title.text = LocalizationManager.tr_key("ui.rest.zone.battle.title", "Start Battle")
	var subtitle := owner_ui.battle_start_primary_panel.get_node_or_null("SubTitle") as Label
	if subtitle:
		subtitle.text = LocalizationManager.tr_key(
			"ui.rest.zone.battle.subtitle",
			"Leave the rest area and begin the next fight."
		)
	var start_button := owner_ui.battle_start_primary_panel.get_node_or_null("StartBattleButton") as Button
	if start_button:
		start_button.text = LocalizationManager.tr_key("ui.dialog.action.start_battle", "Start battle")
