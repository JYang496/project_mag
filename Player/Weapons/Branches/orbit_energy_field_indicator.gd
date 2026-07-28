extends Node2D
class_name OrbitEnergyFieldIndicator

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")

@export var radius: float = 84.0
@export var fill_color: Color = Color(PALETTE.ENERGY, 0.10)
@export var outline_color: Color = Color(PALETTE.PLAYER_PRIMARY, 0.52)
@export var outline_width: float = 1.5

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var draw_radius: float = maxf(radius, 1.0)
	draw_circle(Vector2.ZERO, draw_radius, fill_color)
	draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, 24, outline_color, maxf(roundf(outline_width), 1.0), false)
