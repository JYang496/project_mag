extends Node2D
class_name OrbitEnergyFieldIndicator

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")

@export var radius: float = 84.0
@export var fill_color: Color = PALETTE.PLAYER_RANGE_FILL
@export var outline_color: Color = PALETTE.PLAYER_RANGE_OUTLINE
@export var outline_width: float = PALETTE.PLAYER_RANGE_LINE_WIDTH

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var draw_radius: float = maxf(radius, 1.0)
	draw_circle(Vector2.ZERO, draw_radius, fill_color)
	draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, 24, outline_color, maxf(roundf(outline_width), 1.0), false)
