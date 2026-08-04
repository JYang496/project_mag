extends RefCounted
class_name UiLayoutController

const LAYOUT_POLICY := preload("res://UI/scripts/management/ui_layout_policy.gd")
const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")
const PAUSE_PANEL_TARGET_SIZE := Vector2(400, 600)
const PRIMARY_MENU_ANIM_TIME := TOKENS.MOTION_NORMAL
const PRIMARY_MENU_ANIM_TRANS := Tween.TRANS_CUBIC
const PRIMARY_MENU_ANIM_EASE := Tween.EASE_OUT
const SECONDARY_MENU_SLIDE_OFFSET := Vector2(-36.0, 0.0)

var owner_ui: UI
var shell: RestAreaManagementShell
var primary_menu_tweens: Dictionary = {}
var secondary_menu_tweens: Dictionary = {}

func bind(ui: UI, management_shell: RestAreaManagementShell) -> void:
	owner_ui = ui
	shell = management_shell
	if shell != null:
		primary_menu_tweens = shell.primary_menu_tweens

func apply_responsive_layout() -> void:
	var viewport_size := owner_ui.get_viewport().get_visible_rect().size
	_apply_rect(owner_ui.purchase_panel, LAYOUT_POLICY.management_panel_rect(viewport_size))
	_apply_rect(owner_ui.upgrade_panel, LAYOUT_POLICY.management_panel_rect(viewport_size))
	_apply_rect(owner_ui.module_panel, LAYOUT_POLICY.management_panel_rect(viewport_size))
	if owner_ui.rest_area_ui_controller != null:
		for menu_id in owner_ui.rest_area_ui_controller.get_registered_service_menu_ids():
			var panel: Control = owner_ui.rest_area_ui_controller.get_service_primary_panel(menu_id)
			_apply_rect(panel, LAYOUT_POLICY.primary_menu_rect(viewport_size, _count_visible_buttons(panel), LAYOUT_POLICY.primary_menu_variant(panel)))
	if owner_ui.management_ui_bootstrap_controller != null:
		owner_ui.management_ui_bootstrap_controller.style_primary_menu_controls()
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
	_apply_rect(panel, LAYOUT_POLICY.primary_menu_rect(viewport_size, _count_visible_buttons(panel), LAYOUT_POLICY.primary_menu_variant(panel)))
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
	_apply_rect(panel, LAYOUT_POLICY.primary_menu_rect(viewport_size, _count_visible_buttons(panel), LAYOUT_POLICY.primary_menu_variant(panel)))
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
	return Vector2(-panel.size.x - LAYOUT_POLICY.safe_margin(panel.get_viewport_rect().size).x, target_pos.y)

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

func show_secondary_menu(root: Control) -> Tween:
	if owner_ui == null or root == null:
		return null
	stop_secondary_menu_tween(root)
	root.visible = true
	_configure_focus_for_root(root)
	root.position = SECONDARY_MENU_SLIDE_OFFSET
	root.modulate.a = 0.0
	var tween := owner_ui.create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(PRIMARY_MENU_ANIM_EASE)
	tween.parallel().tween_property(root, "position", Vector2.ZERO, PRIMARY_MENU_ANIM_TIME)
	tween.parallel().tween_property(root, "modulate:a", 1.0, PRIMARY_MENU_ANIM_TIME)
	tween.finished.connect(on_secondary_menu_tween_finished.bind(root))
	secondary_menu_tweens[root] = tween
	call_deferred("_focus_first_button", root)
	return tween

func hide_secondary_menu(root: Control) -> Tween:
	if owner_ui == null or root == null:
		return null
	stop_secondary_menu_tween(root)
	if not root.visible:
		root.position = Vector2.ZERO
		root.modulate.a = 1.0
		return null
	var tween := owner_ui.create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(root, "position", SECONDARY_MENU_SLIDE_OFFSET, PRIMARY_MENU_ANIM_TIME)
	tween.parallel().tween_property(root, "modulate:a", 0.0, PRIMARY_MENU_ANIM_TIME)
	tween.tween_callback(on_secondary_menu_hidden.bind(root))
	tween.finished.connect(on_secondary_menu_tween_finished.bind(root))
	secondary_menu_tweens[root] = tween
	return tween

func stop_secondary_menu_tween(root: Control) -> void:
	if root == null or not secondary_menu_tweens.has(root):
		return
	var active_tween := secondary_menu_tweens[root] as Tween
	if active_tween and is_instance_valid(active_tween):
		active_tween.kill()
	secondary_menu_tweens.erase(root)

func on_secondary_menu_hidden(root: Control) -> void:
	if root:
		root.visible = false
		root.position = Vector2.ZERO
		root.modulate.a = 1.0
	secondary_menu_tweens.erase(root)

func on_secondary_menu_tween_finished(root: Control) -> void:
	secondary_menu_tweens.erase(root)

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
	_apply_rect(panel, LAYOUT_POLICY.fit_centered_rect(viewport_size, target_size))

func fit_left_panel(panel: Control, viewport_size: Vector2, target_size: Vector2, left_margin: float) -> void:
	if panel == null:
		return
	var margin := LAYOUT_POLICY.safe_margin(viewport_size)
	var available_size: Vector2 = viewport_size - margin * 2.0
	var width: float = minf(target_size.x, available_size.x)
	var height: float = minf(target_size.y, available_size.y)
	panel.size = Vector2(maxf(width, 0.0), maxf(height, 0.0))
	panel.position = Vector2(maxf(left_margin, margin.x), (viewport_size.y - panel.size.y) * 0.5)

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

func _apply_rect(control: Control, target_rect: Rect2) -> void:
	if control == null:
		return
	control.position = target_rect.position
	control.size = target_rect.size

func _count_visible_buttons(root: Node) -> int:
	if root == null:
		return 0
	var result := 0
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.visible:
			result += 1
	return result

func _configure_focus_for_root(root: Node) -> void:
	var buttons: Array[Button] = []
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null or not button.visible or button.disabled:
			continue
		button.focus_mode = Control.FOCUS_ALL
		buttons.append(button)
	if buttons.is_empty():
		return
	for index in range(buttons.size()):
		var button := buttons[index]
		var previous := buttons[posmod(index - 1, buttons.size())]
		var next := buttons[posmod(index + 1, buttons.size())]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)

func _focus_first_button(root: Node) -> void:
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.visible and not button.disabled:
			button.grab_focus()
			return
