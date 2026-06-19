extends RefCounted
class_name UiLayoutController

const PANEL_TARGET_SIZE := Vector2(1000, 600)
const PANEL_MARGIN := Vector2(24, 24)
const PAUSE_PANEL_TARGET_SIZE := Vector2(400, 600)
const PRIMARY_MENU_TARGET_SIZE := Vector2(312, 320)
const PRIMARY_MENU_LEFT_MARGIN := 16.0
const PRIMARY_MENU_ANIM_TIME := 0.2
const PRIMARY_MENU_ANIM_TRANS := Tween.TRANS_CUBIC
const PRIMARY_MENU_ANIM_EASE := Tween.EASE_OUT

var owner_ui: UI
var shell: RestAreaManagementShell
var primary_menu_tweens: Dictionary = {}

func bind(ui: UI, management_shell: RestAreaManagementShell) -> void:
	owner_ui = ui
	shell = management_shell
	if shell != null:
		primary_menu_tweens = shell.primary_menu_tweens

func apply_responsive_layout() -> void:
	var viewport_size := owner_ui.get_viewport().get_visible_rect().size
	fit_center_panel(owner_ui.purchase_panel, viewport_size, PANEL_TARGET_SIZE)
	fit_center_panel(owner_ui.upgrade_panel, viewport_size, PANEL_TARGET_SIZE)
	fit_center_panel(owner_ui.module_panel, viewport_size, PANEL_TARGET_SIZE)
	fit_left_panel(owner_ui.purchase_primary_panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	fit_left_panel(owner_ui.upgrade_primary_panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	fit_left_panel(owner_ui.warehouse_primary_panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	fit_pause_layout(viewport_size)
	owner_ui._ensure_hud_presenter_instance()
	owner_ui.hud_presenter.layout_hud(viewport_size, owner_ui.hp_label_label, owner_ui.weapon_selector)
	owner_ui._layout_rest_area_hover_hint(viewport_size)
	owner_ui._layout_quest_hint(viewport_size)
	owner_ui._layout_controls_hint_panel(viewport_size)
	_sync_public_fields_to_owner()

func show_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	if shell != null:
		shell.show_primary_menu(menu_id, root, panel)
		primary_menu_tweens = shell.primary_menu_tweens
		_sync_public_fields_to_owner()
		return
	if root == null or panel == null:
		return
	stop_primary_menu_tween(menu_id)
	var viewport_size := owner_ui.get_viewport().get_visible_rect().size
	fit_left_panel(panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	var target_pos := panel.position
	var hidden_pos := get_primary_menu_hidden_position(panel, target_pos)
	root.visible = true
	panel.position = hidden_pos
	var tween := owner_ui.create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(PRIMARY_MENU_ANIM_EASE)
	tween.tween_property(panel, "position", target_pos, PRIMARY_MENU_ANIM_TIME)
	tween.finished.connect(on_primary_menu_tween_finished.bind(menu_id))
	primary_menu_tweens[menu_id] = tween
	_sync_public_fields_to_owner()

func hide_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	if shell != null:
		shell.hide_primary_menu(menu_id, root, panel)
		primary_menu_tweens = shell.primary_menu_tweens
		_sync_public_fields_to_owner()
		return
	if root == null or panel == null:
		return
	stop_primary_menu_tween(menu_id)
	var viewport_size := owner_ui.get_viewport().get_visible_rect().size
	fit_left_panel(panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	var target_pos := panel.position
	var hidden_pos := get_primary_menu_hidden_position(panel, target_pos)
	if not root.visible:
		panel.position = hidden_pos
		return
	var tween := owner_ui.create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(PRIMARY_MENU_ANIM_EASE)
	tween.tween_property(panel, "position", hidden_pos, PRIMARY_MENU_ANIM_TIME)
	tween.tween_callback(on_primary_menu_hidden.bind(menu_id, root, panel, hidden_pos))
	tween.finished.connect(on_primary_menu_tween_finished.bind(menu_id))
	primary_menu_tweens[menu_id] = tween
	_sync_public_fields_to_owner()

func get_primary_menu_hidden_position(panel: Control, target_pos: Vector2) -> Vector2:
	if shell != null:
		return shell._get_primary_menu_hidden_position(panel, target_pos)
	return Vector2(-panel.size.x - PRIMARY_MENU_LEFT_MARGIN, target_pos.y)

func stop_primary_menu_tween(menu_id: StringName) -> void:
	if shell != null:
		shell.stop_primary_menu_tween(menu_id)
		primary_menu_tweens = shell.primary_menu_tweens
		_sync_public_fields_to_owner()
		return
	if not primary_menu_tweens.has(menu_id):
		return
	var active_tween := primary_menu_tweens[menu_id] as Tween
	if active_tween and is_instance_valid(active_tween):
		active_tween.kill()
	primary_menu_tweens.erase(menu_id)
	_sync_public_fields_to_owner()

func on_primary_menu_hidden(menu_id: StringName, root: Control, panel: Control, hidden_pos: Vector2) -> void:
	if shell != null:
		shell.call("_on_primary_menu_hidden", menu_id, root, panel, hidden_pos)
		primary_menu_tweens = shell.primary_menu_tweens
		_sync_public_fields_to_owner()
		return
	if root:
		root.visible = false
	if panel:
		panel.position = hidden_pos
	primary_menu_tweens.erase(menu_id)
	_sync_public_fields_to_owner()

func on_primary_menu_tween_finished(menu_id: StringName) -> void:
	if shell != null:
		shell.call("_on_primary_menu_tween_finished", menu_id)
		primary_menu_tweens = shell.primary_menu_tweens
		_sync_public_fields_to_owner()
		return
	primary_menu_tweens.erase(menu_id)
	_sync_public_fields_to_owner()

func fit_center_panel(panel: Control, viewport_size: Vector2, target_size: Vector2) -> void:
	if panel == null:
		return
	var available_size: Vector2 = viewport_size - PANEL_MARGIN * 2.0
	var width: float = minf(target_size.x, available_size.x)
	var height: float = minf(target_size.y, available_size.y)
	panel.size = Vector2(maxf(width, 0.0), maxf(height, 0.0))
	panel.position = (viewport_size - panel.size) * 0.5

func fit_left_panel(panel: Control, viewport_size: Vector2, target_size: Vector2, left_margin: float) -> void:
	if panel == null:
		return
	var available_size: Vector2 = viewport_size - PANEL_MARGIN * 2.0
	var width: float = minf(target_size.x, available_size.x)
	var height: float = minf(target_size.y, available_size.y)
	panel.size = Vector2(maxf(width, 0.0), maxf(height, 0.0))
	panel.position = Vector2(maxf(left_margin, PANEL_MARGIN.x), (viewport_size.y - panel.size.y) * 0.5)

func fit_pause_layout(viewport_size: Vector2) -> void:
	owner_ui.pause_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner_ui.pause_menu_root.offset_left = 0
	owner_ui.pause_menu_root.offset_top = 0
	owner_ui.pause_menu_root.offset_right = 0
	owner_ui.pause_menu_root.offset_bottom = 0
	fit_center_panel(owner_ui.pause_menu_panel, viewport_size, PAUSE_PANEL_TARGET_SIZE)

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui._primary_menu_tweens = primary_menu_tweens

