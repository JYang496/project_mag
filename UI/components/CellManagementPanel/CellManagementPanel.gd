extends Control

signal board_management_requested

const PANEL_BG := Color(0.045, 0.065, 0.09, 0.98)
const PANEL_BORDER := Color(0.18, 0.38, 0.52, 1.0)
const MANAGEMENT_PANEL_SIZE := Vector2(1000, 600)
const SIDE_CONTENT_WIDTH := 380.0
const CELL_PREVIEW_GRID_SIZE := Vector2(352, 352)
const CELL_PREVIEW_BUTTON_SIZE := Vector2(112, 112)
const CELL_PREVIEW_TEXTURE_SIZE := Vector2(64, 64)
const TASK_MODULE_CARD_HEIGHT := 84.0
const TASK_DETAIL_WINDOW_SIZE := Vector2(360, 238)
const RARITY_UTIL := preload("res://data/LootRarity.gd")
const PRIMARY_MENU_SCENE := preload("res://UI/components/ReusablePrimaryMenu/ReusablePrimaryMenu.tscn")
const DRAG_CONTROLS := preload("res://UI/scripts/management/warehouse_drag_controls.gd")
const TASK_VIEW_SCENE := preload("res://UI/components/TaskManagementView/TaskManagementView.tscn")
const BACK_BUTTON_SCENE := preload("res://UI/components/ManagementBackButton/ManagementBackButton.tscn")
const TASK_MODULE_CARD_SCENE := preload("res://UI/components/TaskModuleCard/TaskModuleCard.tscn")
const TASK_MODULE_DRAG_PREVIEW_SCENE := preload("res://UI/components/TaskModuleDragPreview/TaskModuleDragPreview.tscn")
const TASK_CELL_PREVIEW_SCENE := preload("res://UI/components/TaskCellPreview/TaskCellPreview.tscn")
const TASK_DETAIL_WINDOW_SCENE := preload("res://UI/components/TaskDetailWindow/TaskDetailWindow.tscn")
const DETAIL_TEXT_SCENE := preload("res://UI/components/DetailText/DetailText.tscn")

var owner_ui: UI
var _board: BoardCellGenerator
var _mode: StringName = &"home"
var _selected_inventory_index: int = -1
var _pending_overwrite_inventory_index: int = -1
var _pending_overwrite_module_id: String = ""
var _pending_overwrite_cell_id: int = 0
@onready var _root_panel: Panel = %TaskManagementPanel
@onready var _primary_menu: Control = %PrimaryMenu
@onready var _title_label: Label = %Title
@onready var _subtitle_label: Label = %Subtitle
@onready var _content: VBoxContainer = %Content
@onready var _footer: HBoxContainer = %Footer
var _task_detail_window: PanelContainer
var _locked_task_detail_cell_id: int = 0
var _hover_task_detail_cell_id: int = 0

func _ready() -> void:
	visible = false
	_primary_menu.entry_pressed.connect(_on_primary_menu_entry_pressed)
	if not CellTaskModuleRuntime.inventory_changed.is_connected(_refresh):
		CellTaskModuleRuntime.inventory_changed.connect(_refresh)
	if not CellTaskModuleRuntime.deployment_changed.is_connected(_refresh):
		CellTaskModuleRuntime.deployment_changed.connect(_refresh)
	if not CellTaskModuleRuntime.active_tasks_changed.is_connected(_refresh):
		CellTaskModuleRuntime.active_tasks_changed.connect(_refresh)
	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)

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
	_close_task_detail_window(true)
	_cancel_overwrite_confirmation()

func _on_language_changed(_new_locale: String) -> void:
	if visible:
		_refresh()
	_clear_pending_overwrite()

func clear_selection_if_any() -> bool:
	if _cancel_overwrite_confirmation():
		return true
	if _task_detail_window != null and is_instance_valid(_task_detail_window) and _task_detail_window.visible:
		_close_task_detail_window(true)
		return true
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
		LocalizationManager.tr_key("ui.cell_management.title", "Board"),
		LocalizationManager.tr_key("ui.cell_management.subtitle", "Install cell effects or deploy task modules."),
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
	_subtitle_label.text = LocalizationManager.tr_key("ui.task_management.subtitle", "Install task modules on active cells before the next battle.")
	var view := TASK_VIEW_SCENE.instantiate() as HBoxContainer
	_content.add_child(view)
	_populate_cell_preview_grid(view.get_node("GridPanel/Margin/Grid") as GridContainer)
	_populate_task_module_side(view)
	_add_footer_back_button()

func _populate_cell_preview_grid(grid: GridContainer) -> void:
	var ids := [7, 8, 9, 4, 5, 6, 1, 2, 3]
	for id_variant in ids:
		var cell_id := int(id_variant)
		var button := DRAG_CONTROLS.WarehouseDragDropButton.new()
		button.view = self
		button.drop_payload = {"kind": "task_cell", "cell_id": cell_id}
		button.custom_minimum_size = CELL_PREVIEW_BUTTON_SIZE
		button.toggle_mode = false
		button.disabled = _board == null or not _board.is_cell_active_by_id(cell_id)
		button.text = ""
		button.add_theme_stylebox_override("normal", _make_cell_preview_style(cell_id, false, button.disabled))
		button.add_theme_stylebox_override("hover", _make_cell_preview_style(cell_id, true, button.disabled))
		button.add_theme_stylebox_override("pressed", _make_cell_preview_style(cell_id, true, button.disabled))
		button.add_theme_stylebox_override("disabled", _make_cell_preview_style(cell_id, false, true))
		button.pressed.connect(_on_cell_pressed.bind(cell_id))
		button.mouse_entered.connect(_on_cell_hovered.bind(cell_id))
		button.mouse_exited.connect(_on_cell_unhovered.bind(cell_id))
		button.add_child(_make_cell_preview_content(cell_id, button.disabled))
		grid.add_child(button)

func _populate_task_module_side(view: Control) -> void:
	var inventory := CellTaskModuleRuntime.get_inventory_snapshot()
	var deployed_count := CellTaskModuleRuntime.get_deployment_snapshot().size()
	var deploy_limit := int(CellTaskModuleRuntime.ACTIVE_LIMIT)

	var title_text := LocalizationManager.tr_format(
		"ui.task_management.ready_title",
		{"count": inventory.size()},
		"Ready To Install (%d)" % inventory.size()
	)
	var guidance := _task_management_guidance(inventory.size(), deployed_count, deploy_limit)
	view.call("set_data", title_text, guidance.status, guidance.instruction, guidance.detail, guidance.warning)
	var column := view.get_node("Side/Scroll/InventoryList") as VBoxContainer

	if inventory.is_empty():
		column.add_child(_make_muted_label(LocalizationManager.tr_key(
			"ui.task_management.empty_inventory",
			"No task modules. Complete cell objectives to earn more."
		)))
		return
	for index in range(inventory.size()):
		var module_id := str(inventory[index])
		var button := _make_task_module_card(
			module_id,
			index == _selected_inventory_index,
			{"kind": "task_inventory_module", "inventory_index": index, "module_id": module_id}
		)
		button.pressed.connect(_on_inventory_pressed.bind(index))
		column.add_child(button)

func _task_management_guidance(ready_count: int, deployed_count: int, deploy_limit: int) -> Dictionary:
	var status := LocalizationManager.tr_format(
		"ui.task_management.status",
		{"ready": ready_count, "deployed": deployed_count, "limit": deploy_limit},
		"Ready To Install: %d    Deployed: %d/%d" % [ready_count, deployed_count, deploy_limit]
	)

	var instruction_text := ""
	if _selected_inventory_index >= 0:
		instruction_text = LocalizationManager.tr_key(
			"ui.task_management.selected_hint",
			"Click a highlighted active cell to deploy. Right click to cancel selection."
		)
	else:
		instruction_text = LocalizationManager.tr_format(
			"ui.task_management.unselected_hint",
			{"limit": deploy_limit},
			"Select or drag a task module to an active cell. Up to %d tasks can be deployed for the next battle." % deploy_limit
		)
	var detail_hint := ""
	if deployed_count > 0:
		detail_hint = LocalizationManager.tr_key(
			"ui.task_management.detail_hint",
			"Hover a deployed task cell to preview details. Click to pin the detail window."
		)
	var battle_warning := LocalizationManager.tr_key(
		"ui.task_management.battle_warning",
		"Deployed tasks are consumed when battle starts. Undeployed Ready To Install tasks will be discarded."
	)
	return {"status": status, "instruction": instruction_text, "detail": detail_hint, "warning": battle_warning}

func _make_muted_label(text: String) -> Label:
	var label := DETAIL_TEXT_SCENE.instantiate() as Label
	label.call("set_data", text, Color(0.62, 0.72, 0.76, 1.0), 13)
	return label

func _add_footer_back_button() -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(spacer)
	var button := BACK_BUTTON_SCENE.instantiate() as Button
	button.call("set_data", LocalizationManager.tr_key("ui.common.back", "Back"))
	_style_button(button)
	button.pressed.connect(_on_back_pressed)
	_footer.add_child(button)

func _make_task_module_card(module_id: String, selected: bool, drag_payload: Dictionary = {}) -> Button:
	var definition := CellTaskModuleRuntime.get_definition(module_id)
	var button := TASK_MODULE_CARD_SCENE.instantiate() as Button
	_style_task_module_button(button, definition, selected)
	var rarity := definition.get_rarity() if definition != null else ""
	button.call("set_data", {
		"name": definition.get_display_name() if definition != null else module_id,
		"accent": _get_task_module_color(definition, Color(0.86, 0.96, 1.0, 1.0)),
		"task": definition.get_task_label() if definition != null else "",
		"rarity_color": RARITY_UTIL.get_color(rarity) if definition != null else Color.WHITE,
		"rarity_name": RARITY_UTIL.get_display_name(rarity) if definition != null else "",
		"show_rarity": definition != null,
		"selected": selected,
	})
	button.call("set_drag_interface", drag_payload, build_drag_data)
	return button

func _format_task_module_description(definition: TaskModuleDefinition, fallback_id: String) -> String:
	if definition == null:
		return fallback_id
	var description := definition.get_description()
	return description if description != "" else LocalizationManager.tr_key(
		"ui.task_management.default_description",
		"Deploy to an active cell for the next battle."
	)

func build_drag_data(payload: Dictionary, source_control: Control = null) -> Dictionary:
	if str(payload.get("kind", "")) != "task_inventory_module":
		return {}
	var index := _resolve_task_drag_inventory_index(payload)
	if index < 0:
		return {}
	var module_id := str(payload.get("module_id", ""))
	if source_control != null:
		source_control.set_drag_preview(_make_task_module_drag_preview(module_id))
	return {"task_module_drag": true, "payload": payload}

func can_drop_payload(target: Dictionary, data: Variant) -> bool:
	var feedback := _get_task_drag_drop_feedback(target, data)
	return bool(feedback.get("ok", false))

func drop_payload(target: Dictionary, data: Variant) -> bool:
	var feedback := _get_task_drag_drop_feedback(target, data)
	if not bool(feedback.get("ok", false)):
		if owner_ui != null:
			owner_ui.show_item_message(LocalizationManager.localize_cell_management_reason(
				str(feedback.get("reason", LocalizationManager.tr_key(
					"ui.task_management.deploy_failed",
					"Cannot deploy task module."
				)))
			), 1.6)
		return false
	var payload: Dictionary = data.get("payload", {})
	var index := _resolve_task_drag_inventory_index(payload)
	var cell_id := int(target.get("cell_id", 0))
	_selected_inventory_index = -1
	if _selected_cell_has_deployment(cell_id):
		_request_overwrite_confirmation(index, cell_id)
		return true
	var result := CellTaskModuleRuntime.deploy_inventory_module(index, cell_id, _board)
	if not bool(result.get("ok", false)) and owner_ui != null:
		owner_ui.show_item_message(LocalizationManager.localize_cell_management_reason(
			str(result.get("reason", LocalizationManager.tr_key(
				"ui.task_management.deploy_failed",
				"Cannot deploy task module."
			)))
		), 1.6)
	_refresh()
	return bool(result.get("ok", false))

func _get_task_drag_drop_feedback(target: Dictionary, data: Variant) -> Dictionary:
	if str(target.get("kind", "")) != "task_cell":
		return {"ok": false, "reason": "Drop this task module on an active cell."}
	if not (data is Dictionary) or not bool(data.get("task_module_drag", false)):
		return {"ok": false, "reason": ""}
	var payload: Dictionary = data.get("payload", {})
	var index := _resolve_task_drag_inventory_index(payload)
	if index < 0:
		return {"ok": false, "reason": "Invalid task module slot."}
	var cell_id := int(target.get("cell_id", 0))
	if _selected_cell_has_deployment(cell_id):
		return CellTaskModuleRuntime.can_replace_deployment_with_inventory_module(index, cell_id, _board)
	return CellTaskModuleRuntime.can_deploy_inventory_module(index, cell_id, _board)

func _resolve_task_drag_inventory_index(payload: Dictionary) -> int:
	if str(payload.get("kind", "")) != "task_inventory_module":
		return -1
	var index := int(payload.get("inventory_index", -1))
	var module_id := str(payload.get("module_id", ""))
	var inventory := CellTaskModuleRuntime.get_inventory_snapshot()
	if index < 0 or index >= inventory.size():
		return -1
	if str(inventory[index]) != module_id:
		return -1
	return index

func _make_task_module_drag_preview(module_id: String) -> Control:
	var definition := CellTaskModuleRuntime.get_definition(module_id)
	var preview := TASK_MODULE_DRAG_PREVIEW_SCENE.instantiate() as Control
	preview.call("set_data", "%s  [%s]" % [definition.get_display_name(), definition.get_task_label()] if definition != null else module_id, _get_task_module_color(definition, PANEL_BORDER))
	return preview

func _ensure_task_detail_window() -> void:
	if _task_detail_window != null and is_instance_valid(_task_detail_window):
		return
	_task_detail_window = TASK_DETAIL_WINDOW_SCENE.instantiate() as PanelContainer
	_task_detail_window.name = "TaskDetailWindow"
	_task_detail_window.connect("close_requested", _on_task_detail_close_requested)
	add_child(_task_detail_window)

func _show_task_detail_for_cell(cell_id: int, locked: bool = false, hover: bool = false) -> bool:
	var module_id := _get_cell_task_module_id(cell_id)
	var definition := CellTaskModuleRuntime.get_definition(module_id)
	if module_id == "" or definition == null:
		return false
	if locked:
		_locked_task_detail_cell_id = cell_id
	if hover:
		_hover_task_detail_cell_id = cell_id
	_ensure_task_detail_window()
	_rebuild_task_detail_window(cell_id, definition)
	_popup_task_detail_window(cell_id)
	return true

func _rebuild_task_detail_window(cell_id: int, definition: TaskModuleDefinition) -> void:
	_task_detail_window.call("set_data", {
		"title": LocalizationManager.tr_format(
		"ui.task_management.detail_title",
		{"cell": cell_id, "name": definition.get_display_name()},
		"Cell %d - %s" % [cell_id, definition.get_display_name()]
		),
		"rarity_color": RARITY_UTIL.get_color(definition.get_rarity()),
		"rarity_name": RARITY_UTIL.get_display_name(definition.get_rarity()),
		"task_label": definition.get_task_label(),
		"objective_heading": LocalizationManager.tr_key("ui.task_management.objective", "Objective"),
		"description": _format_task_module_description(definition, definition.module_id),
		"reward_heading": LocalizationManager.tr_key("ui.task_management.reward", "Reward"),
		"reward": LocalizationManager.tr_key(
		"ui.task_management.reward_description",
		"Complete to receive a cell task reward."
		),
		"close_text": LocalizationManager.tr_key("ui.common.close", "Close"),
	})
	_style_button(_task_detail_window.get_node("Margin/Content/Footer/CloseButton") as Button)

func _popup_task_detail_window(cell_id: int) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var detail_y := _root_panel.position.y + MANAGEMENT_PANEL_SIZE.y - TASK_DETAIL_WINDOW_SIZE.y - 30.0
	if [1, 2, 3].has(cell_id):
		detail_y = _root_panel.position.y + 82.0
	var base_position := Vector2(
		_root_panel.position.x + 24.0,
		detail_y
	)
	base_position.x = clampf(base_position.x, 12.0, maxf(12.0, viewport_size.x - TASK_DETAIL_WINDOW_SIZE.x - 12.0))
	base_position.y = clampf(base_position.y, 12.0, maxf(12.0, viewport_size.y - TASK_DETAIL_WINDOW_SIZE.y - 12.0))
	_task_detail_window.position = base_position
	_task_detail_window.size = TASK_DETAIL_WINDOW_SIZE
	_task_detail_window.visible = true

func _close_task_detail_window(clear_lock: bool = true) -> void:
	if clear_lock:
		_locked_task_detail_cell_id = 0
		_hover_task_detail_cell_id = 0
	if _task_detail_window != null and is_instance_valid(_task_detail_window):
		_task_detail_window.hide()

func _on_task_detail_close_requested() -> void:
	_close_task_detail_window(true)

func _make_cell_preview_content(cell_id: int, disabled: bool) -> Control:
	var preview := TASK_CELL_PREVIEW_SCENE.instantiate() as Control
	preview.call("set_data", LocalizationManager.tr_format(
		"ui.task_management.cell_label",
		{"cell": cell_id},
		"Cell %d" % cell_id
	), _get_cell_terrain_texture(cell_id), _format_cell_preview_status(cell_id, disabled), _get_cell_task_color(cell_id, Color(0.66, 0.78, 0.82, 1.0)))
	return preview

func _format_cell_preview_status(cell_id: int, disabled: bool) -> String:
	var module_id := _get_cell_task_module_id(cell_id)
	if module_id == "":
		return LocalizationManager.tr_key(
			"ui.task_management.locked",
			"Locked"
		) if disabled else LocalizationManager.tr_key(
			"ui.task_management.available",
			"Available"
		)
	var definition := CellTaskModuleRuntime.get_definition(module_id)
	if definition == null:
		return module_id
	return definition.get_task_label()

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
			terrain_type = int(cell.terrain_type) as Cell.TerrainType
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
		style.border_color = _get_cell_task_color(cell_id, Color(0.44, 0.85, 0.52, 1.0))
	elif _selected_inventory_index >= 0:
		style.bg_color = Color(0.10, 0.15, 0.14, 0.96)
		style.border_color = Color(0.78, 0.92, 0.58, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	elif hover:
		style.bg_color = Color(0.10, 0.15, 0.18, 0.96)
		style.border_color = Color(0.50, 0.76, 0.92, 1.0)
	return style

func _get_cell_task_color(cell_id: int, fallback: Color) -> Color:
	var module_id := _get_cell_task_module_id(cell_id)
	if module_id == "":
		return fallback
	var definition := CellTaskModuleRuntime.get_definition(module_id)
	if definition == null:
		return fallback
	return RARITY_UTIL.get_color(definition.get_rarity())

func _get_task_module_color(definition: TaskModuleDefinition, fallback: Color) -> Color:
	if definition == null:
		return fallback
	return RARITY_UTIL.get_color(definition.get_rarity())

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

func _style_task_module_button(button: Button, definition: TaskModuleDefinition, selected: bool = false) -> void:
	_style_button(button)
	if definition == null:
		return
	var rarity_color: Color = RARITY_UTIL.get_color(definition.get_rarity())
	button.add_theme_color_override("font_color", rarity_color)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(state)
		var flat := style.duplicate() as StyleBoxFlat if style is StyleBoxFlat else null
		if flat == null:
			flat = _make_panel_style(Color(0.08, 0.12, 0.16, 0.94), rarity_color, 7)
		flat.border_color = rarity_color
		if selected and (state == "normal" or state == "pressed" or state == "focus"):
			flat.bg_color = Color(0.10, 0.18, 0.16, 0.98)
		if state == "disabled":
			flat.bg_color = Color(0.06, 0.07, 0.075, 0.92)
			flat.border_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.65)
		button.add_theme_stylebox_override(state, flat)

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
	_close_task_detail_window(true)
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
		_show_task_detail_for_cell(cell_id, true, false)
		return
	if _selected_cell_has_deployment(cell_id):
		_request_overwrite_confirmation(_selected_inventory_index, cell_id)
		return
	var result := CellTaskModuleRuntime.deploy_inventory_module(_selected_inventory_index, cell_id, _board)
	if not bool(result.get("ok", false)) and owner_ui != null:
		owner_ui.show_item_message(LocalizationManager.localize_cell_management_reason(
			str(result.get("reason", LocalizationManager.tr_key(
				"ui.task_management.deploy_failed",
				"Cannot deploy task module."
			)))
		), 1.6)
	_selected_inventory_index = -1
	_refresh()

func _on_cell_hovered(cell_id: int) -> void:
	_show_task_detail_for_cell(cell_id, false, true)

func _on_cell_unhovered(cell_id: int) -> void:
	if _hover_task_detail_cell_id != cell_id:
		return
	_hover_task_detail_cell_id = 0
	if _locked_task_detail_cell_id > 0:
		_show_task_detail_for_cell(_locked_task_detail_cell_id, false, false)
	else:
		_close_task_detail_window(false)

func _request_overwrite_confirmation(index: int, cell_id: int) -> void:
	var validation := CellTaskModuleRuntime.can_replace_deployment_with_inventory_module(index, cell_id, _board)
	if not bool(validation.get("ok", false)):
		if owner_ui != null:
			owner_ui.show_item_message(LocalizationManager.localize_cell_management_reason(
				str(validation.get("reason", LocalizationManager.tr_key(
					"ui.task_management.replace_failed",
					"Cannot replace task module."
				)))
			), 1.6)
		return
	_pending_overwrite_inventory_index = index
	_pending_overwrite_cell_id = cell_id
	var inventory := CellTaskModuleRuntime.get_inventory_snapshot()
	var new_module_id := str(inventory[index])
	_pending_overwrite_module_id = new_module_id
	var old_module_id := _get_cell_task_module_id(cell_id)
	if owner_ui == null:
		_clear_pending_overwrite()
		return
	var opened := owner_ui.request_confirmation(
		&"cell_task_module_overwrite",
		LocalizationManager.tr_key("ui.task_module.replace_title", "Replace Task Module"),
		LocalizationManager.tr_format(
			"ui.task_module.cell_replace_warning",
			{
				"cell": cell_id,
				"current": _format_task_module_for_dialog(old_module_id),
				"new": _format_task_module_for_dialog(new_module_id)
			},
			"Cell %d already has a task module.\n\nCurrent: %s\nNew: %s\n\nReplace the current module? The old module will be discarded." % [
				cell_id,
				_format_task_module_for_dialog(old_module_id),
				_format_task_module_for_dialog(new_module_id)
			]
		),
		LocalizationManager.tr_key("ui.task_module.replace_action", "Replace"),
		LocalizationManager.tr_key("ui.common.cancel", "Cancel"),
		Callable(self, "_on_overwrite_confirmed"),
		Callable(self, "_on_overwrite_cancelled"),
		true,
		Vector2i(560, 300)
	)
	if not opened:
		_clear_pending_overwrite()

func _on_overwrite_confirmed(_dialog_id: StringName = &"") -> void:
	if not _pending_overwrite_inventory_matches():
		if owner_ui != null:
			owner_ui.show_item_message(LocalizationManager.tr_key(
				"ui.task_management.selection_unavailable",
				"Selected task module is no longer available."
			), 1.6)
		_clear_pending_overwrite()
		_selected_inventory_index = -1
		_refresh()
		return
	var result := CellTaskModuleRuntime.replace_deployment_with_inventory_module(
		_pending_overwrite_inventory_index,
		_pending_overwrite_cell_id,
		_board
	)
	if not bool(result.get("ok", false)) and owner_ui != null:
		owner_ui.show_item_message(LocalizationManager.localize_cell_management_reason(
			str(result.get("reason", LocalizationManager.tr_key(
				"ui.task_management.replace_failed",
				"Cannot replace task module."
			)))
		), 1.6)
	_clear_pending_overwrite()
	_selected_inventory_index = -1
	_refresh()

func _on_overwrite_cancelled(_dialog_id: StringName = &"") -> void:
	_clear_pending_overwrite()

func _cancel_overwrite_confirmation() -> bool:
	if _pending_overwrite_inventory_index < 0:
		return false
	if owner_ui != null:
		owner_ui.cancel_visible_dialog()
	_clear_pending_overwrite()
	return true

func _clear_pending_overwrite() -> void:
	_pending_overwrite_inventory_index = -1
	_pending_overwrite_module_id = ""
	_pending_overwrite_cell_id = 0

func _pending_overwrite_inventory_matches() -> bool:
	var inventory := CellTaskModuleRuntime.get_inventory_snapshot()
	if _pending_overwrite_inventory_index < 0 or _pending_overwrite_inventory_index >= inventory.size():
		return false
	return str(inventory[_pending_overwrite_inventory_index]) == _pending_overwrite_module_id

func _format_task_module_for_dialog(module_id: String) -> String:
	var definition := CellTaskModuleRuntime.get_definition(module_id)
	if definition == null:
		return module_id
	return "%s / %s" % [definition.get_task_label(), definition.get_display_name()]
