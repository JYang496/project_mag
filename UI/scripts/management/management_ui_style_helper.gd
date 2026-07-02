extends RefCounted
class_name ManagementUiStyleHelper

const PANEL_BACKGROUND_COLOR := Color(0.045, 0.065, 0.09, 0.98)
const PANEL_BORDER_COLOR := Color(0.18, 0.38, 0.52, 1.0)
const PANEL_SHADOW_COLOR := Color(0, 0, 0, 0.45)
const PRIMARY_BUTTON_BACKGROUND_COLOR := Color(0.12, 0.38, 0.58)
const PRIMARY_BUTTON_BORDER_COLOR := Color(0.3, 0.68, 0.9)
const SECONDARY_BUTTON_BACKGROUND_COLOR := Color(0.12, 0.18, 0.25)
const SECONDARY_BUTTON_BORDER_COLOR := Color(0.28, 0.42, 0.55)

var _management_panel_style: StyleBoxFlat
var _primary_button_styles: Dictionary = {}
var _secondary_button_styles: Dictionary = {}

func style_primary_menu_panel(
	panel: Panel,
	buttons: Array,
	first_button_position: Vector2,
	second_button_position: Vector2,
	button_size: Vector2
) -> void:
	if panel == null:
		return
	var title := panel.get_node_or_null("Title") as Label
	if title:
		title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		title.position = Vector2(28, 16)
		title.size = Vector2(256, 28)
		title.clip_text = true
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	var subtitle := panel.get_node_or_null("SubTitle") as Label
	if subtitle:
		subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		subtitle.position = Vector2(28, 48)
		subtitle.size = Vector2(256, 28)
		subtitle.clip_text = true
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.add_theme_font_size_override("font_size", 14)
		subtitle.add_theme_color_override("font_color", Color(0.62, 0.72, 0.8))
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		if button == null:
			continue
		var target_position := first_button_position if index == 0 else second_button_position
		position_management_button(button, target_position, button_size)
		style_management_button(button)

func style_management_panel(panel: Panel) -> void:
	if panel == null:
		return
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _get_management_panel_style())

func style_management_title(title: Label) -> void:
	if title == null:
		return
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))

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
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 44.0)
	button.add_theme_font_size_override("font_size", 18)
	var styles := _get_management_button_styles(primary)
	button.add_theme_stylebox_override("normal", styles.get("normal") as StyleBoxFlat)
	button.add_theme_stylebox_override("hover", styles.get("hover") as StyleBoxFlat)
	button.add_theme_stylebox_override("pressed", styles.get("pressed") as StyleBoxFlat)

func refresh_mode_button_styles(weapon_button: Button, module_button: Button, weapon_mode_active: bool) -> void:
	style_management_button(weapon_button, weapon_mode_active)
	style_management_button(module_button, not weapon_mode_active)

func position_management_button(button: Button, position: Vector2, button_size: Vector2) -> void:
	if button == null:
		return
	button.position = position
	button.size = button_size

func create_management_instruction(panel: Panel, node_name: String, position: Vector2, label_size: Vector2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = position
	label.size = label_size
	label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.8))
	label.add_theme_font_size_override("font_size", 16)
	panel.add_child(label)
	return label

func _get_management_panel_style() -> StyleBoxFlat:
	if _management_panel_style != null:
		return _management_panel_style
	_management_panel_style = StyleBoxFlat.new()
	_management_panel_style.bg_color = PANEL_BACKGROUND_COLOR
	_management_panel_style.border_color = PANEL_BORDER_COLOR
	_management_panel_style.set_border_width_all(2)
	_management_panel_style.set_corner_radius_all(12)
	_management_panel_style.shadow_color = PANEL_SHADOW_COLOR
	_management_panel_style.shadow_size = 12
	return _management_panel_style

func _get_management_button_styles(primary: bool) -> Dictionary:
	var cached := _primary_button_styles if primary else _secondary_button_styles
	if not cached.is_empty():
		return cached
	var normal := StyleBoxFlat.new()
	normal.bg_color = (
		PRIMARY_BUTTON_BACKGROUND_COLOR
		if primary
		else SECONDARY_BUTTON_BACKGROUND_COLOR
	)
	normal.border_color = (
		PRIMARY_BUTTON_BORDER_COLOR
		if primary
		else SECONDARY_BUTTON_BORDER_COLOR
	)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.12)
	cached = {
		"normal": normal,
		"hover": hover,
		"pressed": pressed,
	}
	if primary:
		_primary_button_styles = cached
	else:
		_secondary_button_styles = cached
	return cached
