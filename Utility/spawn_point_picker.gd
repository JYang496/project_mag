extends RefCounted
class_name SpawnPointPicker

var owner: Node2D
var board: Node
var top_left_marker: Node2D
var bottom_right_marker: Node2D
var min_spawn_distance_from_player: float = 180.0
var spawn_point_attempts_per_enemy: int = 12
var spawn_edge_margin: float = 28.0
var board_cells: Array[Cell] = []
var last_spawn_cell: Cell = null
var x_min: float = 0.0
var y_min: float = 0.0
var x_max: float = 0.0
var y_max: float = 0.0

func bind(spawner: Node2D, board_node: Node, top_left: Node2D, bottom_right: Node2D) -> void:
	owner = spawner
	board = board_node
	top_left_marker = top_left
	bottom_right_marker = bottom_right

func configure(min_distance: float, attempts_per_enemy: int, edge_margin: float) -> void:
	min_spawn_distance_from_player = min_distance
	spawn_point_attempts_per_enemy = attempts_per_enemy
	spawn_edge_margin = edge_margin

func get_random_position() -> Vector2:
	var player: Player = PlayerData.player
	if player == null:
		last_spawn_cell = null
		return Vector2.ZERO
	refresh_fallback_bounds()
	var spawn_cell := pick_spawn_cell_near_player(player)
	if spawn_cell:
		last_spawn_cell = spawn_cell
		return apply_spawn_safety_margin(get_random_point_in_cell_away_from_player(spawn_cell, player.global_position))
	last_spawn_cell = null
	return apply_spawn_safety_margin(get_fallback_spawn_position(player))

func cache_board_cells() -> void:
	board_cells.clear()
	if board:
		for child in board.get_children():
			if child is Cell:
				board_cells.append(child)
	refresh_fallback_bounds()

func refresh_fallback_bounds() -> void:
	var bounds_set := false
	var min_x := 0.0
	var min_y := 0.0
	var max_x := 0.0
	var max_y := 0.0
	var effective_cells := get_effective_board_cells()
	for cell in effective_cells:
		if cell == null:
			continue
		var cell_rect: Rect2 = get_cell_aabb(cell)
		if cell_rect.size == Vector2.ZERO:
			continue
		if not bounds_set:
			min_x = cell_rect.position.x
			min_y = cell_rect.position.y
			max_x = cell_rect.end.x
			max_y = cell_rect.end.y
			bounds_set = true
			continue
		min_x = minf(min_x, cell_rect.position.x)
		min_y = minf(min_y, cell_rect.position.y)
		max_x = maxf(max_x, cell_rect.end.x)
		max_y = maxf(max_y, cell_rect.end.y)
	if not bounds_set:
		if top_left_marker != null and bottom_right_marker != null:
			min_x = minf(top_left_marker.global_position.x, bottom_right_marker.global_position.x)
			min_y = minf(top_left_marker.global_position.y, bottom_right_marker.global_position.y)
			max_x = maxf(top_left_marker.global_position.x, bottom_right_marker.global_position.x)
			max_y = maxf(top_left_marker.global_position.y, bottom_right_marker.global_position.y)
		else:
			min_x = -1000.0
			min_y = -1000.0
			max_x = 1000.0
			max_y = 1000.0
	x_min = min_x
	y_min = min_y
	x_max = max_x
	y_max = max_y

func pick_spawn_cell_near_player(player: Player) -> Cell:
	var effective_cells := get_effective_board_cells()
	if effective_cells.is_empty():
		cache_board_cells()
		effective_cells = get_effective_board_cells()
	if effective_cells.is_empty():
		return null
	var player_position := player.global_position
	var player_cell := get_cell_at_position(player_position, effective_cells)
	var neighbor_cells := get_neighbor_cells(player_cell, effective_cells)
	var neighbor_candidates: Array[Cell] = []
	var fallback_candidates: Array[Cell] = []
	for cell in effective_cells:
		if cell == null:
			continue
		if cell == player_cell:
			continue
		if not cell_can_spawn_away_from_player(cell, player_position):
			continue
		if not neighbor_cells.is_empty() and neighbor_cells.has(cell):
			neighbor_candidates.append(cell)
		else:
			fallback_candidates.append(cell)
	if not neighbor_candidates.is_empty():
		return neighbor_candidates.pick_random()
	if not fallback_candidates.is_empty():
		return fallback_candidates.pick_random()
	return null

func get_cell_at_position(position: Vector2, cells: Array[Cell]) -> Cell:
	for cell in cells:
		if cell_contains_point(cell, position):
			return cell
	return null

func cell_contains_point(cell: Cell, position: Vector2) -> bool:
	if cell == null:
		return false
	var capture_polygon: CollisionPolygon2D = get_cell_capture_polygon(cell)
	if capture_polygon:
		return is_point_inside_capture_polygon(capture_polygon, position)
	var collision_shape: CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape == null:
		return false
	var rect_shape := collision_shape.shape
	if rect_shape is RectangleShape2D:
		var half_size = rect_shape.size * 0.5
		var local_point = collision_shape.global_transform.affine_inverse() * position
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y
	return false

func get_random_point_in_cell(cell: Cell) -> Vector2:
	var capture_polygon: CollisionPolygon2D = get_cell_capture_polygon(cell)
	if capture_polygon:
		return get_random_point_in_capture_polygon(capture_polygon)
	var collision_shape: CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = collision_shape.shape
		var half_size = rect_shape.size * 0.5
		var random_local = Vector2(
			randf_range(-half_size.x, half_size.x),
			randf_range(-half_size.y, half_size.y)
		)
		return collision_shape.global_transform * random_local
	return cell.global_position

func get_random_point_in_cell_away_from_player(cell: Cell, player_position: Vector2) -> Vector2:
	var attempts: int = max(spawn_point_attempts_per_enemy, 1)
	var best_point: Vector2 = get_random_point_in_cell(cell)
	var best_distance: float = best_point.distance_to(player_position)
	for _i in range(attempts):
		var candidate: Vector2 = get_random_point_in_cell(cell)
		var distance_to_player: float = candidate.distance_to(player_position)
		if distance_to_player >= min_spawn_distance_from_player:
			return candidate
		if distance_to_player > best_distance:
			best_distance = distance_to_player
			best_point = candidate
	return best_point

func cell_can_spawn_away_from_player(cell: Cell, player_position: Vector2) -> bool:
	var cell_rect: Rect2 = get_cell_aabb(cell)
	if cell_rect.size == Vector2.ZERO:
		return cell.global_position.distance_to(player_position) >= min_spawn_distance_from_player
	var farthest_point := Vector2(
		cell_rect.position.x if absf(player_position.x - cell_rect.position.x) > absf(player_position.x - cell_rect.end.x) else cell_rect.end.x,
		cell_rect.position.y if absf(player_position.y - cell_rect.position.y) > absf(player_position.y - cell_rect.end.y) else cell_rect.end.y
	)
	return farthest_point.distance_to(player_position) >= min_spawn_distance_from_player

func get_neighbor_cells(player_cell: Cell, cells: Array[Cell]) -> Array[Cell]:
	var neighbors: Array[Cell] = []
	if player_cell == null:
		return neighbors
	var max_neighbor_distance: float = estimate_neighbor_distance(player_cell, cells)
	for cell in cells:
		if cell == null or cell == player_cell:
			continue
		if cell.global_position.distance_to(player_cell.global_position) <= max_neighbor_distance:
			neighbors.append(cell)
	return neighbors

func estimate_neighbor_distance(player_cell: Cell, cells: Array[Cell]) -> float:
	var nearest_distance: float = INF
	for cell in cells:
		if cell == null or cell == player_cell:
			continue
		var distance: float = cell.global_position.distance_to(player_cell.global_position)
		if distance > 0.0 and distance < nearest_distance:
			nearest_distance = distance
	if nearest_distance == INF:
		return 0.0
	return nearest_distance * 1.1

func project_point_into_cell(cell: Cell, position: Vector2) -> Vector2:
	var capture_polygon: CollisionPolygon2D = get_cell_capture_polygon(cell)
	if capture_polygon:
		return project_point_into_capture_polygon(capture_polygon, position)
	var collision_shape: CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape == null:
		return position
	var rect_shape := collision_shape.shape
	if rect_shape is RectangleShape2D:
		var half_size = rect_shape.size * 0.5
		var local_point = collision_shape.global_transform.affine_inverse() * position
		local_point.x = clampf(local_point.x, -half_size.x, half_size.x)
		local_point.y = clampf(local_point.y, -half_size.y, half_size.y)
		return collision_shape.global_transform * local_point
	return position

func get_player_view_rect(player: Player) -> Rect2:
	if owner == null or not is_instance_valid(owner):
		return Rect2(player.global_position, Vector2.ZERO)
	var viewport_size = owner.get_viewport_rect().size
	var half_size = viewport_size * 0.5
	var top_left = player.global_position - half_size
	return Rect2(top_left, viewport_size)

func cell_intersects_rect(cell: Cell, rect: Rect2) -> bool:
	var cell_rect := get_cell_aabb(cell)
	if cell_rect.size == Vector2.ZERO:
		return rect.has_point(cell.global_position)
	return cell_rect.intersects(rect)

func get_cell_aabb(cell: Cell) -> Rect2:
	var capture_polygon: CollisionPolygon2D = get_cell_capture_polygon(cell)
	if capture_polygon:
		return get_capture_polygon_aabb(capture_polygon)
	var collision_shape: CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = collision_shape.shape
		var half_size = rect_shape.size * 0.5
		var gt := collision_shape.global_transform
		var points = [
			gt * Vector2(-half_size.x, -half_size.y),
			gt * Vector2(half_size.x, -half_size.y),
			gt * Vector2(half_size.x, half_size.y),
			gt * Vector2(-half_size.x, half_size.y)
		]
		var min_x = points[0].x
		var max_x = points[0].x
		var min_y = points[0].y
		var max_y = points[0].y
		for p in points:
			min_x = min(min_x, p.x)
			max_x = max(max_x, p.x)
			min_y = min(min_y, p.y)
			max_y = max(max_y, p.y)
		return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	return Rect2(cell.global_position, Vector2.ZERO)

func get_cell_capture_polygon(cell: Cell) -> CollisionPolygon2D:
	if cell == null:
		return null
	return cell.get_node_or_null("Area2D/CapturePolygon") as CollisionPolygon2D

func is_point_inside_capture_polygon(capture_polygon: CollisionPolygon2D, world_position: Vector2) -> bool:
	if capture_polygon == null or capture_polygon.polygon.is_empty():
		return false
	var local_point: Vector2 = capture_polygon.global_transform.affine_inverse() * world_position
	return Geometry2D.is_point_in_polygon(local_point, capture_polygon.polygon)

func get_random_point_in_capture_polygon(capture_polygon: CollisionPolygon2D) -> Vector2:
	if capture_polygon == null or capture_polygon.polygon.is_empty():
		return Vector2.ZERO
	var local_aabb: Rect2 = get_polygon_local_aabb(capture_polygon.polygon)
	var attempts: int = max(spawn_point_attempts_per_enemy * 2, 12)
	for _i in range(attempts):
		var candidate_local: Vector2 = Vector2(
			randf_range(local_aabb.position.x, local_aabb.end.x),
			randf_range(local_aabb.position.y, local_aabb.end.y)
		)
		if Geometry2D.is_point_in_polygon(candidate_local, capture_polygon.polygon):
			return capture_polygon.global_transform * candidate_local
	var centroid_local: Vector2 = get_polygon_centroid(capture_polygon.polygon)
	return capture_polygon.global_transform * centroid_local

func project_point_into_capture_polygon(capture_polygon: CollisionPolygon2D, world_position: Vector2) -> Vector2:
	if capture_polygon == null or capture_polygon.polygon.is_empty():
		return world_position
	if is_point_inside_capture_polygon(capture_polygon, world_position):
		return world_position
	var local_aabb: Rect2 = get_polygon_local_aabb(capture_polygon.polygon)
	var local_point: Vector2 = capture_polygon.global_transform.affine_inverse() * world_position
	local_point.x = clampf(local_point.x, local_aabb.position.x, local_aabb.end.x)
	local_point.y = clampf(local_point.y, local_aabb.position.y, local_aabb.end.y)
	if Geometry2D.is_point_in_polygon(local_point, capture_polygon.polygon):
		return capture_polygon.global_transform * local_point
	var nearest_polygon_point: Vector2 = capture_polygon.polygon[0]
	var nearest_distance: float = nearest_polygon_point.distance_squared_to(local_point)
	for polygon_point in capture_polygon.polygon:
		var point_distance: float = polygon_point.distance_squared_to(local_point)
		if point_distance < nearest_distance:
			nearest_distance = point_distance
			nearest_polygon_point = polygon_point
	return capture_polygon.global_transform * nearest_polygon_point

func get_capture_polygon_aabb(capture_polygon: CollisionPolygon2D) -> Rect2:
	var polygon_points: PackedVector2Array = capture_polygon.polygon
	if polygon_points.is_empty():
		return Rect2(capture_polygon.global_position, Vector2.ZERO)
	var first_point: Vector2 = capture_polygon.global_transform * polygon_points[0]
	var min_x: float = first_point.x
	var max_x: float = first_point.x
	var min_y: float = first_point.y
	var max_y: float = first_point.y
	for local_point in polygon_points:
		var world_point: Vector2 = capture_polygon.global_transform * local_point
		min_x = minf(min_x, world_point.x)
		max_x = maxf(max_x, world_point.x)
		min_y = minf(min_y, world_point.y)
		max_y = maxf(max_y, world_point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func get_polygon_local_aabb(polygon_points: PackedVector2Array) -> Rect2:
	if polygon_points.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_x: float = polygon_points[0].x
	var max_x: float = polygon_points[0].x
	var min_y: float = polygon_points[0].y
	var max_y: float = polygon_points[0].y
	for polygon_point in polygon_points:
		min_x = minf(min_x, polygon_point.x)
		max_x = maxf(max_x, polygon_point.x)
		min_y = minf(min_y, polygon_point.y)
		max_y = maxf(max_y, polygon_point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func get_polygon_centroid(polygon_points: PackedVector2Array) -> Vector2:
	if polygon_points.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for polygon_point in polygon_points:
		center += polygon_point
	return center / float(polygon_points.size())

func get_fallback_spawn_position(player: Player) -> Vector2:
	var far_cell := pick_farthest_cell_from_player(player.global_position)
	if far_cell:
		last_spawn_cell = far_cell
		return get_random_point_in_cell_away_from_player(far_cell, player.global_position)
	var attempts: int = max(spawn_point_attempts_per_enemy, 1)
	var best_pos: Vector2 = get_farthest_boundary_point(player.global_position)
	var best_distance: float = 0.0
	for _i in range(attempts):
		var candidate: Vector2 = get_random_boundary_position_away_from_player(player.global_position)
		var distance_to_player: float = candidate.distance_to(player.global_position)
		if distance_to_player >= min_spawn_distance_from_player:
			return candidate
		if distance_to_player > best_distance:
			best_distance = distance_to_player
			best_pos = candidate
	return best_pos

func pick_farthest_cell_from_player(player_position: Vector2) -> Cell:
	var effective_cells := get_effective_board_cells()
	if effective_cells.is_empty():
		cache_board_cells()
		effective_cells = get_effective_board_cells()
	if effective_cells.is_empty():
		return null
	var best_cell: Cell = null
	var best_distance := -1.0
	for cell in effective_cells:
		if cell == null:
			continue
		if not cell_can_spawn_away_from_player(cell, player_position):
			continue
		var distance_to_player: float = cell.global_position.distance_to(player_position)
		if distance_to_player > best_distance:
			best_distance = distance_to_player
			best_cell = cell
	return best_cell

func get_effective_board_cells() -> Array[Cell]:
	if board and board.has_method("get_active_cells"):
		var active_cells_variant: Variant = board.call("get_active_cells")
		if active_cells_variant is Array:
			var active_cells_raw := active_cells_variant as Array
			var active_cells: Array[Cell] = []
			for node in active_cells_raw:
				if node is Cell:
					active_cells.append(node as Cell)
			if not active_cells.is_empty():
				return active_cells
	return board_cells

func get_nearby_position(origin: Vector2, min_distance: float = 0.0, max_distance: float = 100.0) -> Vector2:
	var player: Player = PlayerData.player
	var attempts: int = max(spawn_point_attempts_per_enemy, 1)
	var best_position: Vector2 = origin
	var best_distance: float = 0.0
	for _i in range(attempts):
		var angle: float = randf() * 2.0 * PI
		var distance: float = randf_range(min_distance, max_distance)
		var nearby_pos: Vector2 = origin + Vector2(cos(angle), sin(angle)) * distance
		var candidate: Vector2 = nearby_pos
		if last_spawn_cell:
			candidate = project_point_into_cell(last_spawn_cell, nearby_pos)
		else:
			candidate = clamp_position(nearby_pos.x, nearby_pos.y)
		candidate = apply_spawn_safety_margin(candidate)
		if player == null:
			return candidate
		var distance_to_player: float = candidate.distance_to(player.global_position)
		if distance_to_player >= min_spawn_distance_from_player:
			return candidate
		if distance_to_player > best_distance:
			best_distance = distance_to_player
			best_position = candidate
	return best_position

func apply_spawn_safety_margin(position: Vector2) -> Vector2:
	var margin := maxf(spawn_edge_margin, 0.0)
	if margin <= 0.001:
		return position
	if board != null and board.has_method("project_point_to_enemy_traversable_area_with_margin"):
		var projected_with_margin: Variant = board.call("project_point_to_enemy_traversable_area_with_margin", position, margin)
		if projected_with_margin is Vector2:
			return projected_with_margin as Vector2
	if last_spawn_cell != null:
		var center: Vector2 = last_spawn_cell.global_position
		if position.distance_squared_to(center) > 0.0001:
			var moved := position.move_toward(center, margin)
			if cell_contains_point(last_spawn_cell, moved):
				return moved
	return position

func clamp_position(x_value: float, y_value: float) -> Vector2:
	return Vector2(clampf(x_value, x_min, x_max), clampf(y_value, y_min, y_max))

func get_random_boundary_position_away_from_player(player_position: Vector2) -> Vector2:
	var boundary_points := [
		Vector2(randf_range(x_min, x_max), y_min),
		Vector2(randf_range(x_min, x_max), y_max),
		Vector2(x_min, randf_range(y_min, y_max)),
		Vector2(x_max, randf_range(y_min, y_max))
	]
	var best_point: Vector2 = boundary_points[0]
	var best_distance: float = best_point.distance_to(player_position)
	for point in boundary_points:
		var point_distance: float = point.distance_to(player_position)
		if point_distance > best_distance:
			best_distance = point_distance
			best_point = point
	return best_point

func get_farthest_boundary_point(player_position: Vector2) -> Vector2:
	var corners := [
		Vector2(x_min, y_min),
		Vector2(x_max, y_min),
		Vector2(x_min, y_max),
		Vector2(x_max, y_max)
	]
	var best_point: Vector2 = corners[0]
	var best_distance: float = best_point.distance_to(player_position)
	for point in corners:
		var point_distance: float = point.distance_to(player_position)
		if point_distance > best_distance:
			best_distance = point_distance
			best_point = point
	return best_point
