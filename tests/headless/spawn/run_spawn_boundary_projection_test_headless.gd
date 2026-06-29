extends Node

const BoardScript := preload("res://World/board_cell_generator.gd")
const CellScene := preload("res://Board/Cells/cell.tscn")

var _board: BoardCellGenerator

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_board = BoardScript.new() as BoardCellGenerator
	_board.cell_scene = CellScene
	get_tree().root.add_child(_board)
	await get_tree().process_frame

	_board.set("_active_cell_ids", PackedInt32Array([5, 6]))
	_board.call("_apply_active_cell_flags")
	await get_tree().process_frame

	var cell := _board.get_cell_by_logical_id(5)
	if cell == null:
		_fail("missing test cell 5")
		return
	var capture_polygon := cell.get_node_or_null("Area2D/CapturePolygon") as CollisionPolygon2D
	if capture_polygon == null or capture_polygon.polygon.is_empty():
		_fail("cell 5 missing capture polygon")
		return

	var aabb := _get_polygon_local_aabb(capture_polygon.polygon)
	var center_local := aabb.get_center()
	var left_boundary_local := Vector2(aabb.position.x + 2.0, center_local.y)
	var left_boundary_world := capture_polygon.global_transform * left_boundary_local
	var projected_left := _board.project_point_to_enemy_traversable_area_with_margin(left_boundary_world, 28.0)
	var projected_left_local := capture_polygon.global_transform.affine_inverse() * projected_left
	if projected_left_local.x < aabb.position.x + 27.5:
		_fail("inactive left boundary point was not moved away from the active boundary wall")
		return

	var center_world := capture_polygon.global_transform * center_local
	var projected_center := _board.project_point_to_enemy_traversable_area_with_margin(center_world, 28.0)
	if projected_center.distance_squared_to(center_world) > 0.01:
		_fail("center point drifted during enemy traversable projection")
		return

	var right_active_neighbor_local := Vector2(aabb.end.x - 2.0, center_local.y)
	var right_active_neighbor_world := capture_polygon.global_transform * right_active_neighbor_local
	var projected_right := _board.project_point_to_enemy_traversable_area_with_margin(right_active_neighbor_world, 28.0)
	if projected_right.distance_squared_to(right_active_neighbor_world) > 0.01:
		_fail("edge shared with another active cell should not be pushed inward")
		return

	print("PASS: spawn boundary projection keeps enemies off active boundary walls")
	get_tree().quit(0)

func _get_polygon_local_aabb(polygon_points: PackedVector2Array) -> Rect2:
	if polygon_points.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_x := polygon_points[0].x
	var max_x := polygon_points[0].x
	var min_y := polygon_points[0].y
	var max_y := polygon_points[0].y
	for point in polygon_points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _fail(message: String) -> void:
	push_error("SpawnBoundaryProjectionTest: %s" % message)
	get_tree().quit(1)
