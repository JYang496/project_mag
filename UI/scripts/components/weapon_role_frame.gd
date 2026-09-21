extends Control

const MAINHAND_AMMO_COLOR := Color("73e7ef")

@onready var _surface: ColorRect = $Surface

var selected := false:
	set(value):
		if selected == value:
			return
		selected = value
		_apply_shader_state()

var ammo_visible := false
var ammo_progress := 0.0
var ammo_fill_color := MAINHAND_AMMO_COLOR
var ammo_track_color := Color(0.12, 0.30, 0.34, 0.72)

func _ready() -> void:
	_surface.material = _surface.material.duplicate()
	_apply_shader_state()

func set_ammo_state(visible_value: bool, progress_value: float, fill: Color, track: Color) -> void:
	var next_progress := clampf(progress_value, 0.0, 1.0)
	if ammo_visible == visible_value \
			and is_equal_approx(ammo_progress, next_progress) \
			and ammo_fill_color == fill and ammo_track_color == track:
		return
	ammo_visible = visible_value
	ammo_progress = next_progress
	ammo_fill_color = fill
	ammo_track_color = track
	_apply_shader_state()

func _apply_shader_state() -> void:
	if not is_node_ready():
		return
	var material := _surface.material as ShaderMaterial
	material.set_shader_parameter("selected", selected)
	material.set_shader_parameter("ammo_visible", ammo_visible)
	material.set_shader_parameter("ammo_progress", ammo_progress)
	material.set_shader_parameter("ammo_fill_color", ammo_fill_color)
	material.set_shader_parameter("ammo_track_color", ammo_track_color)
