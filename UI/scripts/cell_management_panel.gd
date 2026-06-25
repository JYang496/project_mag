extends Control
class_name CellManagementPanel

signal close_requested
signal board_management_requested

const PANEL_BG := Color(0.045, 0.065, 0.09, 0.98)
const PANEL_BORDER := Color(0.18, 0.38, 0.52, 1.0)
const MANAGEMENT_PANEL_SIZE := Vector2(1000, 600)
const SIDE_CONTENT_WIDTH := 380.0
const CELL_PREVIEW_GRID_SIZE := Vector2(352, 352)
const CELL_PREVIEW_BUTTON_SIZE := Vector2(112, 112)
const CELL_PREVIEW_TEXTURE_SIZE := Vector2(64, 64)
const PRIMARY_MENU_SCRIPT := preload("res://UI/scripts/management/reusable_primary_menu.gd")

var owner_ui: UI
var _board: BoardCellGenerator
var _mode: StringName = &"home"
var _selected_inventory_index: int = -1
var _pending_overwrite_inventory_index: int = -1
var _pending_overwrite_cell_id: int = 0
var _root_panel: Panel
var _primary_menu: Control
var _title_label: Label
var _subtitle_label: Label
var _content: VBoxContainer
var _footer: HBoxContainer
var _overwrite_confirm_dialog: ConfirmationDialog

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
	_clear_pending_overwrite()

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

	_root_panel = Panel.new()
	_root_panel.name = "TaskManagementPanel"
	_root_panel.custom_minimum_size = MANAGEMENT_PANEL_SIZE
	_root_panel.clip_contents = true
	_root_panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_BG, PANEL_BORDER, 12))
	add_child(_root_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_root_panel.add_child(margin)

	var main := VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	match _mode:
		&"task":
			_clear_panel_content()
			_refresh_task_management()
		_:
			_clear_panel_content()
			_refresh_home()
	_apply_panel_size_for_mode()
	call_deferred("_apply_panel_size_for_mode")

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
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	_content.add_child(body)
	_build_cell_preview_grid(body)
	_build_task_module_side(body)
	_add_footer_back_button()

func _build_cell_preview_grid(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.055, 0.064, 0.070, 0.94), Color(0.18, 0.27, 0.31, 0.95), 6)
	)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.custom_minimum_size = CELL_PREVIEW_GRID_SIZE
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	margin.add_child(grid)

	var ids := [7, 8, 9, 4, 5, 6, 1, 2, 3]
	for id_variant in ids:
		var cell_id := int(id_variant)
		var button := Button.new()
		button.custom_minimum_size = CELL_PREVIEW_BUTTON_SIZE
		button.toggle_mode = false
		button.disabled = _board == null or not _board.is_cell_active_by_id(cell_id)
		button.text = ""
		button.add_theme_stylebox_override("normal", _make_cell_preview_style(cell_id, false, button.disabled))
		button.add_theme_stylebox_override("hover", _make_cell_preview_style(cell_id, true, button.disabled))
		button.add_theme_stylebox_override("pressed", _make_cell_preview_style(cell_id, true, button.disabled))
		button.add_theme_stylebox_override("disabled", _make_cell_preview_style(cell_id, false, true))
		button.pressed.connect(_on_cell_pressed.bind(cell_id))
		button.add_child(_make_cell_preview_content(cell_id, button.disabled))
		grid.add_child(button)

func _build_task_module_side(parent: HBoxContainer) -> void:
	var side := VBoxContainer.new()
	side.name = "TaskModuleSide"
	side.custom_minimum_size = Vector2(420, 0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 12)
	parent.add_child(side)
	_build_special_shop_offer(side)
	_build_inventory_column(side)
	_build_deployment_summary(side)

func _build_special_shop_offer(parent: Container = null) -> void:
	var target := parent if parent != null else _content
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
	target.add_child(button)

func _build_inventory_column(parent: Container) -> void:
	var title := Label.new()
	title.text = "Ready To Install"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	parent.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "TaskInventoryScroll"
	scroll.custom_minimum_size = Vector2(SIDE_CONTENT_WIDTH, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var column := VBoxContainer.new()
	column.name = "TaskInventoryList"
	column.custom_minimum_size = Vector2(SIDE_CONTENT_WIDTH, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)

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

func _build_deployment_summary(parent: Container) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "DeploymentSummaryScroll"
	scroll.custom_minimum_size = Vector2(SIDE_CONTENT_WIDTH, 76)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var label := _make_muted_label(_build_deployment_summary_text())
	label.custom_minimum_size = Vector2(SIDE_CONTENT_WIDTH, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(label)

func _build_deployment_summary_text() -> String:
	var deployments := CellTaskModuleRuntime.get_deployment_snapshot()
	if deployments.is_empty():
		return "No deployed task modules."
	var keys := deployments.keys()
	keys.sort()
	var lines := PackedStringArray(["Deployed"])
	for key in keys:
		var module_id := str(deployments[key])
		var definition := CellTaskModuleRuntime.get_definition(module_id)
		lines.append("Cell %s: %s" % [str(key), _format_task_module_inline(definition, module_id)])
	return "\n".join(lines)

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

func _format_task_module_inline(definition: TaskModuleDefinition, fallback_id: String) -> String:
	if definition == null:
		return fallback_id
	return "%s / %s / %s" % [definition.get_task_label(), definition.get_rarity(), definition.get_display_name()]

func _make_cell_preview_content(cell_id: int, disabled: bool) -> Control:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "Cell %d" % cell_id
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	content.add_child(title)

	var texture := TextureRect.new()
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.texture = _get_cell_terrain_texture(cell_id)
	texture.custom_minimum_size = CELL_PREVIEW_TEXTURE_SIZE
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(texture)

	var status := Label.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.text = _format_cell_preview_status(cell_id, disabled)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color(0.66, 0.78, 0.82, 1.0))
	content.add_child(status)
	return margin

func _format_cell_preview_status(cell_id: int, disabled: bool) -> String:
	var module_id := _get_cell_task_module_id(cell_id)
	if module_id == "":
		return "Locked" if disabled else "Available"
	var definition := CellTaskModuleRuntime.get_definition(module_id)
	if definition == null:
		return module_id
	return "%s / %s" % [definition.get_task_label(), definition.get_rarity()]

func _get_cell_task_module_id(cell_id: int) -> String:
	var key := str(cell_id)
	var deployments := CellTaskModuleRuntime.get_deployment_snapshot()
	if deployments.has(key):
		return str(deployments[key])
	var active_tasks := CellTaskModuleRuntime.get_active_tasks_snapshot()
	if active_tasks.has(key):
		return str(active_tasks[key])
	return ""

func _selected_cell_has_deployment(cell_id: int) -> bool:
	return CellTaskModuleRuntime.get_deployment_snapshot().has(str(cell_id))

func _get_cell_terrain_texture(cell_id: int) -> Texture2D:
	var terrain_type := Cell.TerrainType.NONE
	if _board != null:
		var cell := _board.get_cell_by_logical_id(cell_id)
		if cell != null:
			terrain_type = int(cell.terrain_type)
	if not Cell.TERRAIN_TEXTURE_PATHS.has(terrain_type):
		return null
	var loaded := load(str(Cell.TERRAIN_TEXTURE_PATHS[terrain_type]))
	return loaded as Texture2D

func _make_cell_preview_style(cell_id: int, hover: bool, disabled: bool) -> StyleBoxFlat:
	var style := _make_panel_style(Color(0.08, 0.09, 0.10, 0.95), Color(0.28, 0.34, 0.38, 1.0), 6)
	if disabled:
		style.bg_color = Color(0.04, 0.04, 0.045, 0.72)
		style.border_color = Color(0.18, 0.18, 0.18, 0.9)
	elif _selected_cell_has_deployment(cell_id):
		style.bg_color = Color(0.08, 0.12, 0.10, 0.96)
		style.border_color = Color(0.44, 0.85, 0.52, 1.0)
	elif hover:
		style.bg_color = Color(0.10, 0.15, 0.18, 0.96)
		style.border_color = Color(0.50, 0.76, 0.92, 1.0)
	return style

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
	if _selected_cell_has_deployment(cell_id):
		_request_overwrite_confirmation(_selected_inventory_index, cell_id)
		return
	var result := CellTaskModuleRuntime.deploy_inventory_module(_selected_inventory_index, cell_id, _board)
	if not bool(result.get("ok", false)) and owner_ui != null:
		owner_ui.show_item_message(str(result.get("reason", "Cannot deploy task module.")), 1.6)
	_selected_inventory_index = -1
	_refresh()

func _request_overwrite_confirmation(index: int, cell_id: int) -> void:
	var validation := CellTaskModuleRuntime.can_replace_deployment_with_inventory_module(index, cell_id, _board)
	if not bool(validation.get("ok", false)):
		if owner_ui != null:
			owner_ui.show_item_message(str(validation.get("reason", "Cannot replace task module.")), 1.6)
		return
	_init_overwrite_confirm_dialog()
	_pending_overwrite_inventory_index = index
	_pending_overwrite_cell_id = cell_id
	var inventory := CellTaskModuleRuntime.get_inventory_snapshot()
	var new_module_id := str(inventory[index])
	var old_module_id := _get_cell_task_module_id(cell_id)
	_overwrite_confirm_dialog.title = "Replace Task Module"
	_overwrite_confirm_dialog.dialog_text = "Cell %d already has a task module.\n\nCurrent: %s\nNew: %s\n\nReplace the current module? The old module will be discarded." % [
		cell_id,
		_format_task_module_for_dialog(old_module_id),
		_format_task_module_for_dialog(new_module_id)
	]
	_overwrite_confirm_dialog.get_ok_button().text = "Replace"
	_overwrite_confirm_dialog.get_cancel_button().text = "Cancel"
	_overwrite_confirm_dialog.popup_centered(Vector2i(520, 300))

func _init_overwrite_confirm_dialog() -> void:
	if _overwrite_confirm_dialog != null and is_instance_valid(_overwrite_confirm_dialog):
		return
	_overwrite_confirm_dialog = ConfirmationDialog.new()
	_overwrite_confirm_dialog.name = "TaskOverwriteConfirmDialog"
	_overwrite_confirm_dialog.exclusive = true
	add_child(_overwrite_confirm_dialog)
	_overwrite_confirm_dialog.confirmed.connect(_on_overwrite_confirmed)
	_overwrite_confirm_dialog.canceled.connect(_on_overwrite_cancelled)
	_overwrite_confirm_dialog.close_requested.connect(_on_overwrite_cancelled)

func _on_overwrite_confirmed() -> void:
	var result := CellTaskModuleRuntime.replace_deployment_with_inventory_module(
		_pending_overwrite_inventory_index,
		_pending_overwrite_cell_id,
		_board
	)
	if not bool(result.get("ok", false)) and owner_ui != null:
		owner_ui.show_item_message(str(result.get("reason", "Cannot replace task module.")), 1.6)
	_clear_pending_overwrite()
	_selected_inventory_index = -1
	_refresh()

func _on_overwrite_cancelled() -> void:
	_clear_pending_overwrite()

func _clear_pending_overwrite() -> void:
	_pending_overwrite_inventory_index = -1
	_pending_overwrite_cell_id = 0

func _format_task_module_for_dialog(module_id: String) -> String:
	var definition := CellTaskModuleRuntime.get_definition(module_id)
	if definition == null:
		return module_id
	return "%s [%s]" % [definition.get_task_label(), definition.get_rarity()]

func _on_special_shop_offer_pressed() -> void:
	var result := CellTaskModuleRuntime.purchase_special_shop_offer()
	if not bool(result.get("ok", false)) and owner_ui != null:
		owner_ui.show_item_message(str(result.get("reason", "Cannot exchange task module.")), 1.6)
	_refresh()
