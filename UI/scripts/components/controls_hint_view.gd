extends Panel
class_name ControlsHintView

const CONTROLS_HINT_PANEL_SIZE := Vector2(360, 156)
const CONTROLS_HINT_PANEL_MARGIN := Vector2(16, 16)

@onready var title_label: Label = $Title
@onready var body_label: Label = $Body

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

func refresh_for_phase(phase: String, primary_menu_open: bool, secondary_menu_open: bool) -> void:
	if phase == PhaseManager.GAMEOVER:
		visible = false
		return
	visible = not secondary_menu_open
	if not visible:
		return
	if primary_menu_open:
		title_label.text = LocalizationManager.tr_key("ui.tutorial.state.primary_menu", "Current: Primary Menu")
		var primary_menu_lines := PackedStringArray([
			LocalizationManager.tr_key("ui.tutorial.panel.primary_menu.line1", "[LMB] Click buttons"),
			LocalizationManager.tr_key("ui.tutorial.panel.primary_menu.line2", "[RMB] Exit current menu")
		])
		body_label.text = "\n".join(primary_menu_lines)
		return
	if phase == PhaseManager.BATTLE:
		title_label.text = LocalizationManager.tr_key("ui.tutorial.state.battle", "Current: Battle")
		var battle_lines := PackedStringArray([
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line1", "[W][A][S][D] Move"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line2", "[LMB] Attack"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line3", "[Space] Skill"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line4", "[R] Weapon Skill"),
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

func refresh_visibility(secondary_menu_open: bool) -> void:
	if PhaseManager.current_state() == PhaseManager.GAMEOVER:
		visible = false
		return
	visible = not secondary_menu_open
