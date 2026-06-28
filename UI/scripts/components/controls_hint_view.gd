extends Panel
class_name ControlsHintView

const CONTROLS_HINT_PANEL_SIZE := Vector2(360, 156)
const CONTROLS_HINT_PANEL_MARGIN := Vector2(16, 16)

@onready var title_label: Label = $Title
@onready var body_label: Label = $Body

var _current_phase: String = ""
var _primary_menu_open := false
var _secondary_menu_context: StringName = &""

func layout_for_viewport(viewport_size: Vector2) -> void:
	var width := minf(CONTROLS_HINT_PANEL_SIZE.x, viewport_size.x - 2.0 * CONTROLS_HINT_PANEL_MARGIN.x)
	var height := CONTROLS_HINT_PANEL_SIZE.y
	size = Vector2(maxf(width, 260.0), height)
	position = Vector2(
		viewport_size.x - size.x - CONTROLS_HINT_PANEL_MARGIN.x,
		CONTROLS_HINT_PANEL_MARGIN.y
	)
	title_label.position = Vector2(14.0, 10.0)
	title_label.size = Vector2(size.x - 28.0, 28.0)
	body_label.position = Vector2(14.0, 40.0)
	body_label.size = Vector2(size.x - 28.0, size.y - 50.0)

func refresh_for_phase(phase: String, primary_menu_open: bool, secondary_menu_context: StringName = &"") -> void:
	_current_phase = phase
	_primary_menu_open = primary_menu_open
	_secondary_menu_context = _normalize_secondary_menu_context(secondary_menu_context)
	_render_current_context()

func refresh_visibility(primary_menu_open: bool, secondary_menu_context: StringName = &"") -> void:
	_current_phase = PhaseManager.current_state()
	_primary_menu_open = primary_menu_open
	_secondary_menu_context = _normalize_secondary_menu_context(secondary_menu_context)
	_render_current_context()

func _render_current_context() -> void:
	if _current_phase == PhaseManager.GAMEOVER:
		visible = false
		return
	visible = true
	if _secondary_menu_context != &"":
		_render_secondary_menu_hint(_secondary_menu_context)
		return
	if _primary_menu_open:
		title_label.text = LocalizationManager.tr_key("ui.tutorial.state.primary_menu", "Current: Primary Menu")
		var primary_menu_lines := PackedStringArray([
			LocalizationManager.tr_key("ui.tutorial.panel.primary_menu.line1", "[LMB] Click buttons"),
			LocalizationManager.tr_key("ui.tutorial.panel.primary_menu.line2", "[RMB] Exit current menu")
		])
		body_label.text = "\n".join(primary_menu_lines)
		return
	if _current_phase == PhaseManager.BATTLE:
		title_label.text = LocalizationManager.tr_key("ui.tutorial.state.battle", "Current: Battle")
		var battle_lines := PackedStringArray([
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line1", "[W][A][S][D] Move"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line2", "[LMB] Attack"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line3", "[Space] Skill"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line4", "[R] Reload"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line5", "[Q/E] Switch Weapon  [Esc] Pause")
		])
		body_label.text = "\n".join(battle_lines)
		return
	title_label.text = LocalizationManager.tr_key("ui.tutorial.state.rest", "Current: Rest Area")
	var rest_lines := PackedStringArray([
		LocalizationManager.tr_key("ui.tutorial.panel.rest.line1", "[LMB] Click menu and zones"),
		LocalizationManager.tr_key("ui.tutorial.panel.rest.line2", "[LMB Hold Center] Start battle"),
		LocalizationManager.tr_key("ui.tutorial.panel.rest.line3", "[Esc] Pause")
	])
	body_label.text = "\n".join(rest_lines)

func _render_secondary_menu_hint(context: StringName) -> void:
	match context:
		&"purchase":
			title_label.text = LocalizationManager.tr_key("ui.tutorial.state.secondary.purchase", "Current: Shop")
			body_label.text = "\n".join(PackedStringArray([
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.purchase.line1", "[LMB] Click an item to inspect it"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.purchase.line2", "Confirm to buy the selected item"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.purchase.line3", "[RMB] Return  [Esc] Pause / Cancel")
			]))
		&"upgrade":
			title_label.text = LocalizationManager.tr_key("ui.tutorial.state.secondary.upgrade", "Current: Upgrade")
			body_label.text = "\n".join(PackedStringArray([
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.upgrade.line1", "[LMB] Select a weapon or module"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.upgrade.line2", "Confirm the cost to upgrade"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.upgrade.line3", "[RMB] Return  [Esc] Pause / Cancel")
			]))
		&"warehouse":
			title_label.text = LocalizationManager.tr_key("ui.tutorial.state.secondary.warehouse", "Current: Warehouse")
			body_label.text = "\n".join(PackedStringArray([
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.warehouse.line1", "[LMB] Click weapons and modules"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.warehouse.line2", "[Drag] Manage warehouse equipment"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.warehouse.line3", "[RMB] Return  [Esc] Pause / Cancel")
			]))
		&"grid_management":
			title_label.text = LocalizationManager.tr_key("ui.tutorial.state.secondary.grid_management", "Current: Grid Management")
			body_label.text = "\n".join(PackedStringArray([
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.grid_management.line1", "[LMB] Select a cell effect"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.grid_management.line2", "Click or drag it onto an active cell"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.grid_management.line3", "Battle start consumes pending edits"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.grid_management.line4", "[RMB] Return  [Esc] Pause / Cancel")
			]))
		&"task_management":
			title_label.text = LocalizationManager.tr_key("ui.tutorial.state.secondary.task_management", "Current: Task Management")
			body_label.text = "\n".join(PackedStringArray([
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.task_management.line1", "[LMB] Select a task module"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.task_management.line2", "Click or drag it onto an active cell"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.task_management.line3", "Battle start consumes deployed tasks"),
				LocalizationManager.tr_key("ui.tutorial.panel.secondary.task_management.line4", "[RMB] Return  [Esc] Pause / Cancel")
			]))

func _normalize_secondary_menu_context(context: StringName) -> StringName:
	match context:
		&"purchase", &"upgrade", &"warehouse", &"grid_management", &"task_management":
			return context
		&"shop":
			return &"purchase"
		&"grid":
			return &"grid_management"
		&"task":
			return &"task_management"
		_:
			return &""
