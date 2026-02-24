extends Node2D

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

@onready var gui_root: Control = $CanvasLayer/GUI
@onready var background: ColorRect = $CanvasLayer/GUI/Background
@onready var margin_root: MarginContainer = $CanvasLayer/GUI/Background/HBoxMargin
@onready var resolution_option: OptionButton = $CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MenuContainer/VBoxContainer/ResolutionOption

func _ready() -> void:
	_set_full_rect(gui_root)
	_set_full_rect(background)
	_set_full_rect(margin_root)
	_populate_resolution_options()
	if not get_viewport().is_connected("size_changed", Callable(self, "_on_viewport_size_changed")):
		get_viewport().connect("size_changed", Callable(self, "_on_viewport_size_changed"))

func _set_full_rect(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0

func _populate_resolution_options() -> void:
	resolution_option.clear()
	for resolution: Vector2i in RESOLUTION_PRESETS:
		resolution_option.add_item("%sx%s" % [resolution.x, resolution.y])
	var selected_index: int = _find_resolution_index(DisplaySettings.resolution)
	if selected_index == -1:
		selected_index = _find_resolution_index(Vector2i(DisplayServer.window_get_size()))
	if selected_index >= 0:
		resolution_option.select(selected_index)
	if not resolution_option.is_connected("item_selected", Callable(self, "_on_resolution_option_item_selected")):
		resolution_option.connect("item_selected", Callable(self, "_on_resolution_option_item_selected"))
	if not DisplaySettings.can_apply_window_changes():
		resolution_option.disabled = true
		resolution_option.tooltip_text = "Run standalone or exported build to change window resolution."

func _find_resolution_index(resolution: Vector2i) -> int:
	for i: int in range(RESOLUTION_PRESETS.size()):
		if RESOLUTION_PRESETS[i] == resolution:
			return i
	return -1

func _on_resolution_option_item_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTION_PRESETS.size():
		return
	DisplaySettings.set_resolution(RESOLUTION_PRESETS[index])

func _on_viewport_size_changed() -> void:
	# Keep explicit full-rect layout when viewport changes in editor/runtime.
	_set_full_rect(gui_root)
	_set_full_rect(background)
	_set_full_rect(margin_root)
