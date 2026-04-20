extends Node2D
class_name TargetWarning

enum VisualPreset {
	BASIC = 0,
	DODGE_STYLE = 1,
}

@export var visual_preset: VisualPreset = VisualPreset.BASIC
@export var duration: float = 0.8
@export var radius: float = 52.0
@export var fill_color: Color = Color(1.0, 0.2, 0.2, 0.25)
@export var line_color: Color = Color(1.0, 0.4, 0.25, 0.95)
@export var line_width: float = 2.0
@export var wave_color: Color = Color(1.0, 0.92, 0.74, 0.95)

var _elapsed: float = 0.0
var _fill_polygon: Polygon2D = null
var _outline_line: Line2D = null
var _wave_line: Line2D = null

func _ready() -> void:
	add_to_group("enemy_runtime_cleanup")
	if visual_preset == VisualPreset.DODGE_STYLE:
		_build_dodge_style_visuals()
	set_process(true)
	if visual_preset == VisualPreset.BASIC:
		queue_redraw()

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= maxf(duration, 0.01):
		queue_free()
		return
	if visual_preset == VisualPreset.BASIC:
		queue_redraw()

func _draw() -> void:
	if visual_preset != VisualPreset.BASIC:
		return
	var life := clampf(_elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(TAU * 3.0 * life)
	var dynamic_fill := fill_color
	dynamic_fill.a *= (0.45 + 0.35 * pulse)
	var dynamic_line := line_color
	dynamic_line.a *= (0.6 + 0.4 * pulse)
	draw_circle(Vector2.ZERO, radius, dynamic_fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, dynamic_line, maxf(line_width, 1.0), true)

func _build_dodge_style_visuals() -> void:
	var safe_radius := maxf(radius, 8.0)
	_fill_polygon = Polygon2D.new()
	_fill_polygon.color = fill_color
	_fill_polygon.polygon = _build_circle_polygon(safe_radius, 28)
	add_child(_fill_polygon)

	_outline_line = Line2D.new()
	_outline_line.width = maxf(line_width + 1.0, 2.0)
	_outline_line.default_color = line_color
	_outline_line.closed = true
	_outline_line.points = _build_circle_polygon(safe_radius, 28)
	add_child(_outline_line)

	_wave_line = Line2D.new()
	_wave_line.width = maxf(line_width + 2.0, 3.0)
	_wave_line.default_color = wave_color
	_wave_line.closed = true
	_wave_line.points = _build_circle_polygon(safe_radius, 24)
	_wave_line.scale = Vector2.ZERO
	add_child(_wave_line)

	var safe_duration := maxf(duration, 0.05)
	var pulse_tween := create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(_fill_polygon, "color:a", fill_color.a * 1.6, maxf(safe_duration * 0.5, 0.05))
	pulse_tween.tween_property(_fill_polygon, "color:a", fill_color.a, maxf(safe_duration * 0.5, 0.05))

	var wave_tween := create_tween()
	wave_tween.tween_property(_wave_line, "scale", Vector2.ONE, safe_duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	wave_tween.parallel().tween_property(_wave_line, "default_color:a", 0.12, safe_duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

func _build_circle_polygon(target_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count: int = maxi(segments, 8)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * target_radius)
	return points
