extends RefCounted
class_name ManagementUiStyleHelper

const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")

var _management_panel_style: StyleBoxFlat
var _primary_button_styles: Dictionary = {}
var _secondary_button_styles: Dictionary = {}

func style_primary_menu_panel(
	panel: Panel,
	buttons: Array,
	first_button_position: Vector2 = Vector2(28.0, 108.0),
	second_button_position: Vector2 = Vector2(28.0, 166.0),
	button_size: Vector2 = Vector2(304.0, TOKENS.BUTTON_HEIGHT)
) -> void:
	if panel == null:
		return
	style_management_panel(panel)
	_ensure_facility_header_decor(panel)
	var title := panel.get_node_or_null("Title") as Label
	if title:
		title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		title.position = Vector2(TOKENS.SPACE_5, TOKENS.SPACE_4)
		title.size = Vector2(maxf(panel.size.x - 136.0, 0.0), 32.0)
		title.clip_text = true
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		TOKENS.style_label(title, TOKENS.FONT_TITLE, TOKENS.COLOR_TEXT_PRIMARY)
	var subtitle := panel.get_node_or_null("SubTitle") as Label
	if subtitle:
		subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		subtitle.position = Vector2(TOKENS.SPACE_5, 52.0)
		subtitle.size = Vector2(maxf(panel.size.x - TOKENS.SPACE_5 * 2.0, 0.0), 44.0)
		subtitle.clip_text = false
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.max_lines_visible = 2
		subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		TOKENS.style_label(subtitle, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_SECONDARY)
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		if button == null:
			continue
		var target_position := first_button_position
		if index > 0:
			target_position = second_button_position + Vector2(
				0.0,
				float(index - 1) * (button_size.y + TOKENS.SPACE_3)
			)
		position_management_button(button, target_position, button_size)
		style_management_button(button)
	configure_focus_chain(buttons)

func style_management_panel(panel: Panel) -> void:
	if panel == null:
		return
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _get_management_panel_style())

func style_management_title(title: Label) -> void:
	if title == null:
		return
	TOKENS.style_label(title, TOKENS.FONT_TITLE, TOKENS.COLOR_TEXT_PRIMARY)

func connect_management_panel_input_blockers(owner: Object, panels: Array) -> void:
	if owner == null:
		return
	for panel in panels:
		var target_panel := panel as Panel
		if target_panel == null:
			continue
		var callback := Callable(owner, "_on_management_panel_gui_input").bind(target_panel)
		if not target_panel.gui_input.is_connected(callback):
			target_panel.gui_input.connect(callback)

func style_management_button(button: Button, primary: bool = false) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, TOKENS.TOUCH_TARGET_MIN)
	button.add_theme_font_size_override("font_size", TOKENS.FONT_BUTTON)
	button.add_theme_color_override("font_color", TOKENS.COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TOKENS.COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_focus_color", TOKENS.COLOR_TEXT_PRIMARY)
	var styles := _get_management_button_styles(primary)
	button.add_theme_stylebox_override("normal", styles.get("normal") as StyleBoxFlat)
	button.add_theme_stylebox_override("hover", styles.get("hover") as StyleBoxFlat)
	button.add_theme_stylebox_override("pressed", styles.get("pressed") as StyleBoxFlat)
	button.add_theme_stylebox_override("focus", styles.get("focus") as StyleBoxFlat)

func refresh_mode_button_styles(weapon_button: Button, module_button: Button, weapon_mode_active: bool) -> void:
	style_management_button(weapon_button, weapon_mode_active)
	style_management_button(module_button, not weapon_mode_active)

func position_management_button(button: Button, position: Vector2, button_size: Vector2) -> void:
	if button == null:
		return
	button.position = position
	button.size = button_size
	button.custom_minimum_size = button_size

func configure_focus_chain(buttons: Array) -> void:
	var focusable: Array[Button] = []
	for value in buttons:
		var button := value as Button
		if button == null or not button.visible or button.disabled:
			continue
		button.focus_mode = Control.FOCUS_ALL
		focusable.append(button)
	if focusable.is_empty():
		return
	for index in range(focusable.size()):
		var button := focusable[index]
		var previous := focusable[posmod(index - 1, focusable.size())]
		var next := focusable[posmod(index + 1, focusable.size())]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)

func create_management_instruction(panel: Panel, node_name: String, position: Vector2, label_size: Vector2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = position
	label.size = label_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	TOKENS.style_label(label, TOKENS.FONT_BODY, TOKENS.COLOR_TEXT_SECONDARY)
	panel.add_child(label)
	return label

func _ensure_facility_header_decor(panel: Panel) -> void:
	var accent := panel.get_node_or_null("SystemAccent") as ColorRect
	if accent == null:
		accent = ColorRect.new()
		accent.name = "SystemAccent"
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(accent)
	accent.position = Vector2.ZERO
	accent.size = Vector2(6.0, panel.size.y)
	accent.color = TOKENS.COLOR_ACCENT_SYSTEM
	var code := panel.get_node_or_null("FacilityCode") as Label
	if code == null:
		code = Label.new()
		code.name = "FacilityCode"
		code.mouse_filter = Control.MOUSE_FILTER_IGNORE
		code.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		panel.add_child(code)
	code.position = Vector2(maxf(panel.size.x - 112.0, 0.0), 18.0)
	code.size = Vector2(88.0, 24.0)
	code.text = _facility_code(panel)
	TOKENS.style_label(code, TOKENS.FONT_CAPTION, TOKENS.COLOR_ACCENT_SYSTEM)

func _facility_code(panel: Panel) -> String:
	var context := ("%s %s" % [panel.get_parent().name if panel.get_parent() else "", panel.name]).to_lower()
	if "purchase" in context:
		return "FAC / 01"
	if "upgrade" in context:
		return "FAC / 02"
	if "warehouse" in context or "module" in context:
		return "FAC / 03"
	if "board" in context:
		return "SYS / 04"
	if "battle" in context:
		return "OPS / 05"
	return "SYS / 00"

func _get_management_panel_style() -> StyleBoxFlat:
	if _management_panel_style != null:
		return _management_panel_style
	_management_panel_style = TOKENS.make_panel_style(true, TOKENS.COLOR_BORDER)
	return _management_panel_style

func _get_management_button_styles(primary: bool) -> Dictionary:
	var cached := _primary_button_styles if primary else _secondary_button_styles
	if not cached.is_empty():
		return cached
	cached = TOKENS.make_button_style(
		Color(0.34, 0.22, 0.06) if primary else TOKENS.COLOR_SURFACE_INTERACTIVE,
		TOKENS.COLOR_PRIMARY_ACTION if primary else TOKENS.COLOR_BORDER
	)
	if primary:
		_primary_button_styles = cached
	else:
		_secondary_button_styles = cached
	return cached
