extends Node2D
class_name MuzzleFlashVfx

@export var color: Color = Color(1.0, 0.84, 0.35, 0.9)
@export var secondary_color: Color = Color(1.0, 0.35, 0.12, 0.45)
@export var length_px: float = 28.0
@export var width_px: float = 14.0
@export var duration_sec: float = 0.08
@export var smoke_color: Color = Color(0.45, 0.45, 0.45, 0.28)
@export var smoke_radius: float = 0.0

var _age_sec: float = 0.0


func setup(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	_age_sec = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_age_sec += maxf(delta, 0.0)
	if _age_sec >= maxf(duration_sec, 0.001):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_age_sec / maxf(duration_sec, 0.001), 0.0, 1.0)
	var alpha_mul := 1.0 - progress
	var flare_points: PackedVector2Array = [
		Vector2.ZERO,
		Vector2(length_px, -width_px * 0.5),
		Vector2(length_px * 0.72, 0.0),
		Vector2(length_px, width_px * 0.5),
	]
	var inner_points: PackedVector2Array = [
		Vector2.ZERO,
		Vector2(length_px * 0.55, -width_px * 0.22),
		Vector2(length_px * 0.9, 0.0),
		Vector2(length_px * 0.55, width_px * 0.22),
	]
	var outer := secondary_color
	outer.a *= alpha_mul
	var inner := color
	inner.a *= alpha_mul
	draw_colored_polygon(flare_points, outer)
	draw_colored_polygon(inner_points, inner)
	if smoke_radius > 0.0:
		var smoke := smoke_color
		smoke.a *= alpha_mul * 0.8
		draw_circle(Vector2(-length_px * 0.12, 0.0), smoke_radius * (0.7 + progress * 0.5), smoke)
