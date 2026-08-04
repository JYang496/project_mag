extends RefCounted
class_name RestAreaManagementShell

const LAYOUT_POLICY := preload("res://UI/scripts/management/ui_layout_policy.gd")
const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")
const PRIMARY_MENU_ANIM_TIME := TOKENS.MOTION_NORMAL
const PRIMARY_MENU_ANIM_TRANS := Tween.TRANS_CUBIC
const PRIMARY_MENU_ANIM_EASE := Tween.EASE_OUT

var owner_ui: Node
var primary_menu_tweens: Dictionary = {}

func bind(owner: Node) -> void:
	owner_ui = owner

func show_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	menu_id = _normalize_menu_id(menu_id)
	if owner_ui == null or root == null or panel == null:
		return
	stop_primary_menu_tween(menu_id)
	var viewport_size := owner_ui.get_viewport().get_visible_rect().size
	_fit_left_panel(panel, viewport_size)
	var target_pos := panel.position
	var hidden_pos := _get_primary_menu_hidden_position(panel, target_pos)
	root.visible = true
	panel.position = hidden_pos
	var tween := owner_ui.create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(PRIMARY_MENU_ANIM_EASE)
	tween.tween_property(panel, "position", target_pos, PRIMARY_MENU_ANIM_TIME)
	tween.finished.connect(_on_primary_menu_tween_finished.bind(menu_id))
	primary_menu_tweens[menu_id] = tween
	call_deferred("_focus_first_button", panel)

func hide_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	menu_id = _normalize_menu_id(menu_id)
	if owner_ui == null or root == null or panel == null:
		return
	stop_primary_menu_tween(menu_id)
	var viewport_size := owner_ui.get_viewport().get_visible_rect().size
	_fit_left_panel(panel, viewport_size)
	var target_pos := panel.position
	var hidden_pos := _get_primary_menu_hidden_position(panel, target_pos)
	if not root.visible:
		panel.position = hidden_pos
		return
	var tween := owner_ui.create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(PRIMARY_MENU_ANIM_EASE)
	tween.tween_property(panel, "position", hidden_pos, PRIMARY_MENU_ANIM_TIME)
	tween.tween_callback(_on_primary_menu_hidden.bind(menu_id, root, panel, hidden_pos))
	tween.finished.connect(_on_primary_menu_tween_finished.bind(menu_id))
	primary_menu_tweens[menu_id] = tween

func stop_primary_menu_tween(menu_id: StringName) -> void:
	menu_id = _normalize_menu_id(menu_id)
	if not primary_menu_tweens.has(menu_id):
		return
	var active_tween := primary_menu_tweens[menu_id] as Tween
	if active_tween and is_instance_valid(active_tween):
		active_tween.kill()
	primary_menu_tweens.erase(menu_id)

func _on_primary_menu_hidden(menu_id: StringName, root: Control, panel: Control, hidden_pos: Vector2) -> void:
	if root:
		root.visible = false
	if panel:
		panel.position = hidden_pos
	primary_menu_tweens.erase(menu_id)

func _on_primary_menu_tween_finished(menu_id: StringName) -> void:
	primary_menu_tweens.erase(menu_id)

func _normalize_menu_id(menu_id: StringName) -> StringName:
	match menu_id:
		&"merchant":
			return &"purchase"
		&"smith":
			return &"upgrade"
		&"module":
			return &"warehouse"
		_:
			return menu_id

func _fit_left_panel(panel: Control, viewport_size: Vector2) -> void:
	if panel == null:
		return
	var panel_rect := LAYOUT_POLICY.primary_menu_rect(
		viewport_size,
		_count_visible_buttons(panel),
		LAYOUT_POLICY.primary_menu_variant(panel)
	)
	panel.position = panel_rect.position
	panel.size = panel_rect.size

func _get_primary_menu_hidden_position(panel: Control, target_pos: Vector2) -> Vector2:
	return Vector2(-panel.size.x - LAYOUT_POLICY.safe_margin(panel.get_viewport_rect().size).x, target_pos.y)

func _count_visible_buttons(root: Node) -> int:
	var result := 0
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.visible:
			result += 1
	return result

func _focus_first_button(root: Node) -> void:
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.visible and not button.disabled:
			button.grab_focus()
			return
