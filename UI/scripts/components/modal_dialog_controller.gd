extends RefCounted

const DEFAULT_SIZE := Vector2i(520, 240)
const SIZE_PRESETS := {
	&"small": Vector2i(420, 180),
	&"medium": Vector2i(560, 260),
	&"large": Vector2i(720, 420),
}

var owner_ui: Node
var gui_root: Control
var dialog: ConfirmationDialog
var message_label: Label
var checkbox: CheckBox

var current_id: StringName = &""
var on_confirm := Callable()
var on_cancel := Callable()
var on_custom_action := Callable()
var checkbox_callback := Callable()
var custom_action_buttons: Array[Button] = []
var cancel_dispatched := false
var suppress_checkbox_callback := false

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
	dialog.title = str(spec.get("title", ""))
	dialog.ok_button_text = str(spec.get("confirm_text", "OK"))
	dialog.cancel_button_text = str(spec.get("cancel_text", "Cancel"))
	dialog.dialog_text = ""
	message_label.text = _get_body_text(spec)
	checkbox.text = str(spec.get("checkbox_text", ""))
	suppress_checkbox_callback = true
	checkbox.button_pressed = bool(spec.get("checkbox_checked", false))
	suppress_checkbox_callback = false
	checkbox.visible = checkbox.text != ""
	_add_custom_actions(spec.get("custom_actions", []))
	_apply_destructive_state(bool(spec.get("destructive", false)))
	dialog.popup_centered_clamped(_resolve_size(spec.get("size", null)), 0.9)
	return true

func ensure_dialog() -> void:
	if gui_root == null:
		return
	if dialog != null and is_instance_valid(dialog):
		return
	dialog = ConfirmationDialog.new()
	dialog.name = "ConfirmDialogControllerDialog"
	dialog.dialog_text = ""
	dialog.wrap_controls = false
	gui_root.add_child(dialog)
	var content := VBoxContainer.new()
	content.name = "ConfirmDialogContent"
	content.custom_minimum_size = Vector2(460.0, 0.0)
	content.add_theme_constant_override("separation", 12)
	message_label = Label.new()
	message_label.name = "Message"
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(message_label)
	checkbox = CheckBox.new()
	checkbox.name = "OptionalCheckbox"
	checkbox.visible = false
	content.add_child(checkbox)
	dialog.add_child(content)
	dialog.confirmed.connect(_on_confirmed)
	dialog.custom_action.connect(_on_custom_action)
	dialog.canceled.connect(_on_cancelled)
	dialog.close_requested.connect(_on_cancelled)
	if dialog.has_signal("window_input"):
		dialog.window_input.connect(_on_window_input)
	checkbox.toggled.connect(_on_checkbox_toggled)

func _get_body_text(spec: Dictionary) -> String:
	if spec.has("message"):
		return str(spec.get("message", ""))
	return str(spec.get("body", ""))

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

func _apply_destructive_state(destructive: bool) -> void:
	if dialog == null:
		return
	var ok_button := dialog.get_ok_button()
	if ok_button == null:
		return
	if destructive:
		ok_button.add_theme_color_override("font_color", Color(1.0, 0.32, 0.28))
		ok_button.add_theme_color_override("font_hover_color", Color(1.0, 0.42, 0.36))
	else:
		ok_button.remove_theme_color_override("font_color")
		ok_button.remove_theme_color_override("font_hover_color")

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
	_handle_cancel_input(event)

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
