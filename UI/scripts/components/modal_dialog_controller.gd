extends RefCounted

const DIALOG_SCENE := preload("res://UI/components/ModalDialogView/ModalDialogView.tscn")
const DETAIL_ROW_SCENE := preload("res://UI/components/ModalDetailRow/ModalDetailRow.tscn")

const DEFAULT_SIZE := Vector2i(520, 300)
const SIZE_PRESETS := {
	&"small": Vector2i(420, 240),
	&"medium": Vector2i(560, 340),
	&"large": Vector2i(720, 420),
}
const PANEL_BG := Color(0.055, 0.066, 0.078, 0.98)
const MESSAGE_BG := Color(0.09, 0.11, 0.13, 0.92)
const MESSAGE_BORDER := Color(0.30, 0.39, 0.46, 0.55)
const PRIMARY_ACCENT := Color(0.42, 0.78, 0.92, 1.0)
const DESTRUCTIVE_ACCENT := Color(0.92, 0.34, 0.30, 1.0)
const SECONDARY_ACCENT := Color(0.56, 0.64, 0.70, 1.0)

var owner_ui: Node
var gui_root: Control
var dialog: ConfirmationDialog
var title_bar: HBoxContainer
var title_label: Label
var close_button: Button
var accent_bar: ColorRect
var content: VBoxContainer
var body_scroll: ScrollContainer
var body_content: VBoxContainer
var message_panel: PanelContainer
var message_label: Label
var details_container: VBoxContainer
var checkbox_panel: PanelContainer
var checkbox: CheckBox

var current_id: StringName = &""
var on_confirm := Callable()
var on_cancel := Callable()
var on_custom_action := Callable()
var checkbox_callback := Callable()
var custom_action_buttons: Array[Button] = []
var cancel_dispatched := false
var suppress_checkbox_callback := false
var dragging_title := false

func bind(owner: Node, root: Control) -> void:
	owner_ui = owner
	gui_root = root

func confirm(spec: Dictionary) -> bool:
	return _show(spec)

func request_confirmation(
	id: StringName,
	title: String,
	body: String,
	confirm_text: String = "OK",
	cancel_text: String = "Cancel",
	on_confirm_callback: Callable = Callable(),
	on_cancel_callback: Callable = Callable(),
	destructive: bool = false,
	size = null,
	checkbox_text: String = "",
	checkbox_changed_callback: Callable = Callable()
) -> bool:
	return _show({
		"id": id,
		"title": title,
		"message": body,
		"confirm_text": confirm_text,
		"cancel_text": cancel_text,
		"destructive": destructive,
		"size": size,
		"on_confirm": on_confirm_callback,
		"on_cancel": on_cancel_callback,
		"checkbox_text": checkbox_text,
		"checkbox_callback": checkbox_changed_callback,
	})

func is_dialog_visible() -> bool:
	return dialog != null and is_instance_valid(dialog) and dialog.visible

func cancel_visible_dialog() -> bool:
	if not is_dialog_visible():
		return false
	_cancel_current_dialog()
	return true

func _show(spec: Dictionary) -> bool:
	ensure_dialog()
	if dialog == null:
		return false
	current_id = StringName(str(spec.get("id", "")))
	on_confirm = spec.get("on_confirm", Callable()) as Callable
	on_cancel = spec.get("on_cancel", Callable()) as Callable
	on_custom_action = spec.get("on_custom_action", Callable()) as Callable
	checkbox_callback = spec.get("checkbox_callback", Callable()) as Callable
	cancel_dispatched = false
	_clear_custom_action_buttons()
	dialog.title = ""
	title_label.text = str(spec.get("title", ""))
	dialog.ok_button_text = str(spec.get("confirm_text", "OK"))
	dialog.cancel_button_text = str(spec.get("cancel_text", "Cancel"))
	dialog.dialog_text = ""
	message_label.text = _get_body_text(spec)
	_rebuild_details(spec.get("details", []), bool(spec.get("destructive", false)))
	checkbox.text = str(spec.get("checkbox_text", ""))
	suppress_checkbox_callback = true
	checkbox.button_pressed = bool(spec.get("checkbox_checked", false))
	suppress_checkbox_callback = false
	checkbox.visible = checkbox.text != ""
	_add_custom_actions(spec.get("custom_actions", []))
	var destructive := bool(spec.get("destructive", false))
	_apply_dialog_visuals(destructive)
	_apply_destructive_state(destructive)
	var popup_size := _resolve_popup_size(spec.get("size", null))
	dialog.min_size = popup_size
	dialog.popup_centered_clamped(popup_size, 0.9)
	_layout_content.call_deferred()
	return true

func ensure_dialog() -> void:
	if gui_root == null:
		return
	if dialog != null and is_instance_valid(dialog):
		if title_label != null and is_instance_valid(title_label):
			return
		dialog.queue_free()
		dialog = null
	dialog = DIALOG_SCENE.instantiate() as ConfirmationDialog
	dialog.name = "ConfirmDialogControllerDialog"
	gui_root.add_child(dialog)
	var native_message := dialog.get_label()
	native_message.text = ""
	native_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	native_message.add_theme_color_override("font_color", Color.TRANSPARENT)
	content = dialog.get_node("Content") as VBoxContainer
	title_bar = dialog.get_node("Content/TitleBar") as HBoxContainer
	title_label = dialog.get_node("Content/TitleBar/Title") as Label
	close_button = dialog.get_node("Content/TitleBar/CloseButton") as Button
	accent_bar = dialog.get_node("Content/AccentBar") as ColorRect
	body_scroll = dialog.get_node("Content/BodyScroll") as ScrollContainer
	body_content = dialog.get_node("Content/BodyScroll/BodyContent") as VBoxContainer
	message_panel = dialog.get_node("Content/BodyScroll/BodyContent/MessagePanel") as PanelContainer
	message_label = dialog.get_node("Content/BodyScroll/BodyContent/MessagePanel/MessageMargin/Message") as Label
	details_container = dialog.get_node("Content/BodyScroll/BodyContent/Details") as VBoxContainer
	checkbox_panel = dialog.get_node("Content/BodyScroll/BodyContent/CheckboxPanel") as PanelContainer
	checkbox = dialog.get_node("Content/BodyScroll/BodyContent/CheckboxPanel/CheckboxMargin/OptionalCheckbox") as CheckBox
	dialog.size_changed.connect(_layout_content)
	dialog.confirmed.connect(_on_confirmed)
	dialog.custom_action.connect(_on_custom_action)
	dialog.canceled.connect(_on_cancelled)
	dialog.close_requested.connect(_on_cancelled)
	if dialog.has_signal("window_input"):
		dialog.window_input.connect(_on_window_input)
	title_bar.gui_input.connect(_on_title_bar_gui_input)
	close_button.pressed.connect(_on_close_button_pressed)
	checkbox.toggled.connect(_on_checkbox_toggled)

func _layout_content() -> void:
	if dialog == null or not is_instance_valid(dialog) or content == null:
		return
	var native_message := dialog.get_label()
	if native_message == null:
		return
	content.position = native_message.position
	content.size = native_message.size

func _get_body_text(spec: Dictionary) -> String:
	if spec.has("message"):
		return str(spec.get("message", ""))
	return str(spec.get("body", ""))

func _rebuild_details(details, destructive: bool) -> void:
	if details_container == null:
		return
	for child in details_container.get_children():
		details_container.remove_child(child)
		child.queue_free()
	if not (details is Array) or details.is_empty():
		details_container.visible = false
		return
	details_container.visible = true
	for detail in details:
		if not (detail is Dictionary):
			continue
		var row := DETAIL_ROW_SCENE.instantiate() as PanelContainer
		var tone := StringName(str(detail.get("tone", "")))
		var accent := _resolve_detail_accent(tone, destructive)
		details_container.add_child(row)
		row.call("set_data", str(detail.get("label", "")), str(detail.get("value", "")), accent)

func _resolve_detail_accent(tone: StringName, destructive: bool) -> Color:
	if tone == &"destructive":
		return DESTRUCTIVE_ACCENT
	if tone == &"reward":
		return Color(0.94, 0.72, 0.28, 1.0)
	if tone == &"secondary":
		return SECONDARY_ACCENT
	return DESTRUCTIVE_ACCENT if destructive else PRIMARY_ACCENT

func _resolve_size(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is StringName:
		return SIZE_PRESETS.get(value, DEFAULT_SIZE)
	if value is String:
		return SIZE_PRESETS.get(StringName(value), DEFAULT_SIZE)
	if value is Dictionary:
		return Vector2i(int(value.get("x", DEFAULT_SIZE.x)), int(value.get("y", DEFAULT_SIZE.y)))
	return DEFAULT_SIZE

func _resolve_popup_size(value) -> Vector2i:
	var requested := _resolve_size(value)
	if gui_root == null or gui_root.get_viewport() == null:
		return requested
	var viewport_size := gui_root.get_viewport_rect().size
	var maximum := Vector2i(
		int(floor(viewport_size.x * 0.9)),
		int(floor(viewport_size.y * 0.9))
	)
	return Vector2i(min(requested.x, maximum.x), min(requested.y, maximum.y))

func _apply_dialog_visuals(destructive: bool) -> void:
	var accent := DESTRUCTIVE_ACCENT if destructive else PRIMARY_ACCENT
	if accent_bar != null:
		accent_bar.color = accent
	if dialog != null:
		var panel_style := _make_style(PANEL_BG, Color(accent.r, accent.g, accent.b, 0.58), 8, 1)
		dialog.add_theme_stylebox_override("embedded_border", panel_style)
		dialog.add_theme_stylebox_override("embedded_unfocused_border", panel_style)
	if message_panel != null:
		message_panel.add_theme_stylebox_override("panel", _make_style(
			MESSAGE_BG,
			Color(accent.r, accent.g, accent.b, 0.36),
			6,
			1
		))
	if checkbox_panel != null:
		checkbox_panel.visible = checkbox != null and checkbox.visible
		checkbox_panel.add_theme_stylebox_override("panel", _make_style(
			Color(0.08, 0.09, 0.10, 0.70),
			MESSAGE_BORDER,
			5,
			1
		))

func _make_style(bg_color: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	return style

func _apply_destructive_state(destructive: bool) -> void:
	if dialog == null:
		return
	var ok_button := dialog.get_ok_button()
	var cancel_button := dialog.get_cancel_button()
	if ok_button == null:
		return
	_apply_dialog_button_style(ok_button, true, destructive)
	if cancel_button != null:
		_apply_dialog_button_style(cancel_button, false, false)
	for button in custom_action_buttons:
		if button != null and is_instance_valid(button):
			_apply_dialog_button_style(button, false, destructive)
	if close_button != null:
		_apply_close_button_style(close_button)

func _apply_dialog_button_style(button: Button, primary: bool, destructive: bool) -> void:
	var color := DESTRUCTIVE_ACCENT if destructive else (PRIMARY_ACCENT if primary else SECONDARY_ACCENT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		var state_color := color
		style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.28 if primary else 0.08)
		if state == "hover" or state == "focus":
			style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.38 if primary else 0.15)
		elif state == "pressed":
			style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.48 if primary else 0.22)
		elif state == "disabled":
			state_color = Color(0.40, 0.46, 0.50, 1.0)
			style.bg_color = Color(0.10, 0.12, 0.14, 0.64)
		style.border_color = Color(state_color.r, state_color.g, state_color.b, 0.78)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		button.add_theme_stylebox_override(state, style)
	button.custom_minimum_size.y = 40.0
	if destructive:
		button.add_theme_color_override("font_color", Color(1.0, 0.68, 0.64))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.78, 0.74))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.82))
		button.add_theme_color_override("font_focus_color", Color(1.0, 0.78, 0.74))
	else:
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color_name, Color(0.94, 0.98, 1.0, 1.0))

func _apply_close_button_style(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		if state == "hover" or state == "focus":
			style.bg_color = Color(0.92, 0.34, 0.30, 0.22)
		elif state == "pressed":
			style.bg_color = Color(0.92, 0.34, 0.30, 0.34)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color(0.94, 0.98, 1.0, 1.0))

func _on_confirmed() -> void:
	var callback := on_confirm
	_clear_callbacks()
	if callback.is_valid():
		callback.call_deferred()

func _on_custom_action(action: StringName) -> void:
	if not is_dialog_visible():
		return
	if dialog != null and is_instance_valid(dialog):
		dialog.hide()
	var callback := on_custom_action
	_clear_callbacks()
	if callback.is_valid():
		callback.call_deferred(action)

func _on_cancelled() -> void:
	_cancel_current_dialog()

func _cancel_current_dialog() -> void:
	if cancel_dispatched:
		return
	cancel_dispatched = true
	dragging_title = false
	if dialog != null and is_instance_valid(dialog) and dialog.visible:
		dialog.hide()
	var callback := on_cancel
	_clear_callbacks()
	if callback.is_valid():
		callback.call_deferred()

func _clear_callbacks() -> void:
	on_confirm = Callable()
	on_cancel = Callable()
	on_custom_action = Callable()
	checkbox_callback = Callable()
	current_id = &""
	_clear_custom_action_buttons()

func _on_window_input(event: InputEvent) -> void:
	_handle_title_drag(event)
	_handle_cancel_input(event)

func _on_title_bar_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		dragging_title = mouse_button.pressed
		if owner_ui != null and owner_ui.has_method("get_viewport"):
			owner_ui.get_viewport().set_input_as_handled()

func _handle_title_drag(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
		dragging_title = false
		return
	var mouse_motion := event as InputEventMouseMotion
	if dragging_title and mouse_motion != null and dialog != null and is_instance_valid(dialog):
		dialog.position += Vector2i(int(round(mouse_motion.relative.x)), int(round(mouse_motion.relative.y)))
		if owner_ui != null and owner_ui.has_method("get_viewport"):
			owner_ui.get_viewport().set_input_as_handled()

func _on_close_button_pressed() -> void:
	_cancel_current_dialog()

func _handle_cancel_input(event: InputEvent) -> void:
	if not is_dialog_visible():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("CANCEL"):
		_cancel_current_dialog()
		if owner_ui != null and owner_ui.has_method("get_viewport"):
			owner_ui.get_viewport().set_input_as_handled()
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_current_dialog()
		if owner_ui != null and owner_ui.has_method("get_viewport"):
			owner_ui.get_viewport().set_input_as_handled()

func _on_checkbox_toggled(pressed: bool) -> void:
	if suppress_checkbox_callback:
		return
	if checkbox_callback.is_valid():
		checkbox_callback.call_deferred(pressed)

func _add_custom_actions(actions) -> void:
	if dialog == null or not (actions is Array):
		return
	for action in actions:
		if not (action is Dictionary):
			continue
		var action_id := StringName(str(action.get("id", "")))
		if action_id == &"":
			continue
		var button := dialog.add_button(
			str(action.get("text", action_id)),
			bool(action.get("right", false)),
			action_id
		)
		custom_action_buttons.append(button)

func _clear_custom_action_buttons() -> void:
	for button in custom_action_buttons:
		if button == null or not is_instance_valid(button):
			continue
		var parent := button.get_parent()
		if parent != null:
			parent.remove_child(button)
		button.queue_free()
	custom_action_buttons.clear()
