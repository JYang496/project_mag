extends Control
class_name ModuleManagementView

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const WAREHOUSE_DRAG_CONTROLS := preload("res://UI/scripts/management/warehouse_drag_controls.gd")
const MODULE_MANAGEMENT_CARD_FACTORY := preload("res://UI/scripts/management/module_management_card_factory.gd")
const MODULE_MANAGEMENT_DETAIL_PRESENTER := preload("res://UI/scripts/management/module_management_detail_presenter.gd")
const MODULE_MANAGEMENT_DRAG_COORDINATOR := preload("res://UI/scripts/management/module_management_drag_coordinator.gd")
const MODULE_MANAGEMENT_ACTION_PRESENTER := preload("res://UI/scripts/management/module_management_action_presenter.gd")

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
var _card_factory
var _detail_presenter
var _drag_coordinator
var _action_presenter

func _ready() -> void:
	_ensure_card_factory()
	_build_unified_layout()
	_ensure_detail_presenter()
	_ensure_drag_coordinator()
	_ensure_action_presenter()

func _ensure_card_factory() -> void:
	if _card_factory != null:
		return
	_card_factory = MODULE_MANAGEMENT_CARD_FACTORY.new()
	_card_factory.bind(self, owner_ui)

func _ensure_detail_presenter() -> void:
	if _detail_title == null or _detail_subtitle == null or _detail_body == null:
		return
	if _detail_presenter == null:
		_detail_presenter = MODULE_MANAGEMENT_DETAIL_PRESENTER.new()
		_detail_presenter.bind(self, _detail_title, _detail_subtitle, _detail_body)
	else:
		_detail_presenter.set_detail_nodes(_detail_title, _detail_subtitle, _detail_body)

func _ensure_drag_coordinator() -> void:
	if _left_list == null or _status_label == null:
		return
	_ensure_card_factory()
	if _drag_coordinator == null:
		_drag_coordinator = MODULE_MANAGEMENT_DRAG_COORDINATOR.new()
		_drag_coordinator.bind(self, _left_list, _status_label, _card_factory)
	else:
		_drag_coordinator.set_context(_left_list, _status_label, _card_factory)

func _ensure_action_presenter() -> void:
	if _primary_action_button == null or _secondary_action_button == null or _status_label == null:
		return
	if _action_presenter == null:
		_action_presenter = MODULE_MANAGEMENT_ACTION_PRESENTER.new()
		_action_presenter.bind(self, _primary_action_button, _secondary_action_button, _status_label)
	else:
		_action_presenter.set_action_nodes(_primary_action_button, _secondary_action_button, _status_label)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_ensure_drag_coordinator()
		if _drag_coordinator != null:
			_drag_coordinator.handle_drag_end()

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
	_ensure_action_presenter()
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
	_ensure_action_presenter()
	return _action_presenter.perform_primary_action() if _action_presenter != null else false

func perform_secondary_action() -> bool:
	_ensure_action_presenter()
	return _action_presenter.perform_secondary_action() if _action_presenter != null else false

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
	_ensure_detail_presenter()
	_ensure_drag_coordinator()
	_ensure_action_presenter()

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
	_ensure_detail_presenter()
	if active_tab == &"weapon":
		_refresh_weapon_detail()
	else:
		_refresh_module_detail()

func _refresh_weapon_detail() -> void:
	if _detail_presenter != null:
		_detail_presenter.refresh_weapon_detail(selected_equipped_weapon, selected_stored_weapon)

func _refresh_module_detail() -> void:
	if _detail_presenter != null:
		_detail_presenter.refresh_module_detail(selected_module, selected_equipped_module, selected_equipped_module_weapon)

func _refresh_weapon_action() -> void:
	_ensure_action_presenter()
	if _action_presenter != null:
		_action_presenter.refresh_weapon_action()

func _refresh_module_action() -> void:
	_ensure_action_presenter()
	if _action_presenter != null:
		_action_presenter.refresh_module_action()

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
	_ensure_action_presenter()
	return _action_presenter.perform_weapon_action() if _action_presenter != null else false

func _perform_module_unequip() -> bool:
	_ensure_action_presenter()
	return _action_presenter.perform_module_unequip() if _action_presenter != null else false

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
	return _card_factory.make_module_weapon_card(weapon, _get_active_drag_module(), _build_module_socket_callback)

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
	_card_factory.apply_module_weapon_card_style(panel, weapon, _get_active_drag_module())

func _refresh_module_drag_highlights() -> void:
	_ensure_drag_coordinator()
	if _drag_coordinator != null:
		_drag_coordinator.refresh_module_drag_highlights()

func _can_drag_module_install_on_weapon(module_instance: Module, weapon: Weapon) -> bool:
	_ensure_drag_coordinator()
	return _drag_coordinator.can_drag_module_install_on_weapon(module_instance, weapon) if _drag_coordinator != null else false

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
	_ensure_drag_coordinator()
	return _drag_coordinator.build_drag_data(payload, source_control) if _drag_coordinator != null else {}

func can_drop_payload(target: Dictionary, data: Variant) -> bool:
	_ensure_drag_coordinator()
	return _drag_coordinator.can_drop_payload(target, data) if _drag_coordinator != null else false

func drop_payload(target: Dictionary, data: Variant) -> bool:
	_ensure_drag_coordinator()
	return _drag_coordinator.drop_payload(target, data) if _drag_coordinator != null else false

func _get_drop_feedback(target: Dictionary, data: Variant) -> Dictionary:
	_ensure_drag_coordinator()
	return _drag_coordinator.get_drop_feedback(target, data) if _drag_coordinator != null else {"ok": false, "reason": ""}

func _perform_drop_action(target: Dictionary, payload: Dictionary) -> Dictionary:
	_ensure_drag_coordinator()
	return _drag_coordinator.perform_drop_action(target, payload) if _drag_coordinator != null else {"ok": false, "reason": ""}

func _clear_drag_selection(payload: Dictionary) -> void:
	_ensure_drag_coordinator()
	if _drag_coordinator != null:
		_drag_coordinator.clear_drag_selection(payload)

func _build_drag_preview(payload: Dictionary) -> Control:
	_ensure_drag_coordinator()
	return _drag_coordinator.build_drag_preview(payload) if _drag_coordinator != null else null

func _get_active_drag_module() -> Module:
	_ensure_drag_coordinator()
	return _drag_coordinator.active_drag_module if _drag_coordinator != null else null

func _sync_legacy_fields() -> void:
	temporary_modules_scroll = get_node_or_null("Columns/RightColumn/Margin/Root/RightListScroll") as ScrollContainer
	modules = GridContainer.new()
	equipped_m = GridContainer.new()
	module_selection_label = _status_label
	module_equip_button = _primary_action_button
	module_sell_button = _secondary_action_button

func _get_module_texture(module_instance: Module) -> Texture2D:
	_ensure_detail_presenter()
	return _detail_presenter.get_module_texture(module_instance) if _detail_presenter != null else null

func _get_weapon_rarity(weapon: Weapon) -> String:
	_ensure_detail_presenter()
	return _detail_presenter.get_weapon_rarity(weapon) if _detail_presenter != null else RARITY_UTIL.COMMON

func _get_weapon_rarity_color(weapon: Weapon) -> Color:
	_ensure_detail_presenter()
	return _detail_presenter.get_weapon_rarity_color(weapon) if _detail_presenter != null else Color.WHITE

func _build_weapon_param_summary(weapon: Weapon) -> String:
	_ensure_detail_presenter()
	return _detail_presenter.build_weapon_param_summary(weapon) if _detail_presenter != null else ""

func _format_module_install_targets(module_instance: Module) -> String:
	_ensure_detail_presenter()
	return _detail_presenter.format_module_install_targets(module_instance) if _detail_presenter != null else ""

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
