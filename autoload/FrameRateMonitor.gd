extends CanvasLayer

const DISPLAY_WIDTH := 128.0
const TOP_MARGIN := 8.0

var _fps_label: Label
var _last_fps := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20000

	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_fps_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_fps_label.offset_left = -DISPLAY_WIDTH * 0.5
	_fps_label.offset_top = TOP_MARGIN
	_fps_label.offset_right = DISPLAY_WIDTH * 0.5
	_fps_label.offset_bottom = TOP_MARGIN + 24.0
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fps_label.add_theme_font_size_override(&"font_size", 16)
	_fps_label.add_theme_color_override(&"font_color", Color(0.93, 0.97, 0.98, 1.0))
	_fps_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.02, 0.03, 0.95))
	_fps_label.add_theme_constant_override(&"outline_size", 2)
	add_child(_fps_label)

	_update_display()


func _process(_delta: float) -> void:
	_update_display()


func _update_display() -> void:
	var current_fps := int(Engine.get_frames_per_second())
	if current_fps == _last_fps:
		return
	_last_fps = current_fps
	_fps_label.text = "%d FPS" % current_fps
