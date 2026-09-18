extends Node2D
## Manual visual showcase using the actual HeavyAssault scene and skill.
const MECHA := preload("res://Player/Mechas/scenes/heavy_assault.tscn")
const DASH_SPEED_PROFILE := preload("res://Player/Skills/dash_speed_profile.gd")
var _player: Player
var _skill: HeavyAssaultHeatLock
var _fixed_camera: Camera2D
var _elapsed := 1.3
var _index := 0
var _automatic := true
var _capture_path := ""
var _captured := false
var _dash_age := -1.0
var _label: Label
var _parameter_label: Label
var _sliders: Dictionary = {}
var _start_multiplier := 0.0
var _peak_time := 0.40
var _peak_multiplier := 2.50
var _end_multiplier := 1.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101b29"))
	PhaseManager.phase = PhaseManager.BATTLE
	PlayerData.player_speed = 95.0
	_player = MECHA.instantiate()
	_player.position = Vector2(430, 360)
	add_child(_player)
	_install_fixed_showcase_camera()
	_skill = _player.get_node("ActiveSkill/HeavyAssaultHeatLock")
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 24)
	_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_label)
	_build_parameter_panel(layer)
	_apply_parameters()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--jet-capture="):
			_capture_path = argument.trim_prefix("--jet-capture=")
	queue_redraw()


func _install_fixed_showcase_camera() -> void:
	# The production player owns a following camera. This showcase replaces only
	# its viewport ownership so dash distance and acceleration can be judged
	# against a stationary grid.
	if _player.player_camera != null:
		_player.player_camera.enabled = false
	_fixed_camera = Camera2D.new()
	_fixed_camera.name = "FixedShowcaseCamera"
	_fixed_camera.position = Vector2(640, 360)
	_fixed_camera.zoom = Vector2.ONE
	_fixed_camera.position_smoothing_enabled = false
	_fixed_camera.enabled = true
	add_child(_fixed_camera)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_automatic = false
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_automatic = not _automatic

func _process(delta: float) -> void:
	_elapsed += delta
	var status := _player.get_movement_status()
	var speed := (status.get("velocity", Vector2.ZERO) as Vector2).length()
	_label.text = "JET DASH CURVE LAB\nWASD + SPACE: manual dash   TAB: auto showcase\nLive speed: %d units/s   Mode: %s" % [speed, str(status.get("mode", &"idle"))]
	if _automatic and _elapsed > 2.0:
		_elapsed = 0.0
		_player.position = Vector2(430, 360)
		_player.velocity = Vector2.ZERO
		var direction := Vector2.RIGHT.rotated(float(_index) * PI / 4.0)
		_index = (_index + 1) % 8
		_player.velocity = direction
		_skill.force_cooldown_ready()
		_player.add_energy(100.0)
		_skill._on_player_active_skill_requested()
		_dash_age = 0.0
	if _dash_age >= 0.0:
		_dash_age += delta
		if not _captured and not _capture_path.is_empty() and _dash_age > 0.09:
			_captured = true
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_capture_path)

func _draw() -> void:
	for x in range(0, 1281, 40):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color("1b2b3c"))
	for y in range(0, 721, 40):
		draw_line(Vector2(0, y), Vector2(1280, y), Color("1b2b3c"))
	var graph_rect := Rect2(910, 470, 330, 180)
	draw_rect(graph_rect, Color("09131f"), true)
	draw_rect(graph_rect, Color("557089"), false, 2.0)
	draw_line(Vector2(graph_rect.position.x, graph_rect.end.y), graph_rect.end, Color("91a9bd"), 1.0)
	draw_line(graph_rect.position, Vector2(graph_rect.position.x, graph_rect.end.y), Color("91a9bd"), 1.0)
	if _skill == null or _skill.dash_speed_curve == null:
		return
	var points := PackedVector2Array()
	for index in range(65):
		var progress := float(index) / 64.0
		var multiplier := _skill.dash_speed_curve.sample_baked(progress)
		points.append(Vector2(
			graph_rect.position.x + progress * graph_rect.size.x,
			graph_rect.end.y - clampf(multiplier / 2.5, 0.0, 1.0) * graph_rect.size.y
		))
	draw_polyline(points, Color("58d6ff"), 3.0, true)


func _build_parameter_panel(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(890, 18)
	panel.custom_minimum_size = Vector2(370, 430)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var title := Label.new()
	title.text = "RUNTIME PARAMETERS"
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	_add_slider(column, "duration", "Duration (s)", 0.08, 0.60, 0.01, _skill.dash_duration_sec)
	_add_slider(column, "distance", "Distance", 30.0, 240.0, 1.0, _skill.dash_distance)
	_add_slider(column, "start", "Start speed", 0.0, 1.5, 0.01, _start_multiplier)
	_add_slider(column, "peak_time", "Peak time", 0.25, 0.75, 0.01, _peak_time)
	_add_slider(column, "peak", "Peak speed", 0.5, 2.5, 0.01, _peak_multiplier)
	_add_slider(column, "end", "End speed", 0.0, 1.5, 0.01, _end_multiplier)
	_parameter_label = Label.new()
	_parameter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_parameter_label.custom_minimum_size.y = 46
	column.add_child(_parameter_label)
	var reset_button := Button.new()
	reset_button.text = "Reset illustrated profile"
	reset_button.pressed.connect(_reset_parameters)
	column.add_child(reset_button)


func _add_slider(
	parent: VBoxContainer,
	key: StringName,
	title: String,
	minimum: float,
	maximum: float,
	step: float,
	value: float
) -> void:
	var label := Label.new()
	label.name = "%sLabel" % key
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = 330
	slider.value_changed.connect(_on_parameter_changed.bind(key, title, label))
	parent.add_child(slider)
	_sliders[key] = slider
	_update_slider_label(label, title, value)


func _on_parameter_changed(value: float, key: StringName, title: String, label: Label) -> void:
	_update_slider_label(label, title, value)
	match key:
		&"duration":
			_skill.dash_duration_sec = value
		&"distance":
			_skill.dash_distance = value
		&"start":
			_start_multiplier = value
		&"peak_time":
			_peak_time = value
		&"peak":
			_peak_multiplier = value
		&"end":
			_end_multiplier = value
	_apply_parameters()


func _update_slider_label(label: Label, title: String, value: float) -> void:
	label.text = "%s: %.2f" % [title, value]


func _apply_parameters() -> void:
	_skill.dash_speed_curve = DASH_SPEED_PROFILE.create_curve(
		_start_multiplier,
		_peak_time,
		_peak_multiplier,
		_end_multiplier
	)
	if _parameter_label != null:
		_parameter_label.text = "Curve area is normalized: duration and distance remain authoritative."
	queue_redraw()


func _reset_parameters() -> void:
	_start_multiplier = 0.0
	_peak_time = 0.40
	_peak_multiplier = 2.50
	_end_multiplier = 1.0
	var defaults := {
		&"duration": 0.40,
		&"distance": 100.0,
		&"start": _start_multiplier,
		&"peak_time": _peak_time,
		&"peak": _peak_multiplier,
		&"end": _end_multiplier,
	}
	for key in defaults:
		(_sliders[key] as HSlider).value = defaults[key]
	_apply_parameters()
