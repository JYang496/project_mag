extends Node2D
class_name AffiliationMarker

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")

enum MarkerShape {
	PLAYER_RING,
	ENEMY_BRACKETS,
	FRIENDLY_FRAME,
	NEUTRAL_DASHES,
}

@export var marker_shape: MarkerShape = MarkerShape.ENEMY_BRACKETS:
	set(value):
		marker_shape = value
		queue_redraw()
@export var marker_color: Color = PALETTE.ENEMY_PRIMARY:
	set(value):
		marker_color = value
		queue_redraw()
@export_range(8.0, 48.0, 1.0) var radius := 20.0:
	set(value):
		radius = value
		queue_redraw()
@export_range(1.0, 5.0, 0.5) var line_width := 2.0:
	set(value):
		line_width = value
		queue_redraw()
@export_range(0.1, 1.2, 0.05) var arc_length := 0.46:
	set(value):
		arc_length = value
		queue_redraw()


func _ready() -> void:
	z_as_relative = true
	z_index = -1
	queue_redraw()


func _draw() -> void:
	match marker_shape:
		MarkerShape.PLAYER_RING:
			_draw_player_ring()
		MarkerShape.FRIENDLY_FRAME:
			_draw_friendly_frame()
		MarkerShape.NEUTRAL_DASHES:
			_draw_neutral_dashes()
		_:
			_draw_enemy_brackets()


func _draw_player_ring() -> void:
	var gap := 0.54
	draw_arc(
		Vector2.ZERO,
		radius,
		-PI * 0.5 + gap,
		PI * 1.5 - gap,
		40,
		marker_color,
		line_width,
		true
	)
	draw_circle(Vector2(0.0, -radius), line_width * 0.75, PALETTE.PLAYER_CORE)


func _draw_enemy_brackets() -> void:
	for index in range(4):
		var center_angle := PI * 0.25 + float(index) * PI * 0.5
		draw_arc(
			Vector2.ZERO,
			radius,
			center_angle - arc_length * 0.5,
			center_angle + arc_length * 0.5,
			7,
			marker_color,
			line_width,
			true
		)
		var tip := Vector2.RIGHT.rotated(center_angle) * (radius - 3.0)
		var inward := -Vector2.RIGHT.rotated(center_angle) * 4.0
		draw_line(tip, tip + inward, marker_color, line_width, true)


func _draw_friendly_frame() -> void:
	var size := Vector2.ONE * radius * 1.35
	var rect := Rect2(-size * 0.5, size)
	draw_style_box(_make_frame_style(), rect)


func _draw_neutral_dashes() -> void:
	for index in range(8):
		var start_angle := float(index) * TAU / 8.0
		draw_arc(
			Vector2.ZERO,
			radius,
			start_angle,
			start_angle + 0.34,
			4,
			marker_color,
			line_width,
			true
		)


func _make_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = marker_color
	style.set_border_width_all(int(ceilf(line_width)))
	style.set_corner_radius_all(5)
	return style
