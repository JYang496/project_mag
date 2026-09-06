extends RefCounted
class_name TaskObjectiveHudPresenter

const HUD_SCENE := preload("res://UI/components/TaskObjectiveHud/TaskObjectiveHud.tscn")
const CARD_SCENE := preload("res://UI/components/TaskObjectiveCard/TaskObjectiveCard.tscn")

const MAX_CARDS := 2
const PANEL_SIZE := Vector2(232.0, 136.0)
const BOSS_PANEL_SIZE := Vector2(232.0, 58.0)
const CARD_SIZE := Vector2(216.0, 60.0)
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
	panel = HUD_SCENE.instantiate() as PanelContainer
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.visible = false
	panel.z_index = 40
	parent_root.add_child(panel)
	card_list = panel.get_node("Margin/CardList") as VBoxContainer

	while rows.size() < MAX_CARDS:
		rows.append(_create_card())
	return panel

func layout(viewport_size: Vector2) -> void:
	ensure_panel()
	if panel == null:
		return
	var boss_hud_active := owner_ui != null \
		and not owner_ui.get_tree().get_nodes_in_group(&"boss_hud_active").is_empty()
	var target_size := BOSS_PANEL_SIZE if boss_hud_active else PANEL_SIZE
	panel.size = target_size
	if panel.get_parent() is Container:
		panel.custom_minimum_size = target_size
		panel.size_flags_horizontal = Control.SIZE_SHRINK_END
		return
	var x: float = maxf(12.0, viewport_size.x - target_size.x - 16.0)
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
	var boss_hud_active := not owner_ui.get_tree().get_nodes_in_group(&"boss_hud_active").is_empty()
	var visible_limit := 1 if boss_hud_active else MAX_CARDS
	var statuses: Array = (result as Array).slice(0, visible_limit)
	if statuses.is_empty():
		_hide_cards()
		return
	panel.visible = true
	var target_size := BOSS_PANEL_SIZE if boss_hud_active else PANEL_SIZE
	panel.custom_minimum_size = target_size
	panel.size = target_size
	for index in range(rows.size()):
		var row := rows[index]
		var root := row.get("root", null) as Control
		if root == null:
			continue
		if index >= statuses.size() or not (statuses[index] is Dictionary):
			root.visible = false
			continue
		root.visible = true
		root.call("set_data", statuses[index] as Dictionary, boss_hud_active)
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
	var card := CARD_SCENE.instantiate() as PanelContainer
	card_list.add_child(card)
	return {"root": card}

func _apply_status(row: Dictionary, status: Dictionary, compact: bool = false) -> void:
	var root := row.get("root", null) as PanelContainer
	var marker := row.get("marker", null) as Label
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
	instruction.visible = not compact and instruction_text != ""
	progress.visible = not compact
	value.text = value_text
	progress.call("set_target_value", progress_value)
	_apply_marker_icon(marker, str(status.get("icon_key", status.get("type", ""))), state)
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

func _apply_marker_icon(marker: Label, key: String, state: String) -> void:
	if marker == null:
		return
	var color := _marker_color(key, state)
	marker.text = _marker_text(key)
	marker.tooltip_text = _marker_tooltip(key)
	marker.add_theme_stylebox_override("normal", _build_marker_style(color))

func _marker_color(key: String, state: String) -> Color:
	if state == "complete" or state == "completed":
		return Color(0.58, 1.0, 0.55, 1.0)
	if state == "waiting" or state == "blocked":
		return Color(0.45, 0.52, 0.56, 1.0)
	match key.strip_edges().to_lower():
		"kill", "offense":
			return Color(0.96, 0.42, 0.32, 1.0)
		"hold", "defense":
			return Color(0.38, 0.72, 1.0, 1.0)
		"clear":
			return Color(0.58, 0.84, 0.46, 1.0)
		"hunt":
			return Color(0.92, 0.62, 0.26, 1.0)
		"dodge":
			return Color(0.72, 0.56, 1.0, 1.0)
		_:
			return Color(0.54, 0.64, 0.72, 1.0)

func _marker_text(key: String) -> String:
	match key.strip_edges().to_lower():
		"kill", "offense":
			return "K"
		"hold", "defense":
			return "H"
		"clear":
			return "C"
		"hunt":
			return "E"
		"dodge":
			return "D"
		_:
			return "?"

func _marker_tooltip(key: String) -> String:
	match key.strip_edges().to_lower():
		"kill", "offense":
			return "Kill"
		"hold", "defense":
			return "Hold"
		"clear":
			return "Clear"
		"hunt":
			return "Hunt"
		"dodge":
			return "Dodge"
		_:
			return "Task"

func _build_marker_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.20)
	style.border_color = Color(color.r, color.g, color.b, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

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
