extends RefCounted
class_name ModuleWarehouseController

const MODULE_MANAGEMENT_VIEW_PATH := "res://UI/scenes/management/module_management_view.tscn"

var owner_ui: UI
var module_panel: Panel
var module_management_view: ModuleManagementView
var equipped_m: GridContainer
var modules: GridContainer
var module_selection_label: Label
var module_equip_button: Button
var module_sell_button: Button
var selected_temporary_module: Module
var active_tab: StringName = &"weapon"

func bind(ui: UI, panel: Panel) -> void:
	owner_ui = ui
	module_panel = panel

func ensure_view() -> bool:
	if module_management_view != null and is_instance_valid(module_management_view):
		return true
	var view_scene := load(MODULE_MANAGEMENT_VIEW_PATH) as PackedScene
	module_management_view = view_scene.instantiate() as ModuleManagementView if view_scene else null
	if module_management_view == null:
		push_warning("Failed to create ModuleManagementView.")
		return false
	module_panel.add_child(module_management_view)
	module_management_view.bind(owner_ui, self)
	module_management_view.active_tab = active_tab
	module_management_view.set_selected_module(selected_temporary_module)
	_bind_view_fields()
	_sync_public_fields_to_owner()
	return true

func open_tab(tab: StringName) -> void:
	active_tab = &"module" if tab == &"module" else &"weapon"
	if not ensure_view():
		return
	module_management_view.apply_tab(active_tab)
	_refresh_panel_title()
	selected_temporary_module = module_management_view.get_selected_module()
	_bind_view_fields()
	_sync_public_fields_to_owner()

func update_modules() -> void:
	if not ensure_view():
		return
	sync_state_from_owner()
	module_management_view.active_tab = active_tab
	module_management_view.set_selected_module(selected_temporary_module)
	module_management_view.refresh_all()
	_refresh_panel_title()
	selected_temporary_module = module_management_view.get_selected_module()
	_bind_view_fields()
	_sync_public_fields_to_owner()

func on_temporary_module_selected(module_instance: Module) -> void:
	if not ensure_view():
		return
	active_tab = &"module"
	module_management_view.select_module(module_instance, null)
	selected_temporary_module = module_management_view.get_selected_module()
	_sync_public_fields_to_owner()

func on_equip_pressed() -> void:
	on_primary_action_pressed()

func on_sell_pressed() -> void:
	on_secondary_action_pressed()

func on_primary_action_pressed() -> void:
	if not ensure_view():
		return
	if module_management_view.perform_primary_action():
		selected_temporary_module = module_management_view.get_selected_module()
		_sync_public_fields_to_owner()

func on_secondary_action_pressed() -> void:
	if not ensure_view():
		return
	if module_management_view.perform_secondary_action():
		selected_temporary_module = module_management_view.get_selected_module()
		_sync_public_fields_to_owner()

func refresh_action() -> void:
	if module_management_view == null or not is_instance_valid(module_management_view):
		return
	sync_state_from_owner()
	module_management_view.set_selected_module(selected_temporary_module)
	module_management_view.refresh_action()
	selected_temporary_module = module_management_view.get_selected_module()
	_sync_public_fields_to_owner()

func refresh_texts() -> void:
	if module_panel == null:
		return
	_refresh_panel_title()
	if owner_ui.module_instruction_label:
		owner_ui.module_instruction_label.text = LocalizationManager.tr_key(
			"ui.warehouse.instruction",
			"Manage the selected warehouse."
		)
	var warehouse_menu_title := owner_ui.warehouse_primary_panel.get_node_or_null("Title") as Label
	if warehouse_menu_title:
		warehouse_menu_title.text = LocalizationManager.tr_key("ui.management.menu.title", "Warehouse Management")
	var warehouse_menu_subtitle := owner_ui.warehouse_primary_panel.get_node_or_null("SubTitle") as Label
	if warehouse_menu_subtitle:
		warehouse_menu_subtitle.text = LocalizationManager.tr_key("ui.management.menu.subtitle", "Open weapon and module warehouses")
	var warehouse_menu_open := owner_ui.warehouse_primary_panel.get_node_or_null("OpenModuleButton") as Button
	if warehouse_menu_open:
		warehouse_menu_open.text = LocalizationManager.tr_key("ui.module.warehouse.title", "Module Warehouse")
	if owner_ui.weapon_warehouse_button:
		owner_ui.weapon_warehouse_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.title", "Weapon Warehouse")
	var module_back := module_panel.get_node_or_null("BackToModuleMenu") as Button
	if module_back:
		module_back.text = LocalizationManager.tr_key("ui.panel.back", "Back")
	if owner_ui != null and owner_ui.has_method("_style_primary_menu_controls"):
		owner_ui.call("_style_primary_menu_controls")
	if module_management_view and is_instance_valid(module_management_view):
		module_management_view.refresh_all()

func sync_state_from_owner() -> void:
	if owner_ui == null:
		return
	selected_temporary_module = owner_ui.selected_temporary_module

func _bind_view_fields() -> void:
	if module_management_view == null:
		return
	equipped_m = module_management_view.equipped_m
	modules = module_management_view.modules
	module_selection_label = module_management_view.module_selection_label
	module_equip_button = module_management_view.module_equip_button
	module_sell_button = module_management_view.module_sell_button

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui.module_management_view = module_management_view
	owner_ui.equipped_m = equipped_m
	owner_ui.modules = modules
	owner_ui.module_selection_label = module_selection_label
	owner_ui.module_equip_button = module_equip_button
	owner_ui.module_sell_button = module_sell_button
	owner_ui.selected_temporary_module = selected_temporary_module

func _refresh_panel_title() -> void:
	if module_panel == null:
		return
	var module_title := module_panel.get_node_or_null("Title") as Label
	if module_title == null:
		return
	if active_tab == &"module":
		module_title.text = LocalizationManager.tr_key("ui.module.warehouse.title", "Module Warehouse")
	else:
		module_title.text = LocalizationManager.tr_key("ui.weapon.warehouse.title", "Weapon Warehouse")
