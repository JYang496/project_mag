extends Control
class_name ReusablePrimaryMenu

signal entry_pressed(entry_id: StringName)

const PANEL_SIZE := Vector2(312, 320)
const PANEL_POSITION := Vector2(24, 164)
const TITLE_POSITION := Vector2(28, 16)
const TITLE_SIZE := Vector2(256, 28)
const SUBTITLE_POSITION := Vector2(28, 48)
const SUBTITLE_SIZE := Vector2(256, 28)
const BUTTON_POSITION_1 := Vector2(28, 108)
const BUTTON_POSITION_2 := Vector2(28, 166)
const BUTTON_SIZE := Vector2(220, 46)

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
	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	panel.custom_minimum_size = PANEL_SIZE
	if helper != null:
		helper.style_primary_menu_panel(
			panel,
			buttons,
			BUTTON_POSITION_1,
			BUTTON_POSITION_2,
			BUTTON_SIZE
		)
		return
	_apply_label_layout(panel.get_node_or_null("Title") as Label, TITLE_POSITION, TITLE_SIZE, 24, Color(0.86, 0.94, 1.0))
	_apply_label_layout(panel.get_node_or_null("SubTitle") as Label, SUBTITLE_POSITION, SUBTITLE_SIZE, 14, Color(0.62, 0.72, 0.8))
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		if button == null:
			continue
		button.position = BUTTON_POSITION_1 if index == 0 else BUTTON_POSITION_2
		button.size = BUTTON_SIZE
		button.custom_minimum_size = BUTTON_SIZE

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
		if _buttons.size() >= 2:
			break
		var button := Button.new()
		button.name = str(entry.get("node_name", "EntryButton%d" % (_buttons.size() + 1)))
		button.text = str(entry.get("text", ""))
		button.pressed.connect(_on_entry_pressed.bind(StringName(str(entry.get("id", "")))))
		_panel.add_child(button)
		_buttons.append(button)

func _on_entry_pressed(entry_id: StringName) -> void:
	entry_pressed.emit(entry_id)
