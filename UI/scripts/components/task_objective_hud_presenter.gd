extends RefCounted
class_name TaskObjectiveHudPresenter

const MAX_CARDS := 2
const PANEL_SIZE := Vector2(248.0, 144.0)
const CARD_SIZE := Vector2(232.0, 64.0)
const REFRESH_INTERVAL := 0.12

var owner_ui: Node
var parent_root: Control
var panel: PanelContainer
var card_list: VBoxContainer
var rows: Array[Dictionary] = []
var _refresh_timer := 0.0
var _dirty := true

func bind(ui: Node, root: Control) -> void:
	owner_ui = ui
	parent_root = root
	_connect_runtime_signals()
	ensure_panel()
	refresh(true)

func ensure_panel() -> PanelContainer:
	if panel != null and is_instance_valid(panel):
		return panel
	if parent_root == null or not is_instance_valid(parent_root):
		return null
	panel = PanelContainer.new()
	panel.name = "TaskObjectiveHud"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.visible = false
	panel.z_index = 40
	panel.add_theme_stylebox_override("panel", _build_panel_style())
	parent_root.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	card_list = VBoxContainer.new()
	card_list.name = "CardList"
	card_list.add_theme_constant_override("separation", 4)
	margin.add_child(card_list)

	while rows.size() < MAX_CARDS:
		rows.append(_create_card())
	return panel

func layout(viewport_size: Vector2) -> void:
	ensure_panel()
	if panel == null:
		return
	panel.size = PANEL_SIZE
	var x: float = maxf(12.0, viewport_size.x - PANEL_SIZE.x - 16.0)
	panel.position = Vector2(x, 116.0)

func mark_dirty() -> void:
	_dirty = true

func refresh_if_needed(delta: float) -> bool:
	_refresh_timer += maxf(delta, 0.0)
	var should_refresh: bool = _dirty
	if not should_refresh and panel != null and panel.visible:
		should_refresh = _refresh_timer >= REFRESH_INTERVAL
	if not should_refresh:
		return false
	refresh(false)
	return true

func refresh(force: bool = false) -> void:
	ensure_panel()
	if panel == null:
		return
	_refresh_timer = 0.0
	_dirty = false
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		_hide_cards()
		return
	if not CellTaskModuleRuntime.has_method("get_active_task_statuses"):
		_hide_cards()
		return
	var board: Variant = owner_ui._find_board() if owner_ui != null and owner_ui.has_method("_find_board") else null
	var result: Variant = CellTaskModuleRuntime.call("get_active_task_statuses", board)
	if not (result is Array):
		_hide_cards()
		return
	var statuses: Array = (result as Array).slice(0, MAX_CARDS)
	if statuses.is_empty():
		_hide_cards()
		return
	panel.visible = true
	for index in range(rows.size()):
		var row := rows[index]
		var root := row.get("root", null) as Control
		if root == null:
			continue
		if index >= statuses.size() or not (statuses[index] is Dictionary):
			root.visible = false
			continue
		root.visible = true
		_apply_status(row, statuses[index] as Dictionary)
	if force and owner_ui != null:
		layout(owner_ui.get_viewport().get_visible_rect().size)

func _hide_cards() -> void:
	if panel != null:
		panel.visible = false
	for row in rows:
		var root := row.get("root", null) as Control
		if root != null:
			root.visible = false

func _create_card() -> Dictionary:
	var card: PanelContainer = PanelContainer.new()
	card.name = "TaskCard"
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _build_card_style(Color(0.12, 0.17, 0.20, 0.92), Color(0.36, 0.54, 0.62, 0.95)))
	card_list.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 4)
	margin.add_child(body)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)

	var marker: ColorRect = ColorRect.new()
	marker.name = "Marker"
	marker.custom_minimum_size = Vector2(10.0, 10.0)
	marker.size = Vector2(10.0, 10.0)
	header.add_child(marker)

	var label: Label = Label.new()
	label.name = "Label"
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(96.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 12)
	header.add_child(label)

	var value: Label = Label.new()
	value.name = "Value"
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(66.0, 0.0)
	value.add_theme_font_size_override("font_size", 11)
	header.add_child(value)

	var instruction: Label = Label.new()
	instruction.name = "Instruction"
	instruction.clip_text = true
	instruction.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	instruction.custom_minimum_size = Vector2(0.0, 14.0)
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction.add_theme_font_size_override("font_size", 11)
	instruction.add_theme_color_override("font_color", Color(0.78, 0.86, 0.88, 0.95))
	body.add_child(instruction)

	var progress: ProgressBar = ProgressBar.new()
	progress.name = "Progress"
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.step = 0.001
	progress.value = 0.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0.0, 6.0)
	progress.add_theme_stylebox_override("background", _build_progress_style(Color(0.05, 0.07, 0.08, 0.9)))
	progress.add_theme_stylebox_override("fill", _build_progress_style(Color(0.35, 0.84, 0.70, 0.95)))
	body.add_child(progress)

	return {
		"root": card,
		"marker": marker,
		"label": label,
		"value": value,
		"instruction": instruction,
		"progress": progress,
	}

func _apply_status(row: Dictionary, status: Dictionary) -> void:
	var root := row.get("root", null) as PanelContainer
	var marker := row.get("marker", null) as ColorRect
	var label := row.get("label", null) as Label
	var value := row.get("value", null) as Label
	var instruction := row.get("instruction", null) as Label
	var progress := row.get("progress", null) as ProgressBar
	if root == null or marker == null or label == null or value == null or instruction == null or progress == null:
		return

	var state: String = str(status.get("state", "active")).strip_edges().to_lower()
	var display_label: String = _sanitize_display_text(str(status.get("label", "")), "Task")
	var instruction_text: String = _sanitize_instruction_text(str(status.get("instruction", "")))
	var value_text: String = _sanitize_display_text(str(status.get("value_text", "")), "")
	var progress_value: float = clampf(float(status.get("progress", 0.0)), 0.0, 1.0)

	label.text = display_label
	instruction.text = instruction_text
	instruction.visible = instruction_text != ""
	value.text = value_text
	progress.value = progress_value
	marker.color = _marker_color(str(status.get("icon_key", status.get("type", ""))), state)
	_apply_state_visual(root, progress, state)

func _sanitize_display_text(text: String, fallback: String) -> String:
	var clean: String = text.strip_edges().replace("\n", " ")
	var lower: String = clean.to_lower()
	if clean == "" or lower.contains("quest:") or lower.contains("remaining"):
		return fallback
	if clean.length() > 24:
		return clean.substr(0, 23) + "..."
	return clean

func _sanitize_instruction_text(text: String) -> String:
	var clean: String = text.strip_edges().replace("\n", " ")
	var lower: String = clean.to_lower()
	if clean == "" or lower.contains("quest:") or lower.contains("remaining"):
		return ""
	if clean.length() > 36:
		return clean.substr(0, 35) + "..."
	return clean

func _apply_state_visual(root: PanelContainer, progress: ProgressBar, state: String) -> void:
	var completed: bool = state == "complete" or state == "completed"
	var dimmed: bool = state == "waiting" or state == "blocked"
	if completed:
		root.modulate = Color(0.70, 0.88, 0.75, 0.82)
		root.add_theme_stylebox_override("panel", _build_card_style(Color(0.07, 0.12, 0.09, 0.68), Color(0.34, 0.62, 0.42, 0.62)))
		progress.add_theme_stylebox_override("fill", _build_progress_style(Color(0.42, 0.78, 0.48, 0.78)))
	elif dimmed:
		root.modulate = Color(0.72, 0.76, 0.78, 0.82)
		root.add_theme_stylebox_override("panel", _build_card_style(Color(0.08, 0.10, 0.12, 0.72), Color(0.24, 0.31, 0.35, 0.68)))
		progress.add_theme_stylebox_override("fill", _build_progress_style(Color(0.38, 0.48, 0.52, 0.9)))
	else:
		root.modulate = Color(1.0, 1.0, 1.0, 1.0)
		root.add_theme_stylebox_override("panel", _build_card_style(Color(0.08, 0.11, 0.13, 0.74), Color(0.30, 0.46, 0.54, 0.78)))
		progress.add_theme_stylebox_override("fill", _build_progress_style(Color(0.35, 0.84, 0.70, 0.95)))

func _marker_color(key: String, state: String) -> Color:
	if state == "complete" or state == "completed":
		return Color(0.58, 1.0, 0.55, 1.0)
	if state == "waiting" or state == "blocked":
		return Color(0.45, 0.52, 0.56, 1.0)
	var hash_value: int = absi(hash(key))
	var hue: float = float(hash_value % 1000) / 1000.0
	return Color.from_hsv(hue, 0.42, 0.92, 1.0)

func _build_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.045, 0.48)
	style.border_color = Color(0.22, 0.32, 0.38, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _build_card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _build_progress_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style

func _connect_runtime_signals() -> void:
	var dirty_callable: Callable = Callable(self, "_on_task_status_invalidated")
	if not PhaseManager.phase_changed.is_connected(dirty_callable):
		PhaseManager.phase_changed.connect(dirty_callable)
	if not CellTaskModuleRuntime.active_tasks_changed.is_connected(dirty_callable):
		CellTaskModuleRuntime.active_tasks_changed.connect(dirty_callable)
	if not CellTaskModuleRuntime.completed_tasks_changed.is_connected(dirty_callable):
		CellTaskModuleRuntime.completed_tasks_changed.connect(dirty_callable)

func _on_task_status_invalidated(_arg: Variant = null) -> void:
	mark_dirty()
	refresh(true)
