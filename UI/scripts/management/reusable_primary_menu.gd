extends Control
class_name ReusablePrimaryMenu

signal entry_pressed(entry_id: StringName)

const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")
const LAYOUT_POLICY := preload("res://UI/scripts/management/ui_layout_policy.gd")

var style_helper: ManagementUiStyleHelper
var _panel: Panel
var _title_label: Label
var _subtitle_label: Label
var _buttons: Array[Button] = []

static func apply_shared_layout(
	panel: Panel,
	buttons: Array,
	helper: ManagementUiStyleHelper = null
) -> void:
	if panel == null:
		return
	var viewport_size := panel.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = LAYOUT_POLICY.REFERENCE_VIEWPORT
	var visible_button_count := 0
	for value in buttons:
		var candidate := value as Button
		if candidate != null and candidate.visible:
			visible_button_count += 1
	var variant := LAYOUT_POLICY.primary_menu_variant(panel)
	var panel_rect := LAYOUT_POLICY.primary_menu_rect(viewport_size, visible_button_count, variant)
	panel.position = panel_rect.position
	panel.size = panel_rect.size
	panel.custom_minimum_size = Vector2.ZERO
	var horizontal_margin := float(TOKENS.SPACE_5)
	var button_size := Vector2(
		maxf(panel.size.x - horizontal_margin * 2.0, 0.0),
		TOKENS.BUTTON_HEIGHT
	)
	var first_button_position := Vector2(horizontal_margin, 108.0)
	var second_button_position := first_button_position + Vector2(
		0.0,
		button_size.y + TOKENS.SPACE_3
	)
	if helper != null:
		helper.style_primary_menu_panel(
			panel,
			buttons,
			first_button_position,
			second_button_position,
			button_size
		)
		if variant == &"single_action" and not buttons.is_empty():
			helper.style_management_button(buttons[0] as Button, true)
		return
	_apply_label_layout(
		panel.get_node_or_null("Title") as Label,
		Vector2(horizontal_margin, TOKENS.SPACE_4),
		Vector2(button_size.x, 32.0),
		TOKENS.FONT_TITLE,
		TOKENS.COLOR_TEXT_PRIMARY
	)
	_apply_label_layout(
		panel.get_node_or_null("SubTitle") as Label,
		Vector2(horizontal_margin, 52.0),
		Vector2(button_size.x, 44.0),
		TOKENS.FONT_LABEL,
		TOKENS.COLOR_TEXT_SECONDARY
	)
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		if button == null:
			continue
		button.position = first_button_position + Vector2(
			0.0,
			float(index) * (button_size.y + TOKENS.SPACE_3)
		)
		button.size = button_size
		button.custom_minimum_size = button_size
		button.focus_mode = Control.FOCUS_ALL

static func _apply_label_layout(
	label: Label,
	label_position: Vector2,
	label_size: Vector2,
	font_size: int,
	color: Color
) -> void:
	if label == null:
		return
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.position = label_position
	label.size = label_size
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if font_size >= 20 else TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

func configure(
	title: String,
	subtitle: String,
	entries: Array,
	helper: ManagementUiStyleHelper = null
) -> void:
	style_helper = helper
	_ensure_nodes()
	_title_label.text = title
	_subtitle_label.text = subtitle
	_rebuild_buttons(entries)
	apply_shared_layout(_panel, _buttons, style_helper)

func get_panel() -> Panel:
	_ensure_nodes()
	return _panel

func get_buttons() -> Array[Button]:
	return _buttons.duplicate()

func _ensure_nodes() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_title_label = Label.new()
	_title_label.name = "Title"
	_panel.add_child(_title_label)
	_subtitle_label = Label.new()
	_subtitle_label.name = "SubTitle"
	_panel.add_child(_subtitle_label)

func _rebuild_buttons(entries: Array) -> void:
	for button in _buttons:
		if button != null and is_instance_valid(button):
			button.queue_free()
	_buttons.clear()
	for entry in entries:
		var button := Button.new()
		button.name = str(entry.get("node_name", "EntryButton%d" % (_buttons.size() + 1)))
		button.text = str(entry.get("text", ""))
		button.pressed.connect(_on_entry_pressed.bind(StringName(str(entry.get("id", "")))))
		_panel.add_child(button)
		_buttons.append(button)

func _on_entry_pressed(entry_id: StringName) -> void:
	entry_pressed.emit(entry_id)
