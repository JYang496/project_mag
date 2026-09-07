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
