extends Node2D
class_name TargetWarning

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")

enum VisualPreset {
	BASIC = 0,
	DODGE_STYLE = 1,
}

@export var visual_preset: VisualPreset = VisualPreset.BASIC
@export var duration: float = 0.8
@export var radius: float = 52.0
@export var fill_color: Color = Color(PALETTE.ENEMY_PRIMARY, 0.10)
@export var line_color: Color = Color(PALETTE.ENEMY_PRIMARY, 0.96)
@export var line_width: float = 2.5
@export var wave_color: Color = Color(PALETTE.ENEMY_SECONDARY, 0.98)
@export_range(8.0, 12.0, 1.0) var center_marker_diameter: float = 10.0

var _elapsed: float = 0.0
var _fill_polygon: Polygon2D = null
var _outline_line: Line2D = null
var _wave_line: Line2D = null

func _ready() -> void:
	add_to_group("enemy_runtime_cleanup")
	add_to_group(&"hybrid_ground_warning_circle")
	if visual_preset == VisualPreset.DODGE_STYLE:
		_build_dodge_style_visuals()
	set_process(true)
	if visual_preset == VisualPreset.BASIC:
		queue_redraw()
	call_deferred("_register_with_hybrid_ground")

func _register_with_hybrid_ground() -> void:
	if HybridGroundRegistration.register(self, &"register_warning_circle"):
		visible = false

func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= maxf(duration, 0.01):
		queue_free()
		return
	if visual_preset == VisualPreset.BASIC:
		queue_redraw()

func get_warning_progress() -> float:
	return clampf(_elapsed / maxf(duration, 0.01), 0.0, 1.0)

func _draw() -> void:
	if visual_preset != VisualPreset.BASIC:
		return
	var life := clampf(_elapsed / maxf(duration, 0.01), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, line_color, maxf(roundf(line_width), 1.0), false)
	var remaining := 1.0 - life
	draw_arc(Vector2.ZERO, radius * remaining, 0.0, TAU, 24, wave_color, maxf(roundf(line_width + 1.0), 2.0), false)
	draw_circle(Vector2.ZERO, center_marker_diameter * 0.5, line_color)

func _build_dodge_style_visuals() -> void:
	var safe_radius := maxf(radius, 8.0)
	_fill_polygon = Polygon2D.new()
	_fill_polygon.name = "DangerFill"
	_fill_polygon.color = fill_color
	_fill_polygon.polygon = _build_circle_polygon(safe_radius, 28)
	add_child(_fill_polygon)

	_outline_line = Line2D.new()
	_outline_line.name = "DamageBoundary"
	_outline_line.width = maxf(line_width + 1.0, 2.0)
	_outline_line.default_color = line_color
	_outline_line.closed = true
	_outline_line.points = _build_circle_polygon(safe_radius, 28)
	_outline_line.antialiased = false
	add_child(_outline_line)

	_wave_line = Line2D.new()
	_wave_line.name = "CountdownRing"
	_wave_line.width = maxf(line_width + 2.0, 3.0)
	_wave_line.default_color = wave_color
	_wave_line.closed = true
	_wave_line.points = _build_circle_polygon(safe_radius, 24)
	_wave_line.antialiased = false
	_wave_line.scale = Vector2.ONE
	add_child(_wave_line)

	var center_marker := Polygon2D.new()
	center_marker.name = "CenterMarker"
	center_marker.color = line_color
	center_marker.polygon = _build_circle_polygon(center_marker_diameter * 0.5, 12)
	add_child(center_marker)

	var safe_duration := maxf(duration, 0.05)
	var wave_tween := create_tween()
	wave_tween.tween_property(_wave_line, "scale", Vector2.ZERO, safe_duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

func _build_circle_polygon(target_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count: int = maxi(segments, 8)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * target_radius)
	return points
