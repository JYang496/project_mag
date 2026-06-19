extends Control
class_name ModuleManagementView

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const WAREHOUSE_DRAG_CONTROLS := preload("res://UI/scripts/management/warehouse_drag_controls.gd")
const MODULE_MANAGEMENT_CARD_FACTORY := preload("res://UI/scripts/management/module_management_card_factory.gd")

@onready var temporary_modules_scroll: ScrollContainer = get_node_or_null("TemporaryModulesScroll")
@onready var modules: GridContainer = get_node_or_null("TemporaryModulesScroll/Modules")
@onready var equipped_m: GridContainer = get_node_or_null("EquippedM")
@onready var module_selection_label: Label = get_node_or_null("ModuleSelectionLabel")
@onready var module_equip_button: Button = get_node_or_null("ModuleEquipButton")
@onready var module_sell_button: Button = get_node_or_null("ModuleSellButton")

var owner_ui: Node
var controller: ModuleWarehouseController
var selected_module: Module

var active_tab: StringName = &"weapon"
var selected_equipped_weapon: Weapon
var selected_stored_weapon: Weapon
var selected_equipped_module: Module
var selected_equipped_module_weapon: Weapon

var _built := false
var _tab_weapon_button: Button
var _tab_module_button: Button
var _left_title: Label
var _right_title: Label
var _left_list: VBoxContainer
var _right_list: VBoxContainer
var _detail_title: Label
var _detail_subtitle: Label
var _detail_body: VBoxContainer
var _primary_action_button: Button
var _secondary_action_button: Button
var _back_action_button: Button
var _status_label: Label
var _tabs: HBoxContainer
var _action_bar: HBoxContainer
var _active_drag_module: Module
var _card_factory

func _ready() -> void:
	_ensure_card_factory()
	_build_unified_layout()

func _ensure_card_factory() -> void:
	if _card_factory != null:
		return
	_card_factory = MODULE_MANAGEMENT_CARD_FACTORY.new()
	_card_factory.bind(self, owner_ui)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _active_drag_module != null:
		_active_drag_module = null
		_refresh_module_drag_highlights()

func bind(owner_ui: Node, module_controller: ModuleWarehouseController = null) -> void:
	if owner_ui == null:
		return
	self.owner_ui = owner_ui
	controller = module_controller
	_ensure_card_factory()
	_build_unified_layout()
	if _primary_action_button and controller != null:
		var action_pressed := Callable(controller, "on_primary_action_pressed")
		if not _primary_action_button.pressed.is_connected(action_pressed):
			_primary_action_button.pressed.connect(action_pressed)
	if _secondary_action_button and controller != null:
		var secondary_pressed := Callable(controller, "on_secondary_action_pressed")
		if not _secondary_action_button.pressed.is_connected(secondary_pressed):
			_secondary_action_button.pressed.connect(secondary_pressed)
	_style_static_controls()

func set_selected_module(module_instance: Module) -> void:
	selected_module = module_instance
	_sync_owner_selection()

func get_selected_module() -> Module:
	return selected_module

func select_module(module_instance: Module, _module_slots: Node = null) -> void:
	active_tab = &"module"
	selected_module = module_instance
	selected_equipped_module = null
	selected_equipped_module_weapon = null
	refresh_all()

func apply_slot_selection(_module_slots: Node) -> void:
	pass

func clear_if_missing() -> void:
	if selected_module != null and not InventoryData.temporary_modules.has(selected_module):
		selected_module = null
	if selected_equipped_weapon != null and not PlayerData.player_weapon_list.has(selected_equipped_weapon):
		selected_equipped_weapon = null
	if selected_stored_weapon != null and not InventoryData.weapon_storage.has(selected_stored_weapon):
		selected_stored_weapon = null
	if selected_equipped_module != null and not is_instance_valid(selected_equipped_module):
		selected_equipped_module = null
		selected_equipped_module_weapon = null
	_sync_owner_selection()

func trigger_equip() -> bool:
	return false

func trigger_sell() -> bool:
	if selected_module == null or not is_instance_valid(selected_module):
		return false
	if owner_ui and owner_ui.has_method("request_temporary_module_sell_confirmation"):
		owner_ui.call("request_temporary_module_sell_confirmation", selected_module)
		return true
	return false

func apply_tab(tab: StringName) -> void:
	active_tab = &"module" if tab == &"module" else &"weapon"
	refresh_all()

func refresh_all() -> void:
	_build_unified_layout()
	clear_if_missing()
	_refresh_tab_buttons()
	_refresh_columns()
	refresh_detail()
	refresh_action()
	_sync_owner_selection()

func refresh_action() -> void:
	if _primary_action_button == null or _secondary_action_button == null or _back_action_button == null or _status_label == null:
		return
	_primary_action_button.visible = true
	_secondary_action_button.visible = active_tab == &"module"
	_back_action_button.visible = true
	_back_action_button.text = LocalizationManager.tr_key("ui.panel.back", "Back")
	_primary_action_button.disabled = true
	_secondary_action_button.disabled = true
	_status_label.text = ""
	if active_tab == &"weapon":
		_refresh_weapon_action()
	else:
		_refresh_module_action()

func perform_primary_action() -> bool:
	if active_tab == &"weapon":
		return _perform_weapon_action()
	if selected_equipped_module != null and selected_equipped_module_weapon != null:
		return _perform_module_unequip()
	return false

func perform_secondary_action() -> bool:
	if active_tab != &"module":
		return false
	return trigger_sell()

func _build_unified_layout() -> void:
	if _built:
		return
	_built = true
	for child in get_children():
		remove_child(child)
		child.queue_free()
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_tabs = HBoxContainer.new()
	_tabs.name = "WarehouseTabs"
	_tabs.visible = false
	_tabs.position = Vector2(25, 40)
	_tabs.size = Vector2(360, 46)
	_tabs.add_theme_constant_override("separation", 10)
	add_child(_tabs)

	_tab_weapon_button = Button.new()
	_tab_weapon_button.name = "WeaponWarehouseTab"
	_tab_weapon_button.toggle_mode = true
	_tab_weapon_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.title", "Weapon Warehouse")
	_tab_weapon_button.custom_minimum_size = Vector2(170, 44)
	_tab_weapon_button.pressed.connect(_on_weapon_tab_pressed)
	_tabs.add_child(_tab_weapon_button)

	_tab_module_button = Button.new()
	_tab_module_button.name = "ModuleWarehouseTab"
	_tab_module_button.toggle_mode = true
	_tab_module_button.text = LocalizationManager.tr_key("ui.module.warehouse.title", "Module Warehouse")
	_tab_module_button.custom_minimum_size = Vector2(170, 44)
	_tab_module_button.pressed.connect(_on_module_tab_pressed)
	_tabs.add_child(_tab_module_button)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.position = Vector2(25, 78)
	columns.size = Vector2(950, 428)
	columns.add_theme_constant_override("separation", 14)
	add_child(columns)

	var left_panel := _make_panel_column(columns, "LeftColumn", Vector2(300, 410))
	_left_title = _make_column_title(left_panel)
	_left_list = _make_scroll_list(left_panel, "LeftListScroll", "LeftList")

	var detail_panel := _make_panel_column(columns, "DetailColumn", Vector2(300, 410))
	_detail_title = _make_column_title(detail_panel)
	_detail_subtitle = Label.new()
	_detail_subtitle.name = "DetailSubtitle"
	_detail_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_subtitle.add_theme_font_size_override("font_size", 13)
	_detail_subtitle.add_theme_color_override("font_color", Color(0.74, 0.84, 0.9))
	detail_panel.add_child(_detail_subtitle)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(detail_scroll)
	_detail_body = VBoxContainer.new()
	_detail_body.name = "DetailBody"
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(_detail_body)

	var right_panel := _make_panel_column(columns, "RightColumn", Vector2(300, 410))
	_right_title = _make_column_title(right_panel)
	_right_list = _make_scroll_list(right_panel, "RightListScroll", "RightList")

	_action_bar = HBoxContainer.new()
	_action_bar.name = "ActionBar"
	_action_bar.position = Vector2(25, 512)
	_action_bar.size = Vector2(950, 62)
	_action_bar.add_theme_constant_override("separation", 12)
	add_child(_action_bar)

	_status_label = Label.new()
	_status_label.name = "WarehouseStatus"
	_status_label.custom_minimum_size = Vector2(320, 52)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.9))
	_action_bar.add_child(_status_label)

	_primary_action_button = Button.new()
	_primary_action_button.name = "PrimaryAction"
	_primary_action_button.custom_minimum_size = Vector2(184, 52)
	_action_bar.add_child(_primary_action_button)

	_secondary_action_button = Button.new()
	_secondary_action_button.name = "SecondaryAction"
	_secondary_action_button.custom_minimum_size = Vector2(184, 52)
	_action_bar.add_child(_secondary_action_button)

	_back_action_button = Button.new()
	_back_action_button.name = "BackAction"
	_back_action_button.custom_minimum_size = Vector2(150, 52)
	_back_action_button.text = LocalizationManager.tr_key("ui.panel.back", "Back")
	_back_action_button.pressed.connect(_on_back_action_pressed)
	_action_bar.add_child(_back_action_button)

	_sync_legacy_fields()

func _make_panel_column(parent: Container, node_name: String, min_size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.095, 0.125, 0.94)
	style.border_color = Color(0.22, 0.36, 0.46)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)
	return root

func _make_column_title(parent: VBoxContainer) -> Label:
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	title.clip_text = true
	parent.add_child(title)
	return title

func _make_scroll_list(parent: VBoxContainer, scroll_name: String, list_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = scroll_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var list := WAREHOUSE_DRAG_CONTROLS.WarehouseDropList.new()
	list.name = list_name
	list.view = self
	list.mouse_filter = Control.MOUSE_FILTER_STOP
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list

func _style_static_controls() -> void:
	if owner_ui == null:
		return
	owner_ui.call("_style_management_button", _tab_weapon_button, active_tab == &"weapon")
	owner_ui.call("_style_management_button", _tab_module_button, active_tab == &"module")
	owner_ui.call("_style_management_button", _primary_action_button, true)
	owner_ui.call("_style_management_button", _secondary_action_button)
	owner_ui.call("_style_management_button", _back_action_button)

func _refresh_tab_buttons() -> void:
	_tab_weapon_button.button_pressed = active_tab == &"weapon"
	_tab_module_button.button_pressed = active_tab == &"module"
	_style_static_controls()

func _refresh_columns() -> void:
	_clear_container(_left_list)
	_clear_container(_right_list)
	_set_list_drop_payload(_left_list, {})
	_set_list_drop_payload(_right_list, {})
	if active_tab == &"weapon":
		_refresh_weapon_columns()
	else:
		_refresh_module_columns()

func _refresh_weapon_columns() -> void:
	_left_title.text = LocalizationManager.tr_key("ui.weapon.warehouse.equipped", "Equipped Weapons")
	_right_title.text = LocalizationManager.tr_key("ui.weapon.warehouse.stored", "Stored Weapons")
	_set_list_drop_payload(_right_list, {"kind": "weapon_storage_area"})
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon:
			_left_list.add_child(_make_weapon_button(weapon, "equipped", weapon == selected_equipped_weapon))
	for slot_index in range(PlayerData.player_weapon_list.size(), int(PlayerData.max_weapon_num)):
		_left_list.add_child(_make_empty_weapon_slot_button(slot_index))
	var stored := InventoryData.get_stored_weapons()
	if stored.is_empty():
		_add_empty_label(_right_list, LocalizationManager.tr_key("ui.weapon.warehouse.empty", "Warehouse is empty."))
	for weapon in stored:
		_right_list.add_child(_make_weapon_button(weapon, "stored", weapon == selected_stored_weapon))

func _refresh_module_columns() -> void:
	_left_title.text = LocalizationManager.tr_key("ui.module.targets", "Weapons and Module Slots")
	_right_title.text = LocalizationManager.tr_key("ui.module.temporary_modules", "Temporary Modules")
	_set_list_drop_payload(_right_list, {"kind": "temporary_module_area"})
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon:
			_left_list.add_child(_make_module_weapon_card(weapon))
	var count := InventoryData.temporary_modules.size()
	if count == 0:
		_add_empty_label(_right_list, LocalizationManager.tr_key("ui.module.empty_storage", "No temporary modules."))
	for module_ref in InventoryData.temporary_modules:
		var module_instance := module_ref as Module
		if module_instance:
			_right_list.add_child(_make_module_button(module_instance, module_instance == selected_module))

func refresh_detail() -> void:
	_clear_container(_detail_body)
	if active_tab == &"weapon":
		_refresh_weapon_detail()
	else:
		_refresh_module_detail()

func _refresh_weapon_detail() -> void:
	var active_weapon := selected_stored_weapon if selected_stored_weapon != null else selected_equipped_weapon
	if active_weapon == null or not is_instance_valid(active_weapon):
		_detail_title.text = LocalizationManager.tr_key("ui.warehouse.detail.empty", "Select an item")
		_detail_subtitle.text = LocalizationManager.tr_key("ui.weapon.warehouse.select_hint", "Select a held weapon to store, or a stored weapon to equip or exchange.")
		return
	_detail_title.text = LocalizationManager.get_weapon_name_from_node(active_weapon)
	_detail_title.add_theme_color_override("font_color", _get_weapon_rarity_color(active_weapon))
	_detail_subtitle.text = _get_weapon_location(active_weapon)
	_add_detail_line("Level", "Lv.%d/%d" % [int(active_weapon.level), int(active_weapon.max_level)])
	_add_detail_line("Fuse", str(int(active_weapon.fuse)))
	_add_detail_line("Modules", LocalizationManager.tr_key("ui.weapon.warehouse.modules_removed", "Stored weapons do not keep modules."))
	_add_detail_text(_build_weapon_param_summary(active_weapon))

func _refresh_module_detail() -> void:
	var active_module := selected_module if selected_module != null else selected_equipped_module
	if active_module == null or not is_instance_valid(active_module):
		_detail_title.text = LocalizationManager.tr_key("ui.warehouse.detail.empty", "Select an item")
		_detail_subtitle.text = LocalizationManager.tr_key("ui.module.select_prompt", "Select a temporary module, then click a compatible weapon slot.")
		return
	_detail_title.text = LocalizationManager.get_module_name(active_module)
	_detail_title.add_theme_color_override("font_color", RARITY_UTIL.get_color(active_module.get_rarity()))
	_detail_subtitle.text = _get_module_location(active_module)
	_add_detail_line("Level", "Lv.%d/%d" % [int(active_module.module_level), Module.MAX_LEVEL])
	_add_detail_line("Rarity", RARITY_UTIL.get_display_name(active_module.get_rarity()))
	_add_detail_line("Install Targets", _format_module_install_targets(active_module))
	for description in active_module.get_effect_descriptions():
		_add_detail_text(str(description))

func _refresh_weapon_action() -> void:
	_secondary_action_button.visible = false
	if selected_stored_weapon != null and is_instance_valid(selected_stored_weapon):
		if PlayerData.player_weapon_list.size() < PlayerData.max_weapon_num:
			_primary_action_button.disabled = false
			_primary_action_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.equip_empty", "Equip to Empty Slot")
			return
		_primary_action_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.exchange_selected", "Exchange with Selected")
		if selected_equipped_weapon != null and is_instance_valid(selected_equipped_weapon):
			_primary_action_button.disabled = false
			_status_label.text = LocalizationManager.tr_format(
				"ui.weapon.warehouse.exchange_preview",
				{"stored": LocalizationManager.get_weapon_name_from_node(selected_stored_weapon), "equipped": LocalizationManager.get_weapon_name_from_node(selected_equipped_weapon)},
				"Exchange stored weapon with selected held weapon."
			)
		else:
			_status_label.text = LocalizationManager.tr_key("ui.weapon.warehouse.select_exchange_target", "Select a held weapon on the left to exchange.")
		return
	if selected_equipped_weapon != null and is_instance_valid(selected_equipped_weapon):
		_primary_action_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.store", "Store in Warehouse")
		_primary_action_button.disabled = PlayerData.player_weapon_list.size() <= 1
		if _primary_action_button.disabled:
			_status_label.text = LocalizationManager.tr_key("ui.weapon.warehouse.keep_one", "At least one weapon must remain equipped.")
		return
	_primary_action_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.action", "Manage Weapon")

func _refresh_module_action() -> void:
	_primary_action_button.text = LocalizationManager.tr_key("ui.module.action.unequip", "Unequip Module")
	_primary_action_button.disabled = selected_equipped_module == null or selected_equipped_module_weapon == null
	_secondary_action_button.text = LocalizationManager.tr_key("ui.module.action.sell_selected", "Sell Selected Module")
	_secondary_action_button.disabled = selected_module == null or not is_instance_valid(selected_module)
	if selected_module != null and is_instance_valid(selected_module):
		_status_label.text = LocalizationManager.tr_key("ui.module.slot_click_hint", "Click a highlighted slot on the left to install or replace.")
	elif selected_equipped_module != null and is_instance_valid(selected_equipped_module):
		_status_label.text = LocalizationManager.tr_key("ui.module.unequip_hint", "Use Unequip Module to move it back to temporary storage.")
	else:
		_status_label.text = LocalizationManager.tr_key("ui.module.select_prompt", "Select a temporary module to manage.")

func _on_back_action_pressed() -> void:
	if controller != null and controller.owner_ui != null and controller.owner_ui.rest_area_ui_controller != null:
		controller.owner_ui.rest_area_ui_controller.back_to_warehouse_primary_menu()
		return
	if owner_ui == null:
		return
	var rest_controller: Variant = owner_ui.get("rest_area_ui_controller")
	if rest_controller != null:
		rest_controller.back_to_warehouse_primary_menu()

func _perform_weapon_action() -> bool:
	if selected_stored_weapon != null and is_instance_valid(selected_stored_weapon):
		var result: Dictionary
		if PlayerData.player_weapon_list.size() < PlayerData.max_weapon_num:
			result = InventoryData.equip_stored_weapon(selected_stored_weapon)
		elif selected_equipped_weapon != null and is_instance_valid(selected_equipped_weapon):
			result = InventoryData.exchange_stored_weapon(selected_stored_weapon, selected_equipped_weapon)
		else:
			return false
		if not result.get("ok", false):
			_show_message(str(result.get("reason", "")), 1.6)
			return false
		selected_stored_weapon = null
		selected_equipped_weapon = null
		refresh_all()
		return true
	if selected_equipped_weapon != null and is_instance_valid(selected_equipped_weapon):
		var store_result := InventoryData.store_weapon(selected_equipped_weapon)
		if not store_result.get("ok", false):
			_show_message(str(store_result.get("reason", "")), 1.6)
			return false
		selected_equipped_weapon = null
		refresh_all()
		return true
	return false

func _perform_module_unequip() -> bool:
	var result := InventoryData.unequip_module_from_weapon(selected_equipped_module, selected_equipped_module_weapon)
	if not result.get("ok", false):
		_show_message(str(result.get("reason", "")), 1.6)
		return false
	selected_equipped_module = null
	selected_equipped_module_weapon = null
	refresh_all()
	return true

func _make_weapon_button(weapon: Weapon, location: String, selected: bool) -> Button:
	_ensure_card_factory()
	return _card_factory.make_weapon_button(weapon, location, selected, _on_weapon_pressed.bind(weapon, location))

func _make_empty_weapon_slot_button(slot_index: int) -> Button:
	_ensure_card_factory()
	return _card_factory.make_empty_weapon_slot_button(slot_index)

func _make_module_button(module_instance: Module, selected: bool) -> Button:
	_ensure_card_factory()
	return _card_factory.make_module_button(module_instance, selected, _on_temporary_module_pressed.bind(module_instance))

func _make_module_weapon_card(weapon: Weapon) -> PanelContainer:
	_ensure_card_factory()
	return _card_factory.make_module_weapon_card(weapon, _active_drag_module, _build_module_socket_callback)

func _make_module_socket_button(weapon: Weapon, existing: Module, index: int) -> Button:
	_ensure_card_factory()
	return _card_factory.make_module_socket_button(weapon, existing, index, _on_module_socket_pressed.bind(weapon, existing))

func _get_slot_feedback(weapon: Weapon, existing: Module) -> Dictionary:
	if selected_module == null or not is_instance_valid(selected_module):
		if existing != null and is_instance_valid(existing):
			return {"ok": true, "reason": ""}
		return {"ok": false, "reason": LocalizationManager.tr_key("ui.module.select_first", "Select a temporary module first.")}
	return InventoryData.get_weapon_module_assignment_feedback(selected_module, weapon, existing, false)

func _apply_module_weapon_card_style(panel: PanelContainer, weapon: Weapon) -> void:
	_ensure_card_factory()
	_card_factory.apply_module_weapon_card_style(panel, weapon, _active_drag_module)

func _refresh_module_drag_highlights() -> void:
	if _left_list == null or active_tab != &"module":
		return
	for child in _left_list.get_children():
		var panel := child as PanelContainer
		if panel == null or panel.name != "ModuleWeaponCard":
			continue
		var weapon := panel.get_meta("weapon", null) as Weapon
		if weapon != null and is_instance_valid(weapon):
			_apply_module_weapon_card_style(panel, weapon)

func _can_drag_module_install_on_weapon(module_instance: Module, weapon: Weapon) -> bool:
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	if weapon == null or not is_instance_valid(weapon):
		return false
	if weapon.modules == null:
		return false
	var installed: Array[Module] = []
	for child in weapon.modules.get_children():
		var existing := child as Module
		if existing != null and is_instance_valid(existing):
			installed.append(existing)
	for existing in installed:
		var replace_feedback := InventoryData.get_weapon_module_assignment_feedback(module_instance, weapon, existing, false)
		if bool(replace_feedback.get("ok", false)):
			return true
	if installed.size() < int(weapon.MAX_MODULE_NUMBER):
		var empty_feedback := InventoryData.get_weapon_module_assignment_feedback(module_instance, weapon, null, false)
		return bool(empty_feedback.get("ok", false))
	return false

func _on_weapon_pressed(weapon: Weapon, location: String) -> void:
	if location == "stored":
		selected_stored_weapon = weapon
	else:
		selected_equipped_weapon = weapon
	refresh_all()

func _on_temporary_module_pressed(module_instance: Module) -> void:
	selected_module = module_instance
	selected_equipped_module = null
	selected_equipped_module_weapon = null
	_sync_owner_selection()
	refresh_all()

func _on_module_socket_pressed(weapon: Weapon, existing: Module) -> void:
	if selected_module != null and is_instance_valid(selected_module):
		var result := InventoryData.equip_module_to_weapon(selected_module, weapon, existing, false)
		if not result.get("ok", false):
			_show_message(str(result.get("reason", "")), 1.6)
			return
		selected_module = null
		selected_equipped_module = null
		selected_equipped_module_weapon = null
		_sync_owner_selection()
		refresh_all()
		return
	if existing != null and is_instance_valid(existing):
		selected_equipped_module = existing
		selected_equipped_module_weapon = weapon
		_sync_owner_selection()
		refresh_all()

func _build_module_socket_callback(weapon: Weapon, existing: Module) -> Callable:
	return _on_module_socket_pressed.bind(weapon, existing)

func _on_weapon_tab_pressed() -> void:
	active_tab = &"weapon"
	refresh_all()

func _on_module_tab_pressed() -> void:
	active_tab = &"module"
	refresh_all()

func build_drag_data(payload: Dictionary, source_control: Control = null) -> Dictionary:
	if payload.is_empty():
		return {}
	if str(payload.get("kind", "")) == "temporary_module":
		_active_drag_module = payload.get("module", null) as Module
		_refresh_module_drag_highlights()
	var preview := _build_drag_preview(payload)
	if source_control != null and preview != null:
		source_control.set_drag_preview(preview)
	return {"warehouse_drag": true, "payload": payload}

func can_drop_payload(target: Dictionary, data: Variant) -> bool:
	var result := _get_drop_feedback(target, data)
	if _status_label != null:
		_status_label.text = str(result.get("reason", ""))
	return bool(result.get("ok", false))

func drop_payload(target: Dictionary, data: Variant) -> bool:
	var result := _get_drop_feedback(target, data)
	if not bool(result.get("ok", false)):
		if _status_label != null:
			_status_label.text = str(result.get("reason", ""))
		return false
	var payload: Dictionary = data.get("payload", {})
	var action_result := _perform_drop_action(target, payload)
	if not bool(action_result.get("ok", false)):
		if _status_label != null:
			_status_label.text = str(action_result.get("reason", ""))
		return false
	_clear_drag_selection(payload)
	_active_drag_module = null
	refresh_all()
	return true

func _get_drop_feedback(target: Dictionary, data: Variant) -> Dictionary:
	if not (data is Dictionary) or not bool(data.get("warehouse_drag", false)):
		return {"ok": false, "reason": ""}
	var payload: Dictionary = data.get("payload", {})
	var source_kind := str(payload.get("kind", ""))
	var target_kind := str(target.get("kind", ""))
	match target_kind:
		"weapon_storage_area":
			if source_kind != "equipped_weapon":
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.warehouse.drag.invalid_target", "Drop this item on a compatible warehouse target.")}
			var equipped_weapon := payload.get("weapon", null) as Weapon
			if equipped_weapon == null or not PlayerData.player_weapon_list.has(equipped_weapon):
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.invalid_equipped", "Invalid held weapon.")}
			if PlayerData.player_weapon_list.size() <= 1:
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.keep_one", "At least one weapon must remain equipped.")}
			return {"ok": true, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.drop_store", "Release to store this weapon.")}
		"held_empty_slot":
			if source_kind != "stored_weapon":
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.drop_stored_only", "Only stored weapons can be equipped into an empty slot.")}
			var stored_weapon := payload.get("weapon", null) as Weapon
			if stored_weapon == null or not InventoryData.weapon_storage.has(stored_weapon):
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.invalid_stored", "Invalid stored weapon.")}
			if PlayerData.player_weapon_list.size() >= int(PlayerData.max_weapon_num):
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.no_empty_slot", "No weapon slots available.")}
			return {"ok": true, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.drop_equip", "Release to equip this weapon.")}
		"equipped_weapon":
			if source_kind != "stored_weapon":
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.drop_stored_exchange", "Drop a stored weapon on a held weapon to exchange.")}
			var exchange_stored := payload.get("weapon", null) as Weapon
			var exchange_equipped := target.get("weapon", null) as Weapon
			if exchange_stored == null or exchange_equipped == null:
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.invalid_exchange", "Invalid weapon exchange.")}
			if not InventoryData.weapon_storage.has(exchange_stored) or not PlayerData.player_weapon_list.has(exchange_equipped):
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.invalid_exchange", "Invalid weapon exchange.")}
			return {"ok": true, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.drop_exchange", "Release to exchange these weapons.")}
		"module_slot":
			if source_kind != "temporary_module":
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.module.drag.drop_temp_only", "Drop a temporary module on a weapon slot to install it.")}
			var module_instance := payload.get("module", null) as Module
			var weapon := target.get("weapon", null) as Weapon
			var existing := target.get("existing", null) as Module
			return InventoryData.get_weapon_module_assignment_feedback(module_instance, weapon, existing, false)
		"temporary_module_area":
			if source_kind != "equipped_module":
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.module.drag.drop_equipped_only", "Drop an installed module here to unequip it.")}
			var equipped_module := payload.get("module", null) as Module
			var owner_weapon := payload.get("weapon", null) as Weapon
			if equipped_module == null or owner_weapon == null:
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.module.drag.invalid_module", "Invalid module.")}
			if owner_weapon.modules == null or equipped_module.get_parent() != owner_weapon.modules:
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.module.drag.not_equipped", "Module is not equipped.")}
			return {"ok": true, "reason": LocalizationManager.tr_key("ui.module.drag.drop_unequip", "Release to unequip this module.")}
	return {"ok": false, "reason": LocalizationManager.tr_key("ui.warehouse.drag.invalid_target", "Drop this item on a compatible warehouse target.")}

func _perform_drop_action(target: Dictionary, payload: Dictionary) -> Dictionary:
	match str(target.get("kind", "")):
		"weapon_storage_area":
			return InventoryData.store_weapon(payload.get("weapon", null) as Weapon)
		"held_empty_slot":
			return InventoryData.equip_stored_weapon(payload.get("weapon", null) as Weapon)
		"equipped_weapon":
			return InventoryData.exchange_stored_weapon(payload.get("weapon", null) as Weapon, target.get("weapon", null) as Weapon)
		"module_slot":
			return InventoryData.equip_module_to_weapon(payload.get("module", null) as Module, target.get("weapon", null) as Weapon, target.get("existing", null) as Module, false)
		"temporary_module_area":
			return InventoryData.unequip_module_from_weapon(payload.get("module", null) as Module, payload.get("weapon", null) as Weapon)
	return {"ok": false, "reason": LocalizationManager.tr_key("ui.warehouse.drag.invalid_target", "Drop this item on a compatible warehouse target.")}

func _clear_drag_selection(payload: Dictionary) -> void:
	match str(payload.get("kind", "")):
		"stored_weapon", "equipped_weapon":
			selected_stored_weapon = null
			selected_equipped_weapon = null
		"temporary_module", "equipped_module":
			selected_module = null
			selected_equipped_module = null
			selected_equipped_module_weapon = null
			_sync_owner_selection()

func _build_drag_preview(payload: Dictionary) -> Control:
	_ensure_card_factory()
	return _card_factory.build_drag_preview(payload)

func _sync_legacy_fields() -> void:
	temporary_modules_scroll = get_node_or_null("Columns/RightColumn/Margin/Root/RightListScroll") as ScrollContainer
	modules = GridContainer.new()
	equipped_m = GridContainer.new()
	module_selection_label = _status_label
	module_equip_button = _primary_action_button
	module_sell_button = _secondary_action_button

func _get_weapon_location(weapon: Weapon) -> String:
	if PlayerData.player_weapon_list.has(weapon):
		return LocalizationManager.tr_key("ui.weapon.location.equipped", "Held weapon")
	return LocalizationManager.tr_key("ui.weapon.location.stored", "Stored weapon")

func _get_module_location(module_instance: Module) -> String:
	if InventoryData.temporary_modules.has(module_instance):
		return LocalizationManager.tr_key("ui.module.location.temporary", "Temporary module")
	if selected_equipped_module_weapon:
		return LocalizationManager.tr_format(
			"ui.module.location.weapon",
			{"weapon": LocalizationManager.get_weapon_name_from_node(selected_equipped_module_weapon)},
			"Installed on weapon"
		)
	return ""

func _get_module_texture(module_instance: Module) -> Texture2D:
	if module_instance == null or not is_instance_valid(module_instance):
		return null
	var sprite_node := module_instance.get_node_or_null("%Sprite")
	if sprite_node and sprite_node is Sprite2D:
		return (sprite_node as Sprite2D).texture
	if module_instance.get("sprite") is Sprite2D:
		return (module_instance.get("sprite") as Sprite2D).texture
	return null

func _get_weapon_rarity(weapon: Weapon) -> String:
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	return weapon_def.get_rarity() if weapon_def else RARITY_UTIL.COMMON

func _get_weapon_rarity_color(weapon: Weapon) -> Color:
	return RARITY_UTIL.get_color(_get_weapon_rarity(weapon))

func _build_weapon_param_summary(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return ""
	var weapon_data_variant: Variant = weapon.get("weapon_data")
	if not (weapon_data_variant is Dictionary):
		return ""
	var current_data := weapon.get_weapon_level_data(weapon.level, weapon_data_variant as Dictionary)
	var keys := ["damage", "fire_interval_sec", "ammo", "speed", "projectile_hits", "bullet_count"]
	var parts := PackedStringArray()
	for key in keys:
		if current_data.has(key):
			parts.append("%s: %s" % [key, str(current_data[key])])
	return "  ".join(parts)

func _format_module_install_targets(module_instance: Module) -> String:
	if module_instance == null or not is_instance_valid(module_instance):
		return ""
	var parts := PackedStringArray()
	for value in module_instance.get_normalized_required_weapon_traits():
		parts.append(str(value))
	for value in module_instance.get_normalized_required_delivery_types():
		parts.append(str(value))
	for value in module_instance.get_normalized_required_weapon_capabilities():
		parts.append(str(value))
	if parts.is_empty():
		return LocalizationManager.tr_key("ui.shop.module.any_weapon", "Any weapon")
	return " / ".join(parts)

func _add_detail_line(label: String, value: String) -> void:
	_add_detail_text("%s: %s" % [label, value])

func _add_detail_text(text: String) -> void:
	if text == "":
		return
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.9))
	_detail_body.add_child(label)

func _add_empty_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.72, 0.81, 0.86))
	parent.add_child(label)

func _set_list_drop_payload(list: VBoxContainer, payload: Dictionary) -> void:
	if list != null:
		list.set("drop_payload", payload)

func _clear_container(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		child.queue_free()

func _show_message(message: String, duration: float = 1.4) -> void:
	if owner_ui and owner_ui.has_method("show_item_message"):
		owner_ui.call("show_item_message", message, duration)

func _sync_owner_selection() -> void:
	if owner_ui != null:
		owner_ui.selected_temporary_module = selected_module
