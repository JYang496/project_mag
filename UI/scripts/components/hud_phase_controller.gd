extends RefCounted
class_name HudPhaseController

const PHASE_DOCK_SCENE := preload("res://UI/components/PhaseDock/PhaseDock.tscn")
const FADE_SECONDS := 0.16

var owner_ui: UI
var phase_dock: PanelContainer
var phase_label: Label
var _last_signature := ""
var _visibility_tweens: Dictionary = {}
var _selection_modal_active := false


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
	var signature := "%s|%s|%s|%s" % [phase, str(primary_open), str(secondary_open), str(_selection_modal_active)]
	if signature == _last_signature:
		return
	_last_signature = signature
	var state := visibility_for(phase, primary_open, secondary_open)
	_set_visible(owner_ui.battle_hud, bool(state.battle_hud), animated)
	_set_visible(phase_dock, bool(state.phase_dock) and not _selection_modal_active, animated)
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

func set_selection_modal_focus(active: bool) -> void:
	if _selection_modal_active == active:
		return
	_selection_modal_active = active
	invalidate()
	refresh(false)


func layout(viewport_size: Vector2) -> void:
	if phase_dock == null:
		return
	var margin := UiLayoutPolicy.safe_margin(viewport_size)
	phase_dock.position = margin
	phase_dock.size = Vector2(UiLayoutPolicy.HUD_LEFT_WIDTH, 42.0)


func _ensure_phase_dock() -> void:
	if owner_ui == null or phase_dock != null:
		return
	phase_dock = PHASE_DOCK_SCENE.instantiate() as PanelContainer
	phase_dock.z_index = 45
	owner_ui.gui_root.add_child(phase_dock)
	phase_label = phase_dock.get_node("Margin/ContentRow/PhaseLabel") as Label
	var row := phase_dock.call("get_content_row") as HBoxContainer
	if owner_ui.gold_label != null and owner_ui.gold_label.get_parent() != row:
		owner_ui.gold_label.reparent(row)
		owner_ui.gold_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		owner_ui.gold_label.custom_minimum_size = Vector2(112.0, 34.0)
	layout(owner_ui.get_viewport().get_visible_rect().size)


func _update_phase_text(phase: String) -> void:
	if phase_dock == null:
		return
	var text := ""
	match phase:
		PhaseManager.BATTLE:
			text = LocalizationManager.tr_key("ui.tutorial.state.battle", "Current: Battle")
		PhaseManager.PREPARE:
			text = LocalizationManager.tr_key("ui.tutorial.state.rest", "Current: Rest Area")
		PhaseManager.SETTLEMENT:
			text = LocalizationManager.tr_key("ui.phase.settlement", "Current: Reward Settlement")
		PhaseManager.PROTOCOL_SELECTION:
			text = LocalizationManager.tr_key("ui.phase.protocol_selection", "Current: Protocol Selection")
		PhaseManager.BATTLE_STARTING:
			text = LocalizationManager.tr_key("ui.phase.battle_starting", "Current: Deploying")
	phase_dock.call("set_phase_text", text)


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

