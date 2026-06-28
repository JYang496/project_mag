extends Control
class_name BoardEditPanel

signal close_requested

const CELL_BUTTON_SCRIPT := preload("res://UI/scripts/cell_effect_board_cell_button.gd")
const EFFECT_CARD_SCRIPT := preload("res://UI/scripts/cell_effect_inventory_card.gd")

const MANAGEMENT_PANEL_BG := Color(0.045, 0.065, 0.09, 0.98)
const MANAGEMENT_PANEL_BORDER := Color(0.18, 0.38, 0.52, 1.0)
const MANAGEMENT_BUTTON_BG := Color(0.12, 0.18, 0.25)
const MANAGEMENT_BUTTON_BORDER := Color(0.28, 0.42, 0.55)
const MANAGEMENT_PANEL_SIZE := Vector2(1000, 600)
const SIDE_CONTENT_WIDTH := 380.0

var _board: BoardCellGenerator
var _selected_effect_id := ""
var _selected_cell_id := 0
var _root_panel: PanelContainer
var _grid: GridContainer
var _inventory_list: VBoxContainer
var _detail_label: Label
var _title_label: Label
var _subtitle_label: Label
var _inventory_title_label: Label
var _detail_icon: TextureRect
var _undo_button: Button
var _clear_button: Button
var _close_button: Button

func _ready() -> void:
	visible = false
	_build_layout()
	_refresh_static_texts()
	if not CellEffectRuntime.inventory_changed.is_connected(_refresh):
		CellEffectRuntime.inventory_changed.connect(_refresh)
	if not CellEffectRuntime.pending_changed.is_connected(_refresh):
		CellEffectRuntime.pending_changed.connect(_refresh)
	if not CellEffectRuntime.installed_changed.is_connected(_refresh):
		CellEffectRuntime.installed_changed.connect(_refresh)
	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)

func open_panel(board: BoardCellGenerator) -> bool:
	_board = board
	if _board == null:
		_board = _find_board()
	if _board == null:
		return false
	_selected_effect_id = ""
	_selected_cell_id = 0
	visible = true
	CellEffectRuntime.apply_to_board(_board, true)
	_refresh()
	return true

func close_panel() -> void:
	visible = false
	_selected_effect_id = ""
	_selected_cell_id = 0

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (event.is_action_pressed("ui_cancel") or event.is_action_pressed("CANCEL")) and clear_selection_if_any():
		get_viewport().set_input_as_handled()

func can_drag_effect(effect_id: String) -> bool:
	return CellEffectRuntime.get_available_count(effect_id) > 0

func can_install_effect_on_cell(effect_id: String, cell_id: int) -> bool:
	if _board == null:
		return false
	if not _board.is_cell_active_by_id(cell_id):
		return false
	return CellEffectRuntime.get_available_count(effect_id) > 0

func install_effect_on_cell(effect_id: String, cell_id: int) -> void:
	if not can_install_effect_on_cell(effect_id, cell_id):
		_show_message(LocalizationManager.tr_key("ui.board_edit.install_rejected", "Cannot install this effect here."))
		return
	var result := CellEffectRuntime.set_pending_effect(cell_id, effect_id)
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("reason", LocalizationManager.tr_key("ui.board_edit.install_failed", "Cannot install."))))
		return
	_selected_cell_id = cell_id
	CellEffectRuntime.apply_to_board(_board, true)
	_refresh()

func can_swap_installed_effect_between_cells(from_cell_id: int, to_cell_id: int) -> bool:
	if _board == null:
		return false
	if not _board.is_cell_active_by_id(from_cell_id) or not _board.is_cell_active_by_id(to_cell_id):
		return false
	var result: Dictionary = CellEffectRuntime.can_swap_installed_effects(from_cell_id, to_cell_id)
	return bool(result.get("ok", false))

func swap_installed_effect_between_cells(from_cell_id: int, to_cell_id: int) -> void:
	if _board == null:
		return
	if not _board.is_cell_active_by_id(from_cell_id) or not _board.is_cell_active_by_id(to_cell_id):
		_show_message(LocalizationManager.tr_key("ui.board_edit.swap_rejected", "Cannot swap these cells."))
		return
	var result: Dictionary = CellEffectRuntime.swap_installed_effects(from_cell_id, to_cell_id)
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("reason", LocalizationManager.tr_key("ui.board_edit.swap_failed", "Cannot swap."))))
		return
	_selected_cell_id = to_cell_id
	CellEffectRuntime.apply_to_board(_board, true)
	_refresh()

func get_installed_drag_data_for_cell(cell_id: int) -> Dictionary:
	if _board == null or not _board.is_cell_active_by_id(cell_id):
		return {}
	if CellEffectRuntime.get_pending_snapshot().has(str(cell_id)):
		return {}
	var effect_id := str(CellEffectRuntime.get_installed_snapshot().get(str(cell_id), ""))
	if effect_id == "":
		return {}
	var definition := CellEffectRuntime.get_definition(effect_id)
	if definition == null or not definition.can_swap_installed:
		return {}
	return {
		"type": "installed_cell_effect",
		"effect_id": effect_id,
		"source_cell_id": cell_id,
	}

func build_effect_drag_preview(definition: CellEffectDefinition, fallback_id: String = "") -> Control:
	var preview := HBoxContainer.new()
	preview.add_theme_constant_override("separation", 6)
	if definition != null and definition.icon_texture != null:
		var icon := TextureRect.new()
		icon.texture = definition.icon_texture
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.add_child(icon)
	var label := Label.new()
	label.text = definition.get_display_name() if definition != null else fallback_id
	label.add_theme_font_size_override("font_size", 14)
	preview.add_child(label)
	return preview

func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_root_panel = PanelContainer.new()
	_root_panel.name = "BoardEditPanel"
	_root_panel.custom_minimum_size = MANAGEMENT_PANEL_SIZE
	_root_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_root_panel.offset_left = -500
	_root_panel.offset_top = -300
	_root_panel.offset_right = 500
	_root_panel.offset_bottom = 300
	_root_panel.add_theme_stylebox_override("panel", _make_management_panel_style())
	add_child(_root_panel)

	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_root_panel.add_child(margin)

	var main := VBoxContainer.new()
	main.name = "MainLayout"
	main.add_theme_constant_override("separation", 14)
	margin.add_child(main)

	var header := VBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 2)
	main.add_child(header)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 1.0))
	header.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.add_theme_color_override("font_color", Color(0.60, 0.72, 0.78, 1.0))
	header.add_child(_subtitle_label)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	main.add_child(body)

	var grid_panel := PanelContainer.new()
	grid_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.064, 0.070, 0.94), Color(0.18, 0.27, 0.31, 0.95)))
	body.add_child(grid_panel)

	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left", 12)
	grid_margin.add_theme_constant_override("margin_right", 12)
	grid_margin.add_theme_constant_override("margin_top", 12)
	grid_margin.add_theme_constant_override("margin_bottom", 12)
	grid_panel.add_child(grid_margin)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.custom_minimum_size = Vector2(430, 430)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	grid_margin.add_child(_grid)

	var side := VBoxContainer.new()
	side.name = "SideContent"
	side.custom_minimum_size = Vector2(420, 0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 12)
	body.add_child(side)

	_inventory_title_label = Label.new()
	_inventory_title_label.add_theme_font_size_override("font_size", 18)
	_inventory_title_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	side.add_child(_inventory_title_label)

	var scroll := ScrollContainer.new()
	scroll.name = "InventoryScroll"
	scroll.custom_minimum_size = Vector2(SIDE_CONTENT_WIDTH, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(scroll)
	_inventory_list = VBoxContainer.new()
	_inventory_list.name = "InventoryList"
	_inventory_list.custom_minimum_size = Vector2(SIDE_CONTENT_WIDTH, 0)
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_inventory_list)

	_detail_label = Label.new()
	_detail_label.name = "DetailLabel"
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(SIDE_CONTENT_WIDTH, 96)
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.90, 1.0))
	side.add_child(_detail_label)

	_detail_icon = TextureRect.new()
	_detail_icon.name = "DetailIcon"
	_detail_icon.custom_minimum_size = Vector2(64, 64)
	_detail_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.visible = false
	side.add_child(_detail_icon)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	main.add_child(footer)
	_undo_button = Button.new()
	_undo_button.pressed.connect(_on_undo_pressed)
	_style_management_button(_undo_button)
	footer.add_child(_undo_button)
	_clear_button = Button.new()
	_clear_button.pressed.connect(_on_clear_pressed)
	_style_management_button(_clear_button)
	footer.add_child(_clear_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_close_button = Button.new()
	_close_button.pressed.connect(_on_close_pressed)
	_style_management_button(_close_button)
	footer.add_child(_close_button)

func _refresh() -> void:
	if not visible:
		return
	_refresh_grid()
	_refresh_inventory()
	_refresh_detail()
	_undo_button.disabled = _selected_cell_id <= 0 or not CellEffectRuntime.get_pending_snapshot().has(str(_selected_cell_id))
	_clear_button.disabled = not CellEffectRuntime.has_pending_edits()

func _refresh_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var ids := [7, 8, 9, 4, 5, 6, 1, 2, 3]
	for id in ids:
		var button := CELL_BUTTON_SCRIPT.new() as CellEffectBoardCellButton
		button.logical_id = int(id)
		button.board_edit_panel = self
		button.custom_minimum_size = Vector2(132, 132)
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 15)
		button.button_pressed = _selected_cell_id == int(id)
		button.disabled = _board == null or not _board.is_cell_active_by_id(int(id))
		button.text = _build_cell_button_text(int(id), button.disabled)
		var button_effect_id := CellEffectRuntime.get_effect_for_cell(int(id), true)
		var button_definition := CellEffectRuntime.get_definition(button_effect_id)
		button.icon = button_definition.icon_texture if button_definition != null else null
		button.expand_icon = true
		button.pressed.connect(_on_cell_pressed.bind(int(id)))
		button.add_theme_stylebox_override("normal", _make_cell_style(int(id), false))
		button.add_theme_stylebox_override("hover", _make_cell_style(int(id), true))
		button.add_theme_stylebox_override("pressed", _make_cell_style(int(id), true))
		_grid.add_child(button)

func _refresh_inventory() -> void:
	for child in _inventory_list.get_children():
		child.queue_free()
	var inventory := CellEffectRuntime.get_inventory_snapshot()
	var ids := inventory.keys()
	ids.sort()
	if ids.is_empty():
		var empty := Label.new()
		empty.name = "EmptyInventoryLabel"
		empty.text = LocalizationManager.tr_key("ui.board_edit.empty_inventory", "No cell effect items. Complete objectives to earn them.")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(SIDE_CONTENT_WIDTH, 0)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.add_theme_color_override("font_color", Color(0.62, 0.72, 0.76, 1.0))
		_inventory_list.add_child(empty)
		return
	for effect_id_variant in ids:
		var effect_id := str(effect_id_variant)
		var definition := CellEffectRuntime.get_definition(effect_id)
		if definition == null:
			continue
		var card := EFFECT_CARD_SCRIPT.new() as CellEffectInventoryCard
		card.effect_id = effect_id
		card.board_edit_panel = self
		card.toggle_mode = true
		card.button_pressed = _selected_effect_id == effect_id
		card.disabled = CellEffectRuntime.get_available_count(effect_id) <= 0
		card.custom_minimum_size = Vector2(0, 56)
		var owned_count := CellEffectRuntime.get_owned_count(effect_id)
		var pending_count := CellEffectRuntime.get_pending_count(effect_id)
		var available_count := CellEffectRuntime.get_available_count(effect_id)
		card.text = LocalizationManager.tr_format(
			"ui.board_edit.effect_counts",
			{
				"name": definition.get_display_name(),
				"owned": owned_count,
				"pending": pending_count,
				"available": available_count,
			},
			"%s  owned %d / pending %d / available %d" % [
				definition.get_display_name(),
				owned_count,
				pending_count,
				available_count,
			]
		)
		card.icon = definition.icon_texture
		card.expand_icon = true
		card.add_theme_font_size_override("font_size", 14)
		card.add_theme_stylebox_override("normal", _make_panel_style(Color(0.065, 0.078, 0.084, 0.96), Color(0.20, 0.29, 0.33, 1.0)))
		card.add_theme_stylebox_override("hover", _make_panel_style(Color(0.085, 0.120, 0.130, 0.98), Color(0.35, 0.62, 0.70, 1.0)))
		card.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.070, 0.145, 0.125, 0.98), Color(0.44, 0.85, 0.70, 1.0)))
		card.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.040, 0.046, 0.050, 0.84), Color(0.13, 0.16, 0.17, 0.9)))
		card.pressed.connect(_on_effect_pressed.bind(effect_id))
		_inventory_list.add_child(card)

func _refresh_detail() -> void:
	var lines := PackedStringArray()
	var detail_definition: CellEffectDefinition = null
	if _selected_effect_id != "":
		var definition := CellEffectRuntime.get_definition(_selected_effect_id)
		if definition:
			detail_definition = definition
			lines.append(LocalizationManager.tr_format(
				"ui.board_edit.selected_effect",
				{"name": definition.get_display_name()},
				"Selected effect: %s" % definition.get_display_name()
			))
			lines.append_array(_build_effect_detail_lines(definition))
	if _selected_cell_id > 0:
		lines.append(LocalizationManager.tr_format(
			"ui.board_edit.selected_cell",
			{"cell": _selected_cell_id},
			"Selected cell: %d" % _selected_cell_id
		))
		var effect_id := CellEffectRuntime.get_effect_for_cell(_selected_cell_id, true)
		var cell_def := CellEffectRuntime.get_definition(effect_id)
		if detail_definition == null:
			detail_definition = cell_def
		var preview_name := cell_def.get_display_name() if cell_def else LocalizationManager.tr_key("ui.board_edit.default_cell", "Default")
		lines.append(LocalizationManager.tr_format(
			"ui.board_edit.preview",
			{"name": preview_name},
			"Preview: %s" % preview_name
		))
	if lines.is_empty():
		lines.append(LocalizationManager.tr_key("ui.board_edit.select_hint", "Select an effect, then click or drag it onto an active cell."))
	if _detail_icon:
		_detail_icon.texture = detail_definition.icon_texture if detail_definition != null else null
		_detail_icon.visible = _detail_icon.texture != null
	_detail_label.text = "\n".join(lines)

func _build_effect_detail_lines(definition: CellEffectDefinition) -> PackedStringArray:
	var lines := PackedStringArray()
	if definition.description.strip_edges() != "":
		lines.append(definition.description)
	lines.append("Tier: %d    Rarity: %s" % [int(definition.tier), str(definition.rarity)])
	var params := PackedStringArray()
	for key in definition.get_aura_parameters().keys():
		var value: Variant = definition.get_aura_parameters()[key]
		if value is float and not is_equal_approx(float(value), 0.0) and not is_equal_approx(float(value), 1.0):
			params.append("%s: %.2f" % [str(key).replace("aura_", "").replace("_", " "), float(value)])
		elif value is int and int(value) != 0 and int(value) != 1:
			params.append("%s: %d" % [str(key).replace("aura_", "").replace("_", " "), int(value)])
	if not params.is_empty():
		lines.append("Parameters: %s" % ", ".join(params))
	return lines

func _build_cell_button_text(cell_id: int, disabled: bool) -> String:
	var pending := CellEffectRuntime.get_pending_snapshot()
	var installed := CellEffectRuntime.get_installed_snapshot()
	var effect_id := CellEffectRuntime.get_effect_for_cell(cell_id, true)
	var definition := CellEffectRuntime.get_definition(effect_id)
	var status := LocalizationManager.tr_key("ui.board_edit.locked_cell", "Locked") if disabled else LocalizationManager.tr_key("ui.board_edit.default_cell", "Default")
	if definition:
		status = definition.get_display_name()
	if pending.has(str(cell_id)):
		status += "\n" + LocalizationManager.tr_key("ui.board_edit.pending_badge", "PENDING")
	elif installed.has(str(cell_id)):
		status += "\n" + LocalizationManager.tr_key("ui.board_edit.installed_badge", "Installed")
	return LocalizationManager.tr_format(
		"ui.board_edit.cell_label",
		{"cell": cell_id, "status": status},
		"Cell %d\n%s" % [cell_id, status]
	)

func _make_cell_style(cell_id: int, hover: bool) -> StyleBoxFlat:
	var style := _make_panel_style(Color(0.08, 0.09, 0.10, 0.95), Color(0.28, 0.34, 0.38, 1.0))
	if _board != null and not _board.is_cell_active_by_id(cell_id):
		style.bg_color = Color(0.04, 0.04, 0.045, 0.72)
		style.border_color = Color(0.18, 0.18, 0.18, 0.9)
	elif CellEffectRuntime.get_pending_snapshot().has(str(cell_id)):
		style.bg_color = Color(0.08, 0.12, 0.10, 0.96)
		style.border_color = Color(0.44, 0.85, 0.52, 1.0)
	elif hover or _selected_cell_id == cell_id:
		style.bg_color = Color(0.10, 0.15, 0.18, 0.96)
		style.border_color = Color(0.50, 0.76, 0.92, 1.0)
	return style

func _make_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _make_management_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = MANAGEMENT_PANEL_BG
	style.border_color = MANAGEMENT_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _style_management_button(button: Button) -> void:
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui) and GlobalVariables.ui.has_method("_style_management_button"):
		GlobalVariables.ui.call("_style_management_button", button, false)
		return
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 44.0)
	button.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = MANAGEMENT_BUTTON_BG
	normal.border_color = MANAGEMENT_BUTTON_BORDER
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)

func _on_effect_pressed(effect_id: String) -> void:
	_selected_effect_id = effect_id
	if _selected_cell_id > 0:
		install_effect_on_cell(effect_id, _selected_cell_id)
		return
	_refresh()

func _on_cell_pressed(cell_id: int) -> void:
	_selected_cell_id = cell_id
	if _selected_effect_id != "":
		install_effect_on_cell(_selected_effect_id, cell_id)
	else:
		_refresh()

func _on_undo_pressed() -> void:
	if _selected_cell_id <= 0:
		return
	CellEffectRuntime.remove_pending_for_cell(_selected_cell_id)
	CellEffectRuntime.apply_to_board(_board, true)
	_refresh()

func _on_clear_pressed() -> void:
	CellEffectRuntime.clear_pending()
	CellEffectRuntime.apply_to_board(_board, true)
	_refresh()

func _on_close_pressed() -> void:
	close_requested.emit()

func _clear_selection() -> void:
	_selected_effect_id = ""
	_selected_cell_id = 0
	_refresh()

func clear_selection_if_any() -> bool:
	if _selected_effect_id == "" and _selected_cell_id <= 0:
		return false
	_clear_selection()
	return true

func _find_board() -> BoardCellGenerator:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Board") as BoardCellGenerator

func _show_message(message: String) -> void:
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui) and GlobalVariables.ui.has_method("show_item_message"):
		GlobalVariables.ui.show_item_message(message, 1.6)

func _refresh_static_texts() -> void:
	if _title_label:
		_title_label.text = LocalizationManager.tr_key("ui.board_edit.title", "Grid Management")
	if _subtitle_label:
		_subtitle_label.text = LocalizationManager.tr_key("ui.board_edit.subtitle", "Install earned cell effects onto active board cells before starting battle.")
	if _inventory_title_label:
		_inventory_title_label.text = LocalizationManager.tr_key("ui.board_edit.inventory_title", "Cell Effects")
	if _undo_button:
		_undo_button.text = LocalizationManager.tr_key("ui.board_edit.undo", "Undo Cell Pending")
	if _clear_button:
		_clear_button.text = LocalizationManager.tr_key("ui.board_edit.clear", "Clear Pending")
	if _close_button:
		_close_button.text = LocalizationManager.tr_key("ui.common.back", "Back")

func _on_language_changed(_new_locale: String) -> void:
	_refresh_static_texts()
	_refresh()
