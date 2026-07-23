class_name GroundConnectionEffect2D
extends Node2D

var _line: Line2D
var _duration: float = 0.16

func configure(start: Vector2, end: Vector2, color: Color, width: float, duration: float = 0.16) -> void:
	global_position = Vector2.ZERO
	_duration = maxf(duration, 0.03)
	_line = Line2D.new()
	_line.name = "ConnectionLine"
	_line.points = PackedVector2Array([start, end])
	_line.default_color = color
	_line.width = maxf(width, 0.5)
	_line.begin_cap_mode = Line2D.LINE_CAP_BOX
	_line.end_cap_mode = Line2D.LINE_CAP_BOX
	_line.antialiased = false
	_line.add_to_group(&"hybrid_ground_segment")
	_line.set_meta("hybrid_ground_visible", true)
	add_child(_line)

func _ready() -> void:
	if _line != null and HybridGroundRegistration.register(_line, &"register_ground_segment"):
		_line.visible = false
	_expire_after_duration()

func _expire_after_duration() -> void:
	await get_tree().create_timer(_duration).timeout
	if is_inside_tree():
		queue_free()

func _exit_tree() -> void:
	if _line != null:
		HybridGroundRegistration.unregister(_line)
