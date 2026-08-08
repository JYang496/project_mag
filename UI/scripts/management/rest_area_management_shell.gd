extends RefCounted
class_name RestAreaManagementShell

const LAYOUT_POLICY := preload("res://UI/scripts/management/ui_layout_policy.gd")
const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")
const PRIMARY_MENU_ANIM_TIME := TOKENS.MOTION_NORMAL
const PRIMARY_MENU_ANIM_TRANS := Tween.TRANS_CUBIC
const PRIMARY_MENU_ANIM_EASE := Tween.EASE_OUT

var owner_ui: Node
var primary_menu_tweens: Dictionary = {}
var _last_focused_button_paths: Dictionary = {}

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
	_configure_focus_for_root(panel)
	var tween := owner_ui.create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(PRIMARY_MENU_ANIM_EASE)
	tween.tween_property(panel, "position", target_pos, PRIMARY_MENU_ANIM_TIME)
	tween.finished.connect(_on_primary_menu_tween_finished.bind(menu_id))
	primary_menu_tweens[menu_id] = tween
	call_deferred("_restore_or_focus_first_button", menu_id, panel)

func hide_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	menu_id = _normalize_menu_id(menu_id)
	if owner_ui == null or root == null or panel == null:
		return
	_remember_focused_button(menu_id, panel)
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
	_release_focus_inside(root)
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

func handle_primary_menu_input(event: InputEvent, menu_id: StringName, panel: Control) -> bool:
	if event == null or event.is_echo() or panel == null or not panel.is_visible_in_tree():
		return false
	var direction := 0
	if event.is_action_pressed("UP") or event.is_action_pressed("LEFT") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		direction = -1
	elif event.is_action_pressed("DOWN") or event.is_action_pressed("RIGHT") \
			or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		direction = 1
	if direction != 0:
		return _move_primary_menu_focus(menu_id, panel, direction)
	if event.is_action_pressed("INTERACT") or event.is_action_pressed("ui_accept"):
		var focused := _focused_button_inside(panel)
		if focused == null:
			_restore_or_focus_first_button(menu_id, panel)
			focused = _focused_button_inside(panel)
		if focused != null:
			focused.pressed.emit()
			return true
	return false

func _configure_focus_for_root(root: Node) -> void:
	var buttons := _eligible_buttons(root)
	for index in range(buttons.size()):
		var button := buttons[index]
		var previous := buttons[posmod(index - 1, buttons.size())]
		var next := buttons[posmod(index + 1, buttons.size())]
		button.focus_mode = Control.FOCUS_ALL
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_neighbor_right = button.get_path_to(next)
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)

func _move_primary_menu_focus(menu_id: StringName, panel: Control, direction: int) -> bool:
	var buttons := _eligible_buttons(panel)
	if buttons.is_empty():
		return false
	var focused := _focused_button_inside(panel)
	var index := buttons.find(focused)
	if index < 0:
		_restore_or_focus_first_button(menu_id, panel)
		return true
	var next: Button = buttons[posmod(index + direction, buttons.size())]
	next.grab_focus()
	_last_focused_button_paths[_normalize_menu_id(menu_id)] = panel.get_path_to(next)
	return true

func _restore_or_focus_first_button(menu_id: StringName, panel: Node) -> void:
	if panel == null or not panel.is_inside_tree():
		return
	var saved_path: NodePath = _last_focused_button_paths.get(_normalize_menu_id(menu_id), NodePath())
	var saved := panel.get_node_or_null(saved_path) as Button if not saved_path.is_empty() else null
	if saved != null and saved.visible and not saved.disabled:
		saved.grab_focus()
		return
	var buttons := _eligible_buttons(panel)
	if not buttons.is_empty():
		buttons[0].grab_focus()

func _remember_focused_button(menu_id: StringName, panel: Control) -> void:
	var focused := _focused_button_inside(panel)
	if focused != null:
		_last_focused_button_paths[_normalize_menu_id(menu_id)] = panel.get_path_to(focused)

func _focused_button_inside(root: Node) -> Button:
	if root == null or root.get_viewport() == null:
		return null
	var focused := root.get_viewport().gui_get_focus_owner() as Button
	if focused != null and (focused == root or root.is_ancestor_of(focused)):
		return focused
	return null

func _eligible_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root == null:
		return buttons
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.visible and not button.disabled:
			buttons.append(button)
	return buttons

func _release_focus_inside(root: Node) -> void:
	var focused := _focused_button_inside(root)
	if focused != null:
		focused.release_focus()
