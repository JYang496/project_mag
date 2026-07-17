extends RefCounted
class_name ManagementUiBootstrapController

const REUSABLE_PRIMARY_MENU_SCRIPT := preload("res://UI/scripts/management/reusable_primary_menu.gd")

var owner_ui: UI
var _shell_polish_ready := false
var _purchase_polish_ready := false
var _upgrade_polish_ready := false
var _warehouse_polish_ready := false

func bind(ui: UI) -> void:
	owner_ui = ui

func init_management_ui_polish() -> void:
	if owner_ui == null or _shell_polish_ready:
		return
	_shell_polish_ready = true
	var style_helper: ManagementUiStyleHelper = owner_ui.management_ui_style_helper
	style_helper.style_management_panel(owner_ui.purchase_panel)
	style_helper.style_management_panel(owner_ui.upgrade_panel)
	style_helper.style_management_panel(owner_ui.module_panel)
	style_helper.connect_management_panel_input_blockers(
		owner_ui,
		[owner_ui.purchase_panel, owner_ui.upgrade_panel, owner_ui.module_panel]
	)

	ensure_management_menu_buttons()

	var upgrade_back := owner_ui.upgrade_panel.get_node_or_null("BackToUpgradeMenu") as Button
	style_helper.style_management_button(upgrade_back)
	style_helper.position_management_button(upgrade_back, Vector2(760, 532), Vector2(200, 52))
	var legacy_module_back := owner_ui.module_panel.get_node_or_null("BackToWarehouseMenu") as Button
	if legacy_module_back:
		legacy_module_back.visible = false

	for title_panel in [owner_ui.purchase_panel, owner_ui.upgrade_panel, owner_ui.module_panel]:
		style_helper.style_management_title(
			title_panel.get_node_or_null("Title") as Label
		)

func init_purchase_ui_polish() -> void:
	init_management_ui_polish()
	if owner_ui == null or _purchase_polish_ready:
		return
	owner_ui.shop_instruction_label = owner_ui.management_ui_style_helper.create_management_instruction(
		owner_ui.purchase_panel, "ShopInstruction", Vector2(25, 40), Vector2(1, 1)
	)
	owner_ui.shop_instruction_label.visible = false
	if not owner_ui.purchase_management_controller.ensure_view():
		owner_ui.shop_instruction_label.queue_free()
		owner_ui.shop_instruction_label = null
		return
	owner_ui.purchase_management_controller.apply_purchase_mode(owner_ui._shop_purchase_mode)
	_purchase_polish_ready = true

func init_upgrade_ui_polish() -> void:
	init_management_ui_polish()
	if owner_ui == null or _upgrade_polish_ready:
		return
	owner_ui.upgrade_instruction_label = owner_ui.management_ui_style_helper.create_management_instruction(
		owner_ui.upgrade_panel, "UpgradeInstruction", Vector2(25, 42), Vector2(480, 30)
	)
	owner_ui.upgrade_management_controller.set_instruction_label(owner_ui.upgrade_instruction_label)
	if not owner_ui.upgrade_management_controller.ensure_view():
		owner_ui.upgrade_instruction_label.queue_free()
		owner_ui.upgrade_instruction_label = null
		return
	owner_ui.upgrade_management_controller.refresh_action()
	_upgrade_polish_ready = true

func init_warehouse_ui_polish() -> void:
	init_management_ui_polish()
	if owner_ui == null or _warehouse_polish_ready:
		return
	owner_ui.module_instruction_label = owner_ui.management_ui_style_helper.create_management_instruction(
		owner_ui.module_panel, "ModuleInstruction", Vector2(25, 42), Vector2(500, 30)
	)
	if not owner_ui.module_warehouse_controller.ensure_view():
		owner_ui.module_instruction_label.queue_free()
		owner_ui.module_instruction_label = null
		return
	owner_ui.module_warehouse_controller.refresh_action()
	_warehouse_polish_ready = true

func ensure_management_menu_buttons() -> void:
	if owner_ui == null:
		return
	var buy_button := owner_ui.purchase_primary_panel.get_node_or_null("OpenBuyButton") as Button
	_connect_button_pressed(buy_button, owner_ui.rest_area_ui_controller.open_purchase_weapon_panel)
	var buy_module_button := owner_ui.purchase_primary_panel.get_node_or_null("OpenBuyModuleButton") as Button
	_connect_button_pressed(buy_module_button, owner_ui.rest_area_ui_controller.open_purchase_module_panel)
	var upgrade_weapon_button := owner_ui.upgrade_primary_panel.get_node_or_null("OpenUpgradeButton") as Button
	_connect_button_pressed(upgrade_weapon_button, owner_ui.rest_area_ui_controller.open_upgrade_panel.bind(&"weapon"))
	if owner_ui.upgrade_module_button == null:
		owner_ui.upgrade_module_button = Button.new()
		owner_ui.upgrade_module_button.name = "OpenModuleUpgradeButton"
		owner_ui.upgrade_module_button.text = LocalizationManager.tr_key("ui.smith.upgrade.module", "Module")
		owner_ui.upgrade_primary_panel.add_child(owner_ui.upgrade_module_button)
	_connect_button_pressed(owner_ui.upgrade_module_button, owner_ui.rest_area_ui_controller.open_upgrade_panel.bind(&"module"))
	# Secondary management panels are loaded later with Management Shell.
	if owner_ui.upgrade_panel != null:
		var upgrade_back := owner_ui.upgrade_panel.get_node_or_null("BackToUpgradeMenu") as Button
		_connect_button_pressed(upgrade_back, owner_ui.rest_area_ui_controller.back_to_upgrade_primary_menu)

	var open_module_button := owner_ui.warehouse_primary_panel.get_node_or_null("OpenModuleButton") as Button
	_connect_button_pressed(open_module_button, owner_ui.rest_area_ui_controller.open_warehouse_management_panel)
	if owner_ui.weapon_warehouse_button == null or not is_instance_valid(owner_ui.weapon_warehouse_button):
		owner_ui.weapon_warehouse_button = Button.new()
		owner_ui.weapon_warehouse_button.name = "OpenWeaponWarehouseButton"
		owner_ui.weapon_warehouse_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.title", "Weapon Warehouse")
		owner_ui.warehouse_primary_panel.add_child(owner_ui.weapon_warehouse_button)
	_connect_button_pressed(owner_ui.weapon_warehouse_button, owner_ui.rest_area_ui_controller.open_warehouse_weapon_panel)
	if owner_ui.module_panel != null:
		var warehouse_back := owner_ui.module_panel.get_node_or_null("BackToWarehouseMenu") as Button
		_connect_button_pressed(warehouse_back, owner_ui.rest_area_ui_controller.back_to_warehouse_primary_menu)
	var open_grid_button := owner_ui.board_edit_primary_panel.get_node_or_null("OpenGridManagementButton") as Button
	_connect_button_pressed(open_grid_button, owner_ui.rest_area_ui_controller.open_cell_grid_panel)
	var open_task_button := owner_ui.board_edit_primary_panel.get_node_or_null("OpenTaskManagementButton") as Button
	_connect_button_pressed(open_task_button, owner_ui.rest_area_ui_controller.open_cell_task_panel)
	var start_battle_button := owner_ui.battle_start_primary_panel.get_node_or_null("StartBattleButton") as Button
	_connect_button_pressed(start_battle_button, owner_ui.rest_area_ui_controller.start_battle_from_primary_menu)
	style_primary_menu_controls()

func style_primary_menu_controls() -> void:
	if owner_ui == null:
		return
	if owner_ui.rest_area_ui_controller != null:
		for menu_id in owner_ui.rest_area_ui_controller.get_registered_service_menu_ids():
			_apply_primary_menu_layout(
				owner_ui.rest_area_ui_controller.get_service_primary_panel(menu_id) as Panel,
				owner_ui.rest_area_ui_controller.get_service_primary_buttons(menu_id)
			)
		return
	_apply_primary_menu_layout(
		owner_ui.purchase_primary_panel,
		[
			owner_ui.purchase_primary_panel.get_node_or_null("OpenBuyButton") as Button,
			owner_ui.purchase_primary_panel.get_node_or_null("OpenBuyModuleButton") as Button,
		]
	)
	_apply_primary_menu_layout(
		owner_ui.upgrade_primary_panel,
		[
			owner_ui.upgrade_primary_panel.get_node_or_null("OpenUpgradeButton") as Button,
			owner_ui.upgrade_module_button,
		]
	)
	_apply_primary_menu_layout(
		owner_ui.warehouse_primary_panel,
		[
			owner_ui.weapon_warehouse_button,
			owner_ui.warehouse_primary_panel.get_node_or_null("OpenModuleButton") as Button,
		]
	)
	_apply_primary_menu_layout(
		owner_ui.board_edit_primary_panel,
		[
			owner_ui.board_edit_primary_panel.get_node_or_null("OpenGridManagementButton") as Button,
			owner_ui.board_edit_primary_panel.get_node_or_null("OpenTaskManagementButton") as Button,
		]
	)
	_apply_primary_menu_layout(
		owner_ui.battle_start_primary_panel,
		[
			owner_ui.battle_start_primary_panel.get_node_or_null("StartBattleButton") as Button,
		]
	)

func _apply_primary_menu_layout(panel: Panel, buttons: Array) -> void:
	REUSABLE_PRIMARY_MENU_SCRIPT.apply_shared_layout(
		panel,
		buttons,
		owner_ui.management_ui_style_helper
	)

func _connect_button_pressed(button: Button, target: Callable) -> void:
	if button == null or not target.is_valid():
		return
	if not button.pressed.is_connected(target):
		button.pressed.connect(target)
