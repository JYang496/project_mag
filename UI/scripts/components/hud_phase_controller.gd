extends RefCounted
class_name HudPhaseController

const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")
const FADE_SECONDS := 0.16

var owner_ui: UI
var phase_dock: PanelContainer
var phase_label: Label
var _last_signature := ""
var _visibility_tweens: Dictionary = {}


func bind(ui: UI) -> void:
	owner_ui = ui
	_ensure_phase_dock()
	refresh(false)


static func visibility_for(
	phase: String,
	primary_menu_open: bool = false,
	secondary_menu_open: bool = false
) -> Dictionary:
	var battle := phase == PhaseManager.BATTLE
	var prepare := phase == PhaseManager.REST
	var settlement := phase == PhaseManager.SETTLEMENT
	var protocol_selection := phase == PhaseManager.PROTOCOL_SELECTION
	var battle_starting := phase == PhaseManager.BATTLE_STARTING
	var game_over := phase in [PhaseManager.GAMEOVER, PhaseManager.RUN_COMPLETE]
	return {
		"battle_hud": prepare or battle,
		"phase_dock": prepare or settlement or protocol_selection or battle_starting or battle,
		"gold": prepare or settlement,
		"character_status": battle,
		"combat_resources": battle,
		"weapon_selector": prepare or battle,
		"objectives": battle,
		"utility": not game_over,
		"world_hud_alpha": 0.42 if prepare and (primary_menu_open or secondary_menu_open) else 1.0,
	}


func refresh(animated: bool = true) -> void:
	if owner_ui == null or not is_instance_valid(owner_ui):
		return
	var phase := PhaseManager.current_state()
	var primary_open := owner_ui._is_primary_menu_open()
	var secondary_open := owner_ui._is_secondary_menu_open()
	var signature := "%s|%s|%s" % [phase, str(primary_open), str(secondary_open)]
	if signature == _last_signature:
		return
	_last_signature = signature
	var state := visibility_for(phase, primary_open, secondary_open)
	_set_visible(owner_ui.battle_hud, bool(state.battle_hud), animated)
	_set_visible(phase_dock, bool(state.phase_dock), animated)
	_set_visible(owner_ui.gold_label, bool(state.gold), animated)
	_set_visible(owner_ui.hp_label_label, bool(state.character_status), animated)
	_set_visible(owner_ui.weapon_selector, bool(state.weapon_selector), animated)
	_set_visible(owner_ui.left_contract_hud_stack, bool(state.objectives), animated)
	_set_visible(owner_ui.right_hud_stack, bool(state.utility), animated)
	if owner_ui.hud_presenter != null:
		_set_visible(owner_ui.hud_presenter.combat_resource_slot_container, bool(state.combat_resources), animated)
		_set_visible(owner_ui.hud_presenter.special_resource_slot_container, bool(state.combat_resources), animated)
	var world_alpha := float(state.world_hud_alpha)
	if owner_ui.weapon_selector != null:
		owner_ui.weapon_selector.modulate.a = world_alpha
	_update_phase_text(phase)


func invalidate() -> void:
	_last_signature = ""

func set_reward_modal_focus(active: bool) -> void:
	if phase_label != null and is_instance_valid(phase_label):
		phase_label.modulate.a = 0.35 if active else 1.0


func layout(viewport_size: Vector2) -> void:
	if phase_dock == null:
		return
	var margin := UiLayoutPolicy.safe_margin(viewport_size)
	phase_dock.position = margin
	phase_dock.size = Vector2(320.0, 42.0)


func _ensure_phase_dock() -> void:
	if owner_ui == null or phase_dock != null:
		return
	phase_dock = PanelContainer.new()
	phase_dock.name = "PhaseDock"
	phase_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_dock.z_index = 45
	phase_dock.add_theme_stylebox_override("panel", _build_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 4)
	phase_dock.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	phase_label = Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TOKENS.style_label(phase_label, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_PRIMARY)
	row.add_child(phase_label)
	owner_ui.gui_root.add_child(phase_dock)
	if owner_ui.gold_label != null and owner_ui.gold_label.get_parent() != row:
		owner_ui.gold_label.reparent(row)
		owner_ui.gold_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		owner_ui.gold_label.custom_minimum_size = Vector2(112.0, 34.0)
	layout(owner_ui.get_viewport().get_visible_rect().size)


func _update_phase_text(phase: String) -> void:
	if phase_label == null:
		return
	match phase:
		PhaseManager.BATTLE:
			phase_label.text = LocalizationManager.tr_key("ui.tutorial.state.battle", "Current: Battle")
		PhaseManager.PREPARE:
			phase_label.text = LocalizationManager.tr_key("ui.tutorial.state.rest", "Current: Rest Area")
		PhaseManager.SETTLEMENT:
			phase_label.text = LocalizationManager.tr_key("ui.phase.settlement", "Current: Reward Settlement")
		PhaseManager.PROTOCOL_SELECTION:
			phase_label.text = LocalizationManager.tr_key("ui.phase.protocol_selection", "Current: Protocol Selection")
		PhaseManager.BATTLE_STARTING:
			phase_label.text = LocalizationManager.tr_key("ui.phase.battle_starting", "Current: Deploying")
		_:
			phase_label.text = ""


func _set_visible(node: CanvasItem, should_show: bool, animated: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	var key := node.get_instance_id()
	var old_tween := _visibility_tweens.get(key) as Tween
	var was_transitioning := old_tween != null and old_tween.is_valid()
	if was_transitioning:
		old_tween.kill()
	_visibility_tweens.erase(key)
	if not animated or not owner_ui.is_inside_tree():
		node.visible = should_show
		node.modulate.a = 1.0
		return
	if should_show:
		# Menu signature changes do not necessarily change HUD visibility. Keep an
		# already-visible node stable instead of replaying its fade-in.
		if node.visible and not was_transitioning:
			return
		if not node.visible:
			node.visible = true
			node.modulate.a = 0.0
		var show_tween := owner_ui.create_tween()
		show_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		show_tween.tween_property(node, "modulate:a", 1.0, FADE_SECONDS)
		_visibility_tweens[key] = show_tween
	else:
		if not node.visible:
			return
		var hide_tween := owner_ui.create_tween()
		hide_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		hide_tween.tween_property(node, "modulate:a", 0.0, FADE_SECONDS)
		hide_tween.tween_callback(_finish_hide.bind(node, key))
		_visibility_tweens[key] = hide_tween


func _finish_hide(node: CanvasItem, key: int) -> void:
	if node != null and is_instance_valid(node):
		node.visible = false
		node.modulate.a = 1.0
	_visibility_tweens.erase(key)


func _build_panel_style() -> StyleBoxFlat:
	var style := TOKENS.make_panel_style(true, TOKENS.COLOR_BORDER)
	style.bg_color = Color(0.025, 0.07, 0.10, 0.90)
	style.border_color = Color(0.25, 0.68, 0.82, 0.72)
	style.set_corner_radius_all(5)
	return style
