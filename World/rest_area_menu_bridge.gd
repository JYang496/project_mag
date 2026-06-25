extends RefCounted

var _owner: Node

func setup(owner_node: Node) -> void:
	_owner = owner_node

func is_navigation_allowed() -> bool:
	var ui: Node = _get_ui()
	if ui != null and ui.has_method("is_rest_area_zone_navigation_allowed"):
		return bool(ui.call("is_rest_area_zone_navigation_allowed"))
	return true

func get_menu_visible() -> Variant:
	var controller: Variant = _get_rest_ui_controller()
	if controller == null or not controller.has_method("is_menu_visible"):
		return null
	return bool(controller.call("is_menu_visible"))

func handle_right_cancel() -> bool:
	var controller: Variant = _get_rest_ui_controller()
	if controller == null or not controller.has_method("handle_right_cancel"):
		return false
	return bool(controller.call("handle_right_cancel"))

func open_zone_menu(zone_id: int, merchant_id: int, smith_id: int, module_id: int, board_edit_id: int) -> void:
	var controller: Variant = _get_rest_ui_controller()
	if controller == null:
		return
	if zone_id == merchant_id:
		controller.open_menu(&"purchase")
		return
	if zone_id == smith_id:
		controller.open_menu(&"upgrade")
		return
	if zone_id == module_id:
		controller.open_menu(&"warehouse")
		return
	if zone_id == board_edit_id:
		controller.open_board_edit_panel()
		return

func close_primary_menu() -> void:
	var controller: Variant = _get_rest_ui_controller()
	if controller != null and controller.has_method("close_primary_menu"):
		controller.close_primary_menu()

func clear_hover_hint() -> void:
	var ui: Node = _get_ui()
	if ui != null and ui.has_method("clear_rest_area_hover_hint"):
		ui.call("clear_rest_area_hover_hint")

func is_mouse_over_blocking_ui(viewport: Viewport, blocking_root_names: Array[StringName]) -> bool:
	if viewport == null:
		return false
	if _is_mouse_inside_visible_blocking_ui_root(viewport.get_mouse_position(), blocking_root_names):
		return true
	var hovered := viewport.gui_get_hovered_control()
	if hovered == null or not hovered.is_visible_in_tree():
		return false
	if hovered is BaseButton:
		return true
	if hovered is LineEdit or hovered is TextEdit:
		return true
	if hovered is ItemList or hovered is Tree:
		return true
	if hovered is OptionButton or hovered is SpinBox:
		return true
	if hovered is Slider or hovered is ScrollBar:
		return true
	return _is_inside_blocking_ui_branch(hovered, blocking_root_names)

func _get_ui() -> Node:
	var ui: Node = GlobalVariables.ui
	if ui != null and is_instance_valid(ui):
		return ui
	return null

func _get_rest_ui_controller() -> Variant:
	var ui: Node = _get_ui()
	if ui == null:
		return null
	if ui.get("rest_area_ui_controller") == null:
		return null
	return ui.get("rest_area_ui_controller")

func _is_inside_blocking_ui_branch(control: Control, blocking_root_names: Array[StringName]) -> bool:
	var current: Node = control
	while current != null:
		if blocking_root_names.has(StringName(current.name)):
			return true
		current = current.get_parent()
	return false

func _is_mouse_inside_visible_blocking_ui_root(mouse_position: Vector2, blocking_root_names: Array[StringName]) -> bool:
	var ui: Node = _get_ui()
	if ui == null:
		return false
	var gui := ui.get_node_or_null("GUI") as Control
	if gui == null:
		return false
	return _control_tree_has_blocking_root_at(gui, mouse_position, blocking_root_names)

func _control_tree_has_blocking_root_at(control: Control, mouse_position: Vector2, blocking_root_names: Array[StringName]) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	if blocking_root_names.has(StringName(control.name)) and control.get_global_rect().has_point(mouse_position):
		return true
	for child in control.get_children():
		var child_control := child as Control
		if child_control != null and _control_tree_has_blocking_root_at(child_control, mouse_position, blocking_root_names):
			return true
	return false
