extends RefCounted
class_name UpgradeManagementController

const UPGRADE_MANAGEMENT_VIEW_PATH := "res://UI/scenes/management/upgrade_management_view.tscn"

var owner_ui: Node
var upgrade_panel: Panel
var upgrade_instruction_label: Label
var upgrade_management_view
var upgrade_action_button: Button
var upgrade_mode_buttons: HBoxContainer
var upgrade_weapon_mode_button: Button
var upgrade_module_mode_button: Button
var upgrade_item_scroll: ScrollContainer
var upgrade_item_list: BoxContainer
var upgrade_detail_panel: PanelContainer
var upgrade_detail_title: Label
var upgrade_detail_subtitle: Label
var upgrade_detail_body: VBoxContainer
var mode: StringName = &"weapon"
var hover_item: Dictionary = {}
var selected_item: Dictionary = {}
var selected_module: Module

func bind(ui: Node, panel: Panel, instruction_label: Label = null) -> void:
	owner_ui = ui
	upgrade_panel = panel
	upgrade_instruction_label = instruction_label

func set_instruction_label(label: Label) -> void:
	upgrade_instruction_label = label

func ensure_view() -> bool:
	if upgrade_item_list != null and upgrade_management_view != null and is_instance_valid(upgrade_management_view):
		return true
	if upgrade_instruction_label:
		upgrade_instruction_label.visible = false
	var view_scene := load(UPGRADE_MANAGEMENT_VIEW_PATH) as PackedScene
	upgrade_management_view = view_scene.instantiate() as Control if view_scene else null
	if upgrade_management_view == null:
		push_warning("Failed to create UpgradeManagementView.")
		return false
	upgrade_panel.add_child(upgrade_management_view)
	upgrade_management_view.bind(owner_ui, self)
	_bind_view_fields()
	_sync_public_fields_to_owner()
	apply_mode(mode)
	return true

func update_upg() -> void:
	refresh_action()
	refresh_template()

func on_weapon_mode_pressed() -> void:
	apply_mode(&"weapon")

func on_module_mode_pressed() -> void:
	apply_mode(&"module")

func apply_mode(new_mode: StringName) -> void:
	if not ensure_view():
		return
	sync_state_to_view()
	upgrade_management_view.apply_mode(new_mode)
	sync_view_state()

func refresh_template() -> void:
	if upgrade_management_view == null or not is_instance_valid(upgrade_management_view):
		return
	sync_state_to_view()
	upgrade_management_view.refresh_template()
	sync_view_state()

func ensure_item_list_layout() -> void:
	if upgrade_management_view and is_instance_valid(upgrade_management_view):
		upgrade_management_view.ensure_item_list_layout()
		upgrade_item_list = upgrade_management_view.upgrade_item_list
		_sync_public_fields_to_owner()

func create_module_row() -> HBoxContainer:
	if upgrade_management_view and is_instance_valid(upgrade_management_view):
		return upgrade_management_view.create_module_row()
	return null

func build_items(item_mode: StringName) -> Array[Dictionary]:
	if not ensure_view():
		var empty: Array[Dictionary] = []
		return empty
	sync_state_to_view()
	return upgrade_management_view.build_items(item_mode)

func add_item_row(item_data: Dictionary, parent_container: Container = null) -> void:
	if not ensure_view():
		return
	sync_state_to_view()
	upgrade_management_view.add_item_row(item_data, parent_container)
	sync_view_state()

func on_item_hovered(item_data: Dictionary) -> void:
	if not ensure_view():
		return
	sync_state_to_view()
	upgrade_management_view.call("_on_item_hovered", item_data)
	sync_view_state()

func on_item_unhovered(item_data: Dictionary) -> void:
	if not ensure_view():
		return
	sync_state_to_view()
	upgrade_management_view.call("_on_item_unhovered", item_data)
	sync_view_state()

func on_item_selected(item_data: Dictionary) -> void:
	if not ensure_view():
		return
	sync_state_to_view()
	upgrade_management_view.call("_on_item_selected", item_data)
	sync_view_state()

func refresh_detail() -> void:
	if upgrade_management_view == null or not is_instance_valid(upgrade_management_view):
		return
	sync_state_to_view()
	upgrade_management_view.refresh_detail()
	sync_view_state()

func on_action_pressed() -> void:
	if not ensure_view():
		return
	sync_state_to_view()
	upgrade_management_view.trigger_action()
	sync_view_state()

func try_upgrade_selected_item() -> bool:
	if not ensure_view():
		return false
	sync_state_to_view()
	var result := bool(upgrade_management_view.try_upgrade_selected_item())
	sync_view_state()
	return result

func try_upgrade_weapon(item_data: Dictionary) -> bool:
	if not ensure_view():
		return false
	var result := bool(upgrade_management_view.call("_try_upgrade_weapon", item_data))
	sync_view_state()
	return result

func try_upgrade_module(item_data: Dictionary) -> bool:
	if not ensure_view():
		return false
	var result := bool(upgrade_management_view.call("_try_upgrade_module", item_data))
	sync_view_state()
	return result

func refresh_action() -> void:
	if upgrade_management_view != null and is_instance_valid(upgrade_management_view):
		sync_state_to_view()
		upgrade_management_view.refresh_action()
		sync_view_state()

func build_weapon_item_data(weapon: Weapon, location_text: String = "") -> Dictionary:
	if not ensure_view():
		return {}
	return upgrade_management_view.call("_build_weapon_item_data", weapon, location_text)

func build_module_item_data(module_instance: Module, location_text: String = "") -> Dictionary:
	if not ensure_view():
		return {}
	return upgrade_management_view.call("_build_module_item_data", module_instance, location_text)

func build_weapon_param_summary(weapon: Weapon) -> String:
	if not ensure_view():
		return ""
	return str(upgrade_management_view.call("_build_weapon_param_summary", weapon))

func build_module_param_summary(module_instance: Module) -> String:
	if not ensure_view():
		return ""
	return str(upgrade_management_view.call("_build_module_param_summary", module_instance))

func get_weapon_location_text(weapon: Weapon) -> String:
	if not ensure_view():
		return ""
	return str(upgrade_management_view.call("_get_weapon_location_text", weapon))

func get_module_location_text(module_instance: Module) -> String:
	if not ensure_view():
		return ""
	return str(upgrade_management_view.call("_get_module_location_text", module_instance))

func resolve_module_owner_weapon(module_instance: Module) -> Weapon:
	if not ensure_view():
		return null
	return upgrade_management_view.call("_resolve_module_owner_weapon", module_instance) as Weapon

func get_module_texture(module_instance: Module) -> Texture2D:
	if not ensure_view():
		return null
	return upgrade_management_view.call("_get_module_texture", module_instance) as Texture2D

func items_match(a: Dictionary, b: Dictionary) -> bool:
	if not ensure_view():
		return false
	return bool(upgrade_management_view.items_match(a, b))

func fill_weapon_detail(item_data: Dictionary) -> void:
	if ensure_view():
		upgrade_management_view.call("_fill_weapon_detail", item_data)

func fill_module_detail(item_data: Dictionary) -> void:
	if ensure_view():
		upgrade_management_view.call("_fill_module_detail", item_data)

func add_detail_section(title: String, value: String) -> void:
	if ensure_view():
		upgrade_management_view.call("_add_detail_section", title, value)

func add_detail_header(text: String) -> void:
	if ensure_view():
		upgrade_management_view.call("_add_detail_header", text)

func add_detail_text(text: String) -> void:
	if ensure_view():
		upgrade_management_view.call("_add_detail_text", text)

func get_weapon_upgrade_price(weapon: Weapon) -> int:
	if not ensure_view():
		return 0
	return int(upgrade_management_view.call("_get_weapon_upgrade_price", weapon))

func get_module_upgrade_price(module_instance: Module) -> int:
	if not ensure_view():
		return 0
	return int(upgrade_management_view.call("_get_module_upgrade_price", module_instance))

func refresh_texts() -> void:
	var upgrade_panel_title := upgrade_panel.get_node_or_null("Title") as Label
	if upgrade_panel_title:
		upgrade_panel_title.text = LocalizationManager.tr_key("ui.panel.upgrade_combined", "Upgrade Weapons and Modules")
	if upgrade_instruction_label:
		upgrade_instruction_label.text = ""
		upgrade_instruction_label.visible = false
	if upgrade_weapon_mode_button:
		upgrade_weapon_mode_button.text = LocalizationManager.tr_key("ui.upgrade.weapons", "Upgrade Weapons")
	if upgrade_module_mode_button:
		upgrade_module_mode_button.text = LocalizationManager.tr_key("ui.upgrade.modules", "Upgrade Modules")
	var upgrade_back := upgrade_panel.get_node_or_null("BackToUpgradeMenu") as Button
	if upgrade_back:
		upgrade_back.text = LocalizationManager.tr_key("ui.panel.back", "Back")
	var upgrade_title := owner_ui.upgrade_primary_panel.get_node_or_null("Title") as Label
	if upgrade_title:
		upgrade_title.text = LocalizationManager.tr_key("ui.smith.upgrade.title", "Upgrade")
	var upgrade_subtitle := owner_ui.upgrade_primary_panel.get_node_or_null("SubTitle") as Label
	if upgrade_subtitle:
		upgrade_subtitle.text = LocalizationManager.tr_key("ui.smith.upgrade.subtitle", "Choose upgrade category")
	var upgrade_open := owner_ui.upgrade_primary_panel.get_node_or_null("OpenUpgradeButton") as Button
	if upgrade_open:
		upgrade_open.text = LocalizationManager.tr_key("ui.smith.upgrade.weapon", "Weapon")
	if owner_ui.upgrade_module_button:
		owner_ui.upgrade_module_button.text = LocalizationManager.tr_key("ui.smith.upgrade.module", "Module")
	sync_primary_menu_style()
	refresh_action()

func sync_primary_menu_style() -> void:
	if owner_ui != null and owner_ui.has_method("_style_primary_menu_controls"):
		owner_ui.call("_style_primary_menu_controls")

func sync_state_to_view() -> void:
	if upgrade_management_view == null or not is_instance_valid(upgrade_management_view):
		return
	if owner_ui != null:
		mode = owner_ui._upgrade_mode
		hover_item = owner_ui._upgrade_hover_item
		selected_item = owner_ui._upgrade_selected_item
		selected_module = owner_ui.selected_upgrade_module
	upgrade_management_view.set_state(mode, hover_item, selected_item, selected_module)

func sync_view_state() -> void:
	if upgrade_management_view == null or not is_instance_valid(upgrade_management_view):
		return
	mode = upgrade_management_view.get_mode()
	hover_item = upgrade_management_view.get_hover_item()
	selected_item = upgrade_management_view.get_selected_item()
	selected_module = upgrade_management_view.get_selected_module()
	_sync_public_fields_to_owner()

func _bind_view_fields() -> void:
	upgrade_mode_buttons = upgrade_management_view.upgrade_mode_buttons
	upgrade_weapon_mode_button = upgrade_management_view.upgrade_weapon_mode_button
	upgrade_module_mode_button = upgrade_management_view.upgrade_module_mode_button
	upgrade_item_scroll = upgrade_management_view.upgrade_item_scroll
	upgrade_item_list = upgrade_management_view.upgrade_item_list
	upgrade_detail_panel = upgrade_management_view.upgrade_detail_panel
	upgrade_detail_title = upgrade_management_view.upgrade_detail_title
	upgrade_detail_subtitle = upgrade_management_view.upgrade_detail_subtitle
	upgrade_detail_body = upgrade_management_view.upgrade_detail_body
	upgrade_action_button = upgrade_management_view.upgrade_action_button

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui.upgrade_management_view = upgrade_management_view
	owner_ui.upgrade_action_button = upgrade_action_button
	owner_ui.upgrade_mode_buttons = upgrade_mode_buttons
	owner_ui.upgrade_weapon_mode_button = upgrade_weapon_mode_button
	owner_ui.upgrade_module_mode_button = upgrade_module_mode_button
	owner_ui.upgrade_item_scroll = upgrade_item_scroll
	owner_ui.upgrade_item_list = upgrade_item_list
	owner_ui.upgrade_detail_panel = upgrade_detail_panel
	owner_ui.upgrade_detail_title = upgrade_detail_title
	owner_ui.upgrade_detail_subtitle = upgrade_detail_subtitle
	owner_ui.upgrade_detail_body = upgrade_detail_body
	owner_ui._upgrade_mode = mode
	owner_ui._upgrade_hover_item = hover_item
	owner_ui._upgrade_selected_item = selected_item
	owner_ui.selected_upgrade_module = selected_module
