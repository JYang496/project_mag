extends Control
class_name EliminationEnemyIndicatorLayer

const Geometry := preload("res://Visual/Oblique/offscreen_indicator_geometry.gd")
const ENEMY_COLOR := Color(1.0, 0.38, 0.16, 0.98)
const OUTLINE_COLOR := Color(0.04, 0.02, 0.02, 0.96)

var _targets: Dictionary = {}
var _elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func set_targets(targets: Dictionary) -> void:
	_targets = targets.duplicate()
	queue_redraw()

func clear() -> void:
	_targets.clear()
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	var viewport_size := get_viewport_rect().size
	if size != viewport_size:
		position = Vector2.ZERO
		size = viewport_size
	_prune_invalid_targets()
	queue_redraw()

func _draw() -> void:
	if _targets.is_empty() or size.x <= 1.0 or size.y <= 1.0:
		return
	var safe_rect := Geometry.make_safe_rect(size)
	for enemy_id in _targets:
		var enemy := _targets[enemy_id] as Node2D
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree() or not enemy.visible:
			continue
		var screen_position := Geometry.project_world_to_screen(get_tree(), get_viewport(), enemy.global_position)
		var state := Geometry.resolve(screen_position, size, safe_rect)
		if bool(state.get("is_inside_viewport", true)):
			continue
		_draw_enemy_arrow(
			state.get("edge_position", safe_rect.get_center()) as Vector2,
			state.get("direction", Vector2.UP) as Vector2
		)

func _draw_enemy_arrow(edge: Vector2, direction: Vector2) -> void:
	var pulse := 0.90 + 0.10 * sin(_elapsed * 4.0)
	var color := Color(ENEMY_COLOR.r, ENEMY_COLOR.g, ENEMY_COLOR.b, ENEMY_COLOR.a * pulse)
	var perpendicular := direction.rotated(PI * 0.5)
	var tip := edge + direction * 7.0
	var left := edge - direction * 13.0 + perpendicular * 10.0
	var right := edge - direction * 13.0 - perpendicular * 10.0
	var arrow := PackedVector2Array([tip, left, right])
	draw_colored_polygon(arrow, color)
	draw_polyline(PackedVector2Array([tip, left, right, tip]), OUTLINE_COLOR, 2.0, true)
	var icon_center := edge - direction * 25.0
	draw_circle(icon_center, 11.0, Color(0.04, 0.02, 0.02, 0.90))
	draw_arc(icon_center, 11.0, 0.0, TAU, 20, color, 2.0, true)
	draw_arc(icon_center, 5.0, 0.0, TAU, 16, color, 1.5, true)
	draw_line(icon_center - Vector2(7.0, 0.0), icon_center + Vector2(7.0, 0.0), color, 1.5, true)
	draw_line(icon_center - Vector2(0.0, 7.0), icon_center + Vector2(0.0, 7.0), color, 1.5, true)

func _prune_invalid_targets() -> void:
	for enemy_id in _targets.keys():
		var enemy := _targets[enemy_id] as Node
		if enemy == null or not is_instance_valid(enemy):
			_targets.erase(enemy_id)
