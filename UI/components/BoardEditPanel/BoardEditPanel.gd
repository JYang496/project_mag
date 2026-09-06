extends Control

signal close_requested

const CELL_BUTTON_SCENE := preload("res://UI/components/BoardCellButton/BoardCellButton.tscn")
const EFFECT_CARD_SCENE := preload("res://UI/components/CellEffectInventoryCard/CellEffectInventoryCard.tscn")
const DRAG_PREVIEW_SCENE := preload("res://UI/components/BoardEffectDragPreview/BoardEffectDragPreview.tscn")
const EMPTY_STATE_SCENE := preload("res://UI/components/EmptyStateLabel/EmptyStateLabel.tscn")

const MANAGEMENT_PANEL_BG := Color(0.045, 0.065, 0.09, 0.98)
const MANAGEMENT_PANEL_BORDER := Color(0.18, 0.38, 0.52, 1.0)
const MANAGEMENT_BUTTON_BG := Color(0.12, 0.18, 0.25)
const MANAGEMENT_BUTTON_BORDER := Color(0.28, 0.42, 0.55)
const MANAGEMENT_PANEL_SIZE := Vector2(1000, 600)
const SIDE_CONTENT_WIDTH := 380.0

var _board: BoardCellGenerator
var _selected_effect_id := ""
var _selected_cell_id := 0
@onready var _root_panel: PanelContainer = %Panel
@onready var _grid: GridContainer = %Grid
@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _detail_label: Label = %DetailLabel
@onready var _title_label: Label = %Title
@onready var _subtitle_label: Label = %Subtitle
@onready var _inventory_title_label: Label = %InventoryTitle
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _undo_button: Button = %UndoButton
@onready var _clear_button: Button = %ClearButton
@onready var _close_button: Button = %CloseButton

func _ready() -> void:
	visible = false
	_undo_button.pressed.connect(_on_undo_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_style_management_button(_undo_button)
	_style_management_button(_clear_button)
	_style_management_button(_close_button)
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
		_show_message(LocalizationManager.localize_cell_management_reason(
			str(result.get("reason", LocalizationManager.tr_key("ui.board_edit.install_failed", "Cannot install.")))
		))
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
		_show_message(LocalizationManager.localize_cell_management_reason(
			str(result.get("reason", LocalizationManager.tr_key("ui.board_edit.swap_failed", "Cannot swap.")))
		))
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
	var preview := DRAG_PREVIEW_SCENE.instantiate() as Control
	preview.call("set_data", definition.get_display_name() if definition != null else fallback_id, definition.icon_texture if definition != null else null)
	return preview

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
		var button := CELL_BUTTON_SCENE.instantiate() as Button
		var unavailable := _board == null or not _board.is_cell_active_by_id(int(id))
		var button_effect_id := CellEffectRuntime.get_effect_for_cell(int(id), true)
		var button_definition := CellEffectRuntime.get_definition(button_effect_id)
		button.call("set_data", int(id), _build_cell_button_text(int(id), unavailable), button_definition.icon_texture if button_definition != null else null, _selected_cell_id == int(id), unavailable)
		button.call("set_drag_interface", can_install_effect_on_cell, can_swap_installed_effect_between_cells, get_installed_drag_data_for_cell, build_effect_drag_preview)
		button.pressed.connect(_on_cell_pressed.bind(int(id)))
		button.connect("install_requested", install_effect_on_cell)
		button.connect("swap_requested", swap_installed_effect_between_cells)
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
		var empty := EMPTY_STATE_SCENE.instantiate() as Label
		empty.name = "EmptyInventoryLabel"
		empty.custom_minimum_size = Vector2(SIDE_CONTENT_WIDTH, 0)
		empty.call("set_data", LocalizationManager.tr_key("ui.board_edit.empty_inventory", "No cell effect items. Complete objectives to earn them."))
		_inventory_list.add_child(empty)
		return
	for effect_id_variant in ids:
		var effect_id := str(effect_id_variant)
		var definition := CellEffectRuntime.get_definition(effect_id)
		if definition == null:
			continue
		var card := EFFECT_CARD_SCENE.instantiate() as Button
		var owned_count := CellEffectRuntime.get_owned_count(effect_id)
		var pending_count := CellEffectRuntime.get_pending_count(effect_id)
		var available_count := CellEffectRuntime.get_available_count(effect_id)
		var card_text := LocalizationManager.tr_format(
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
		card.call("set_data", effect_id, card_text, definition.icon_texture, _selected_effect_id == effect_id, available_count <= 0)
		card.call("set_drag_interface", can_drag_effect, build_effect_drag_preview)
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
	var description := definition.get_description()
	if description != "":
		lines.append(description)
	lines.append(LocalizationManager.tr_format(
		"ui.board_edit.effect_meta",
		{"tier": int(definition.tier), "rarity": LocalizationManager.get_rarity_name(definition.rarity)},
		"Tier: %d    Rarity: %s" % [int(definition.tier), LocalizationManager.get_rarity_name(definition.rarity)]
	))
	var params := PackedStringArray()
	for key in definition.get_aura_parameters().keys():
		var value: Variant = definition.get_aura_parameters()[key]
		var parameter_id := str(key).trim_prefix("aura_")
		var parameter_name := LocalizationManager.tr_key(
			"ui.board_edit.parameter.%s" % parameter_id,
			parameter_id.replace("_", " ").capitalize()
		)
		if value is float and not is_equal_approx(float(value), 0.0) and not is_equal_approx(float(value), 1.0):
			params.append("%s: %.2f" % [parameter_name, float(value)])
		elif value is int and int(value) != 0 and int(value) != 1:
			params.append("%s: %d" % [parameter_name, int(value)])
	if not params.is_empty():
		lines.append(LocalizationManager.tr_format(
			"ui.board_edit.parameters",
			{"parameters": ", ".join(params)},
			"Parameters: %s" % ", ".join(params)
		))
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
