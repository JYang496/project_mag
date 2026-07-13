extends CanvasLayer

const HybridCameraDefaultsType := preload("res://Visual/Oblique/hybrid_camera_defaults.gd")
const DEFAULT_YAW: float = 0.0
const DEFAULT_HYBRID_PITCH: float = 52.0

var _player: Node
var _values: Dictionary = {}
var _value_labels: Dictionary = {}
var _sliders: Dictionary = {}
var _content: VBoxContainer

func setup(player: Node) -> void:
	_player = player
	_values = {
		"yaw": float(player.fixed_camera_yaw_degrees),
		"pitch": float(player.hybrid_camera_pitch_degrees),
		"distance": float(player.hybrid_camera_distance),
	}
	_build_ui()
	_apply_values()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12.0, 90.0)
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	add_child(panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	panel.add_child(_content)
	var title_row := HBoxContainer.new()
	_content.add_child(title_row)
	var title := Label.new()
	title.text = "Hybrid Camera3D Debug"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var hide_button := Button.new()
	hide_button.text = "Hide (Ctrl+Shift+F10)"
	hide_button.pressed.connect(func() -> void: _content.get_parent().visible = false)
	title_row.add_child(hide_button)
	_add_slider("yaw", "Yaw", -20.0, 20.0, 0.5)
	_add_slider("pitch", "3D pitch", 25.0, 75.0, 0.5)
	_add_slider("distance", "3D distance", 5.0, 40.0, 0.5)
	var reset_button := Button.new()
	reset_button.text = "Reset defaults"
	reset_button.pressed.connect(_reset_defaults)
	_content.add_child(reset_button)
	var hint := Label.new()
	hint.text = "Ctrl+Shift+F10: show/hide • Debug builds only"
	_content.add_child(hint)

func _add_slider(key: String, label_text: String, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 110.0
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(_values[key])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void: _on_value_changed(key, value))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%.2f" % float(_values[key])
	value_label.custom_minimum_size.x = 48.0
	row.add_child(value_label)
	_sliders[key] = slider
	_value_labels[key] = value_label

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
		and event.keycode == KEY_F10 and event.ctrl_pressed and event.shift_pressed:
		var panel := _content.get_parent()
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func _on_value_changed(key: String, value: float) -> void:
	_values[key] = value
	(_value_labels[key] as Label).text = "%.2f" % value
	_apply_values()

func _apply_values() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.call("apply_hybrid_camera_debug_settings", _values.yaw, _values.pitch, _values.distance)

func _reset_defaults() -> void:
	var defaults := {
		"yaw": DEFAULT_YAW,
		"pitch": DEFAULT_HYBRID_PITCH,
		"distance": HybridCameraDefaultsType.CAMERA_DISTANCE,
	}
	for key: String in defaults:
		_values[key] = defaults[key]
		(_sliders[key] as HSlider).set_value_no_signal(defaults[key])
		(_value_labels[key] as Label).text = "%.2f" % float(defaults[key])
	_apply_values()
