extends Node2D
class_name OrbitEnergyFieldIndicator

@export var radius: float = 84.0
@export var fill_color: Color = Color(0.45, 0.8, 1.0, 0.10)
@export var outline_color: Color = Color(0.45, 0.9, 1.0, 0.75)
@export var outline_width: float = 1.5

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var draw_radius: float = maxf(radius, 1.0)
	draw_circle(Vector2.ZERO, draw_radius, fill_color)
	draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, 48, outline_color, maxf(outline_width, 0.5))
