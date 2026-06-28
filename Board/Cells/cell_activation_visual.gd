extends Node2D
class_name CellActivationVisual

const DEFAULT_CELL_RECT := Rect2(Vector2.ZERO, Vector2(512.0, 512.0))
const INACTIVE_MASK := Color(0.035, 0.075, 0.105, 0.58)
const INACTIVE_EDGE := Color(0.36, 0.58, 0.68, 0.26)
const INACTIVE_LINE := Color(0.52, 0.72, 0.78, 0.16)
const ACTIVE_EDGE := Color(0.58, 0.78, 0.82, 0.16)
const ACTIVE_BOUNDARY := Color(0.34, 0.82, 0.92, 0.36)
const PLAYER_EDGE := Color(0.38, 0.88, 1.0, 0.58)
const TASK_NODE := Color(1.0, 0.76, 0.32, 0.44)

var cell_rect: Rect2 = DEFAULT_CELL_RECT:
	set(value):
		cell_rect = value
		queue_redraw()

var _active := true
var _player_highlighted := false
var _has_task := false
var _active_boundary_edges: PackedStringArray = PackedStringArray()

func _ready() -> void:
	z_index = 8
	queue_redraw()

func set_active_visual(active: bool) -> void:
	if _active == active:
		return
	_active = active
	queue_redraw()

func set_player_highlighted(highlighted: bool) -> void:
	if _player_highlighted == highlighted:
		return
	_player_highlighted = highlighted
	queue_redraw()

func set_task_or_objective_present(has_task: bool) -> void:
	if _has_task == has_task:
		return
	_has_task = has_task
	queue_redraw()

func set_active_boundary_edges(edges: PackedStringArray) -> void:
	_active_boundary_edges = edges
	queue_redraw()

func configure(active: bool, highlighted: bool, has_task: bool, new_cell_rect: Rect2 = DEFAULT_CELL_RECT) -> void:
	_active = active
	_player_highlighted = highlighted
	_has_task = has_task
	cell_rect = new_cell_rect
	queue_redraw()

func _draw() -> void:
	if cell_rect.size.x <= 0.0 or cell_rect.size.y <= 0.0:
		return
	if _active:
		_draw_active_state()
	else:
		_draw_inactive_state()
	if _player_highlighted:
		_draw_player_highlight()
	if _has_task:
		_draw_task_presence_node()

func _draw_inactive_state() -> void:
	draw_rect(cell_rect, INACTIVE_MASK, true)
	_draw_corner_code(INACTIVE_EDGE, 16.0, 1.5)
	_draw_power_grid_lines()
	_draw_sleep_nodes()

func _draw_active_state() -> void:
	_draw_corner_code(ACTIVE_EDGE, 32.0, 2.5)
	_draw_active_boundary_edges()

func _draw_player_highlight() -> void:
	var inset_rect := cell_rect.grow(-12.0)
	draw_arc(inset_rect.get_center(), minf(inset_rect.size.x, inset_rect.size.y) * 0.47, -PI * 0.50, TAU * 0.72, 48, PLAYER_EDGE, 3.0, true)
	_draw_corner_code(PLAYER_EDGE, 40.0, 3.0)

func _draw_task_presence_node() -> void:
	var center := cell_rect.position + Vector2(cell_rect.size.x * 0.82, cell_rect.size.y * 0.18)
	draw_circle(center, 5.5, TASK_NODE)
	draw_arc(center, 11.0, 0.0, TAU, 20, Color(TASK_NODE.r, TASK_NODE.g, TASK_NODE.b, 0.28), 1.5, true)

func _draw_corner_code(color: Color, length: float, width: float) -> void:
	var left := cell_rect.position.x + 18.0
	var right := cell_rect.end.x - 18.0
	var top := cell_rect.position.y + 18.0
	var bottom := cell_rect.end.y - 18.0
	var corners := [
		[Vector2(left, top), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(right, top), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(right, bottom), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)],
		[Vector2(left, bottom), Vector2(1.0, 0.0), Vector2(0.0, -1.0)]
	]
	for corner in corners:
		var origin: Vector2 = corner[0]
		var horizontal: Vector2 = corner[1]
		var vertical: Vector2 = corner[2]
		draw_line(origin, origin + horizontal * length, color, width, true)
		draw_line(origin, origin + vertical * length, color, width, true)

func _draw_power_grid_lines() -> void:
	var left := cell_rect.position.x + 72.0
	var right := cell_rect.end.x - 72.0
	var top := cell_rect.position.y + 72.0
	var bottom := cell_rect.end.y - 72.0
	draw_line(Vector2(left, top), Vector2(left + 62.0, top), INACTIVE_LINE, 2.0, true)
	draw_line(Vector2(right - 62.0, top), Vector2(right, top), INACTIVE_LINE, 2.0, true)
	draw_line(Vector2(left, bottom), Vector2(left + 62.0, bottom), INACTIVE_LINE, 2.0, true)
	draw_line(Vector2(right - 62.0, bottom), Vector2(right, bottom), INACTIVE_LINE, 2.0, true)
	draw_line(Vector2(cell_rect.position.x + 96.0, cell_rect.get_center().y), Vector2(cell_rect.position.x + 150.0, cell_rect.get_center().y), INACTIVE_LINE, 1.5, true)
	draw_line(Vector2(cell_rect.end.x - 150.0, cell_rect.get_center().y), Vector2(cell_rect.end.x - 96.0, cell_rect.get_center().y), INACTIVE_LINE, 1.5, true)

func _draw_sleep_nodes() -> void:
	var node_color := Color(INACTIVE_EDGE.r, INACTIVE_EDGE.g, INACTIVE_EDGE.b, 0.22)
	var points := [
		cell_rect.position + Vector2(cell_rect.size.x * 0.28, cell_rect.size.y * 0.28),
		cell_rect.position + Vector2(cell_rect.size.x * 0.72, cell_rect.size.y * 0.28),
		cell_rect.position + Vector2(cell_rect.size.x * 0.72, cell_rect.size.y * 0.72),
		cell_rect.position + Vector2(cell_rect.size.x * 0.28, cell_rect.size.y * 0.72)
	]
	for point in points:
		draw_circle(point, 4.0, node_color)

func _draw_active_boundary_edges() -> void:
	if _active_boundary_edges.is_empty():
		return
	var inset_rect := cell_rect.grow(-8.0)
	for edge in _active_boundary_edges:
		match String(edge):
			"top":
				draw_line(inset_rect.position, Vector2(inset_rect.end.x, inset_rect.position.y), ACTIVE_BOUNDARY, 2.5, true)
			"right":
				draw_line(Vector2(inset_rect.end.x, inset_rect.position.y), inset_rect.end, ACTIVE_BOUNDARY, 2.5, true)
			"bottom":
				draw_line(Vector2(inset_rect.position.x, inset_rect.end.y), inset_rect.end, ACTIVE_BOUNDARY, 2.5, true)
			"left":
				draw_line(inset_rect.position, Vector2(inset_rect.position.x, inset_rect.end.y), ACTIVE_BOUNDARY, 2.5, true)
