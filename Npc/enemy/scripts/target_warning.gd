extends Node2D
class_name TargetWarning

@export var duration: float = 0.8
@export var radius: float = 52.0
@export var fill_color: Color = Color(1.0, 0.2, 0.2, 0.25)
@export var line_color: Color = Color(1.0, 0.4, 0.25, 0.95)
@export var line_width: float = 2.0

var _elapsed: float = 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= maxf(duration, 0.01):
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var life := clampf(_elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(TAU * 3.0 * life)
	var dynamic_fill := fill_color
	dynamic_fill.a *= (0.45 + 0.35 * pulse)
	var dynamic_line := line_color
	dynamic_line.a *= (0.6 + 0.4 * pulse)
	draw_circle(Vector2.ZERO, radius, dynamic_fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, dynamic_line, maxf(line_width, 1.0), true)
