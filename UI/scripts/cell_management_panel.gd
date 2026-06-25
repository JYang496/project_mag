extends Control
class_name CellManagementPanel

signal close_requested
signal board_management_requested

const PANEL_BG := Color(0.045, 0.065, 0.09, 0.98)
const PANEL_BORDER := Color(0.18, 0.38, 0.52, 1.0)
const MANAGEMENT_PANEL_SIZE := Vector2(1000, 600)
const PRIMARY_MENU_SCRIPT := preload("res://UI/scripts/management/reusable_primary_menu.gd")

var owner_ui: UI
var _board: BoardCellGenerator
var _mode: StringName = &"home"
var _selected_inventory_index: int = -1
var _root_panel: PanelContainer
var _primary_menu: Control
var _title_label: Label
var _subtitle_label: Label
var _content: VBoxContainer
var _footer: HBoxContainer

func _ready() -> void:
	visible = false
	_build_layout()
	if not CellTaskModuleRuntime.inventory_changed.is_connected(_refresh):
		CellTaskModuleRuntime.inventory_changed.connect(_refresh)
	if not CellTaskModuleRuntime.deployment_changed.is_connected(_refresh):
		CellTaskModuleRuntime.deployment_changed.connect(_refresh)
	if not CellTaskModuleRuntime.active_tasks_changed.is_connected(_refresh):
		CellTaskModuleRuntime.active_tasks_changed.connect(_refresh)

func bind(ui: UI) -> void:
	owner_ui = ui

func open_panel(board: BoardCellGenerator, mode: StringName = &"task") -> bool:
	_board = board
	if _board == null and owner_ui != null:
		_board = owner_ui.call("_find_board") as BoardCellGenerator
	if _board == null:
		return false
	_mode = &"task" if mode != &"home" else &"home"
	_selected_inventory_index = -1
	visible = true
	_refresh()
	return true

func close_panel() -> void:
	visible = false
	_selected_inventory_index = -1

func clear_selection_if_any() -> bool:
	if _mode == &"task" and _selected_inventory_index >= 0:
		_selected_inventory_index = -1
		_refresh()
		return true
	return false

func cancel_menu_level() -> bool:
	if clear_selection_if_any():
		return true
	if _mode == &"task":
		return _return_to_primary_menu()
	return false

func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.42)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_primary_menu = PRIMARY_MENU_SCRIPT.new()
	_primary_menu.name = "PrimaryMenu"
	_primary_menu.visible = false
	_primary_menu.entry_pressed.connect(_on_primary_menu_entry_pressed)
	add_child(_primary_menu)

	_root_panel = PanelContainer.new()
	_root_panel.custom_minimum_size = MANAGEMENT_PANEL_SIZE
	_root_panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_BG, PANEL_BORDER, 12))
	add_child(_root_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_root_panel.add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	margin.add_child(main)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 1.0))
	main.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.add_theme_color_override("font_color", Color(0.60, 0.72, 0.78, 1.0))
	main.add_child(_subtitle_label)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	main.add_child(_content)

	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	main.add_child(_footer)

func _refresh() -> void:
	if not visible:
		return
	_apply_panel_size_for_mode()
	match _mode:
		&"task":
			_clear_panel_content()
			_refresh_task_management()
		_:
			_clear_panel_content()
			_refresh_home()

func _refresh_home() -> void:
	var helper: ManagementUiStyleHelper = null
	if owner_ui != null:
		helper = owner_ui.management_ui_style_helper
	_primary_menu.configure(
		LocalizationManager.tr_key("ui.cell_management.title", "Cell Management"),
		LocalizationManager.tr_key("ui.cell_management.subtitle", "Manage terrain effects or deploy short-lived task modules for the next battle."),
		[
			{
				"id": &"board",
				"node_name": "OpenGridManagementButton",
				"text": LocalizationManager.tr_key("ui.cell_management.board_entry", "Grid Management"),
			},
			{
				"id": &"task",
				"node_name": "OpenTaskManagementButton",
				"text": LocalizationManager.tr_key("ui.cell_management.task_entry", "Task Management"),
			},
		],
		helper
	)

func _refresh_task_management() -> void:
	_title_label.text = LocalizationManager.tr_key("ui.task_management.title", "Task Management")
	_subtitle_label.text = LocalizationManager.tr_key("ui.task_management.subtitle", "Select a task module, then choose an active cell. Battle start consumes deployed modules and discards unassigned modules.")
	_build_special_shop_offer()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	_content.add_child(body)
	_build_inventory_column(body)
	_build_cell_column(body)
	_build_deployment_column(body)
	_add_footer_back_button()

func _build_special_shop_offer() -> void:
	var definition := CellTaskModuleRuntime.get_special_shop_offer_definition()
	if definition == null:
		return
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cost := CellTaskModuleRuntime.get_special_shop_cost_count(definition.module_id)
	button.text = "Special exchange: %s\nCost: %d uninstalled %s cell effect(s)" % [
		_format_task_module(definition, definition.module_id),
		cost,
		definition.get_rarity(),
	]
	var validation := CellTaskModuleRuntime.can_purchase_special_shop_offer()
	button.disabled = not bool(validation.get("ok", false))
	_style_button(button)
	button.pressed.connect(_on_special_shop_offer_pressed)
	_content.add_child(button)

func _build_inventory_column(parent: HBoxContainer) -> void:
	var column := _make_panel_column(parent, "Task Modules", Vector2(280, 0))
	var inventory := CellTaskModuleRuntime.get_inventory_snapshot()
	if inventory.is_empty():
		column.add_child(_make_muted_label("No task modules. Complete cell objectives to earn more."))
		return
	for index in range(inventory.size()):
		var module_id := str(inventory[index])
		var definition := CellTaskModuleRuntime.get_definition(module_id)
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = index == _selected_inventory_index
		button.custom_minimum_size = Vector2(220, 58)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = _format_task_module(definition, module_id)
		_style_button(button)
		button.pressed.connect(_on_inventory_pressed.bind(index))
		column.add_child(button)

func _build_cell_column(parent: HBoxContainer) -> void:
	var column := _make_panel_column(parent, "Active Cells", Vector2(220, 0))
	if _board == null:
		column.add_child(_make_muted_label("Board unavailable."))
		return
	for cell_id in _board.get_active_cell_ids():
		var id := int(cell_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 48)
		button.text = _format_cell_button_text(id)
		button.disabled = _selected_inventory_index < 0 or CellTaskModuleRuntime.get_deployment_snapshot().has(str(id))
		_style_button(button)
		button.pressed.connect(_on_cell_pressed.bind(id))
		column.add_child(button)

func _build_deployment_column(parent: HBoxContainer) -> void:
	var column := _make_panel_column(parent, "Deployed", Vector2(280, 0))
	var deployments := CellTaskModuleRuntime.get_deployment_snapshot()
	if deployments.is_empty():
		column.add_child(_make_muted_label("No deployed task modules."))
		return
	var keys := deployments.keys()
	keys.sort()
	for key in keys:
		var module_id := str(deployments[key])
		var definition := CellTaskModuleRuntime.get_definition(module_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 58)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "Cell %s\n%s\nClick to cancel" % [str(key), _format_task_module(definition, module_id)]
		_style_button(button)
		button.pressed.connect(_on_deployment_pressed.bind(int(str(key))))
		column.add_child(button)

func _make_panel_column(parent: Container, title: String, min_size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.07, 0.095, 0.125, 0.94), Color(0.22, 0.36, 0.46), 8)
	)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	column.add_child(label)
	return column

func _make_muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.76, 1.0))
	return label

func _add_footer_back_button() -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(spacer)
	var button := Button.new()
	button.text = LocalizationManager.tr_key("ui.common.back", "Back")
	button.custom_minimum_size = Vector2(150, 52)
	_style_button(button)
	button.pressed.connect(_on_back_pressed)
	_footer.add_child(button)

func _format_task_module(definition: TaskModuleDefinition, fallback_id: String) -> String:
	if definition == null:
		return fallback_id
	return "[%s] %s\n%s" % [definition.get_rarity(), definition.get_display_name(), definition.get_task_label()]

func _format_cell_button_text(cell_id: int) -> String:
	var text := "Cell %d" % cell_id
	var deployed := str(CellTaskModuleRuntime.get_deployment_snapshot().get(str(cell_id), ""))
	if deployed != "":
		var definition := CellTaskModuleRuntime.get_definition(deployed)
		text += "\n%s" % (definition.get_display_name() if definition else deployed)
	else:
		text += "\nAvailable"
	return text

func _style_button(button: Button) -> void:
	if owner_ui != null and owner_ui.has_method("_style_management_button"):
		owner_ui.call("_style_management_button", button, false)
		return
	var normal := _make_panel_style(Color(0.08, 0.12, 0.16, 0.94), Color(0.25, 0.42, 0.52, 1.0), 7)
	var hover := _make_panel_style(Color(0.10, 0.16, 0.20, 0.96), Color(0.45, 0.70, 0.82, 1.0), 7)
	var pressed := _make_panel_style(Color(0.07, 0.18, 0.15, 0.98), Color(0.45, 0.85, 0.70, 1.0), 7)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)

func _apply_panel_size_for_mode() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if _mode == &"home":
		_primary_menu.visible = true
		_root_panel.visible = false
		return
	_primary_menu.visible = false
	_root_panel.visible = true
	_root_panel.custom_minimum_size = MANAGEMENT_PANEL_SIZE
	_root_panel.size = MANAGEMENT_PANEL_SIZE
	_root_panel.position = (viewport_size - MANAGEMENT_PANEL_SIZE) * 0.5
	_title_label.custom_minimum_size = Vector2(0, 0)
	_subtitle_label.custom_minimum_size = Vector2(0, 0)
	_content.add_theme_constant_override("separation", 10)

func _make_panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	if bg.is_equal_approx(PANEL_BG):
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_size = 12
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _clear_panel_content() -> void:
	for child in _content.get_children():
		child.queue_free()
	for child in _footer.get_children():
		child.queue_free()

func _on_primary_menu_entry_pressed(entry_id: StringName) -> void:
	match entry_id:
		&"board":
			_on_board_entry_pressed()
		&"task":
			_on_task_entry_pressed()

func _on_board_entry_pressed() -> void:
	board_management_requested.emit()

func _on_task_entry_pressed() -> void:
	_mode = &"task"
	_selected_inventory_index = -1
	_refresh()

func _on_back_pressed() -> void:
	_return_to_primary_menu()

func _return_to_primary_menu() -> bool:
	_selected_inventory_index = -1
	if owner_ui != null and owner_ui.rest_area_ui_controller != null:
		owner_ui.rest_area_ui_controller.back_to_board_primary_menu()
		return true
	_mode = &"home"
	_refresh()
	return true

func _on_inventory_pressed(index: int) -> void:
	_selected_inventory_index = index
	_refresh()

func _on_cell_pressed(cell_id: int) -> void:
	if _selected_inventory_index < 0:
		return
	var result := CellTaskModuleRuntime.deploy_inventory_module(_selected_inventory_index, cell_id, _board)
	if not bool(result.get("ok", false)) and owner_ui != null:
		owner_ui.show_item_message(str(result.get("reason", "Cannot deploy task module.")), 1.6)
	_selected_inventory_index = -1
	_refresh()

func _on_deployment_pressed(cell_id: int) -> void:
	var result := CellTaskModuleRuntime.cancel_deployment(cell_id)
	if not bool(result.get("ok", false)) and owner_ui != null:
		owner_ui.show_item_message(str(result.get("reason", "Cannot cancel deployment.")), 1.6)
	_refresh()

func _on_special_shop_offer_pressed() -> void:
	var result := CellTaskModuleRuntime.purchase_special_shop_offer()
	if not bool(result.get("ok", false)) and owner_ui != null:
		owner_ui.show_item_message(str(result.get("reason", "Cannot exchange task module.")), 1.6)
	_refresh()
