extends Node2D
class_name MuzzleFlashVfx

signal finished

enum ShapeStyle { BALLISTIC, ENERGY, PLASMA_EXOTIC }

@export var color: Color = Color(1.0, 0.84, 0.35, 0.9)
@export var secondary_color: Color = Color(1.0, 0.35, 0.12, 0.45)
@export var length_px: float = 28.0
@export var width_px: float = 14.0
@export var duration_sec: float = 0.08
@export var smoke_color: Color = Color(0.45, 0.45, 0.45, 0.28)
@export var smoke_radius: float = 0.0
@export var shape_style: ShapeStyle = ShapeStyle.BALLISTIC
@export_enum("32", "64") var source_size_px := 32

var _age_sec: float = 0.0
var _pooled := false
var _base_color := Color.WHITE
var _base_secondary_color := Color.WHITE
var _base_length_px := 0.0
var _base_width_px := 0.0
var _base_scale := Vector2.ONE
var _signature_style := 0


func _ready() -> void:
	_base_color = color
	_base_secondary_color = secondary_color
	_base_length_px = length_px
	_base_width_px = width_px
	_base_scale = scale


func apply_signature(signature: Dictionary) -> void:
	var tint := signature.get("tint", Color.WHITE) as Color
	var tint_strength := clampf(float(signature.get("tint_strength", 0.0)), 0.0, 0.65)
	color = _base_color.lerp(_base_color * tint, tint_strength)
	secondary_color = _base_secondary_color.lerp(_base_secondary_color * tint, tint_strength)
	length_px = _base_length_px * clampf(float(signature.get("length_scale", 1.0)), 0.65, 1.6)
	width_px = _base_width_px * clampf(float(signature.get("width_scale", 1.0)), 0.65, 1.6)
	scale = _base_scale * clampf(float(signature.get("scale", 1.0)), 0.65, 1.6)
	_signature_style = clampi(int(signature.get("signature_style", 0)), 0, 4)


func setup(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	_age_sec = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func prepare_for_pool() -> void:
	_pooled = true


func _process(delta: float) -> void:
	_age_sec += maxf(delta, 0.0)
	if _age_sec >= maxf(duration_sec, 0.001):
		if _pooled:
			visible = false
			set_process(false)
			finished.emit()
		else:
			queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_age_sec / maxf(duration_sec, 0.001), 0.0, 1.0)
	var alpha_mul := 1.0 - progress
	match shape_style:
		ShapeStyle.ENERGY:
			_draw_energy(alpha_mul, progress)
		ShapeStyle.PLASMA_EXOTIC:
			_draw_plasma(alpha_mul, progress)
		_:
			_draw_ballistic(alpha_mul, progress)
	_draw_rare_signature(alpha_mul, progress)


func _draw_rare_signature(alpha_mul: float, progress: float) -> void:
	if _signature_style == 0:
		return
	var accent := color
	accent.a *= alpha_mul * 0.82
	match _signature_style:
		1:
			for angle in [0.0, PI * 0.5, PI * 0.25, -PI * 0.25]:
				var direction := Vector2.RIGHT.rotated(float(angle))
				draw_line(direction * 3.0, direction * (width_px * 0.72 + progress * 3.0), accent, 1.0, false)
		2:
			for index in range(3):
				var ember_pos := Vector2(length_px * (0.20 + index * 0.20), (float(index) - 1.0) * width_px * 0.20)
				draw_circle(ember_pos, 1.5 + progress * 1.5, accent)
		3:
			var arc_points := PackedVector2Array([Vector2.ZERO, Vector2(length_px * 0.28, -width_px * 0.34), Vector2(length_px * 0.55, width_px * 0.22), Vector2(length_px * 0.84, -width_px * 0.14)])
			draw_polyline(arc_points, accent, 1.5, false)
		4:
			draw_line(Vector2.ZERO, Vector2(length_px * 0.82, -width_px * 0.30), accent, 1.5, false)
			draw_line(Vector2.ZERO, Vector2(length_px * 0.82, width_px * 0.30), accent, 1.5, false)


func _draw_ballistic(alpha_mul: float, progress: float) -> void:
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


func _draw_energy(alpha_mul: float, progress: float) -> void:
	var outer := secondary_color
	outer.a *= alpha_mul
	var inner := color
	inner.a *= alpha_mul
	var radius := width_px * (0.30 + progress * 0.18)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, outer, 2.0, false)
	draw_rect(Rect2(Vector2.ZERO, Vector2(length_px, 2.0)), inner, true)
	draw_rect(Rect2(Vector2(length_px * 0.18, -width_px * 0.18), Vector2(length_px * 0.52, width_px * 0.36)), outer, false, 2.0)
	draw_circle(Vector2(length_px * 0.88, 0.0), maxf(width_px * 0.12, 2.0), inner)


func _draw_plasma(alpha_mul: float, progress: float) -> void:
	var outer := secondary_color
	outer.a *= alpha_mul
	var inner := color
	inner.a *= alpha_mul
	var spread := width_px * (0.42 + progress * 0.12)
	var upper := PackedVector2Array([Vector2.ZERO, Vector2(length_px * 0.48, -spread), Vector2(length_px, -width_px * 0.12)])
	var lower := PackedVector2Array([Vector2.ZERO, Vector2(length_px * 0.48, spread), Vector2(length_px, width_px * 0.12)])
	draw_polyline(upper, outer, 3.0, false)
	draw_polyline(lower, outer, 3.0, false)
	draw_rect(Rect2(Vector2.ZERO, Vector2(length_px * 0.88, 3.0)), inner, true)
	draw_circle(Vector2(length_px * 0.36, 0.0), maxf(width_px * 0.18, 2.0), inner)
