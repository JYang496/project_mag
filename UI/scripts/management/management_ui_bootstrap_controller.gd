extends RefCounted
class_name ManagementUiBootstrapController

var owner_ui: UI

func bind(ui: UI) -> void:
	owner_ui = ui

func init_management_ui_polish() -> void:
	if owner_ui == null:
		return
	owner_ui._style_management_panel(owner_ui.purchase_panel)
	owner_ui._style_management_panel(owner_ui.upgrade_panel)
	owner_ui._style_management_panel(owner_ui.module_panel)
	owner_ui._connect_management_panel_input_blockers()

	owner_ui.shop_instruction_label = owner_ui._create_management_instruction(
		owner_ui.purchase_panel,
		"ShopInstruction",
		Vector2(25, 40),
		Vector2(1, 1)
	)
	owner_ui.shop_instruction_label.visible = false
	owner_ui.upgrade_instruction_label = owner_ui._create_management_instruction(
		owner_ui.upgrade_panel,
		"UpgradeInstruction",
		Vector2(25, 42),
		Vector2(480, 30)
	)
	owner_ui._init_upgrade_management_controller()
	owner_ui.upgrade_management_controller.set_instruction_label(owner_ui.upgrade_instruction_label)
	owner_ui.module_instruction_label = owner_ui._create_management_instruction(
		owner_ui.module_panel,
		"ModuleInstruction",
		Vector2(25, 42),
		Vector2(500, 30)
	)
	owner_ui.purchase_management_controller.ensure_view()
	owner_ui.upgrade_management_controller.ensure_view()
	owner_ui.module_warehouse_controller.ensure_view()
	ensure_management_menu_buttons()

	owner_ui._style_management_button(owner_ui.upgrade_panel.get_node_or_null("BackToSmithMenu") as Button)
	owner_ui._position_management_button(owner_ui.upgrade_panel.get_node_or_null("BackToSmithMenu") as Button, Vector2(760, 532), Vector2(200, 52))
	var legacy_module_back := owner_ui.module_panel.get_node_or_null("BackToModuleMenu") as Button
	if legacy_module_back:
		legacy_module_back.visible = false

	for title_panel in [owner_ui.purchase_panel, owner_ui.upgrade_panel, owner_ui.module_panel]:
		var title := title_panel.get_node_or_null("Title") as Label
		if title:
			title.add_theme_font_size_override("font_size", 26)
			title.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	owner_ui.upgrade_management_controller.refresh_action()
	owner_ui.module_warehouse_controller.refresh_action()
	owner_ui.purchase_management_controller.apply_purchase_mode(owner_ui._shop_purchase_mode)

func ensure_management_menu_buttons() -> void:
	if owner_ui == null:
		return
	var upgrade_weapon_button := owner_ui.upgrade_primary_panel.get_node_or_null("OpenUpgradeButton") as Button
	if owner_ui.upgrade_module_button == null:
		owner_ui.upgrade_module_button = Button.new()
		owner_ui.upgrade_module_button.name = "OpenModuleUpgradeButton"
		owner_ui.upgrade_module_button.pressed.connect(owner_ui.rest_area_ui_controller.open_upgrade_panel.bind(&"module"))
		owner_ui.upgrade_primary_panel.add_child(owner_ui.upgrade_module_button)

	var open_module_button := owner_ui.warehouse_primary_panel.get_node_or_null("OpenModuleButton") as Button
	if owner_ui.weapon_warehouse_button == null or not is_instance_valid(owner_ui.weapon_warehouse_button):
		owner_ui.weapon_warehouse_button = Button.new()
		owner_ui.weapon_warehouse_button.name = "OpenWeaponWarehouseButton"
		owner_ui.weapon_warehouse_button.pressed.connect(owner_ui.rest_area_ui_controller.open_warehouse_weapon_panel)
		owner_ui.warehouse_primary_panel.add_child(owner_ui.weapon_warehouse_button)
	owner_ui._style_primary_menu_controls()
