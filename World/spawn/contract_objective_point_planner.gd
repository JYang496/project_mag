extends RefCounted
class_name ContractObjectivePointPlanner

const MIN_PLAYER_DISTANCE := 180.0
const MIN_BEACON_DISTANCE := 300.0
const MIN_OBJECTIVE_DISTANCE := 220.0

func collect_candidates(cells: Array, player_position: Vector2) -> PackedVector2Array:
	var candidates := PackedVector2Array()
	for cell_value in cells:
		var cell := cell_value as Node2D
		if cell == null:
			continue
		var local_center := Vector2.ZERO
		if cell.has_method("get_local_cell_center"):
			local_center = cell.call("get_local_cell_center") as Vector2
		else:
			local_center = _resolve_cell_center_from_collision(cell)
		var cell_center: Vector2 = cell.global_transform * local_center
		if cell_center.distance_to(player_position) >= MIN_PLAYER_DISTANCE:
			candidates.append(cell_center)
	return candidates

func select_beacon_points(cells: Array, player_position: Vector2) -> PackedVector2Array:
	var points := collect_candidates(cells, player_position)
	if points.size() < 2:
		return PackedVector2Array()
	var best := PackedVector2Array([points[0], points[1]])
	var best_distance := best[0].distance_to(best[1])
	for first in points:
		for second in points:
			var distance := first.distance_to(second)
			if distance > best_distance:
				best = PackedVector2Array([first, second])
				best_distance = distance
	return best if best_distance >= MIN_BEACON_DISTANCE else PackedVector2Array()

func select_objective_points(cells: Array, player_position: Vector2, max_points: int = 3) -> PackedVector2Array:
	var candidates := collect_candidates(cells, player_position)
	if candidates.is_empty() or max_points <= 0:
		return PackedVector2Array()
	var selected := PackedVector2Array()
	var first := candidates[0]
	for point in candidates:
		if point.distance_to(player_position) > first.distance_to(player_position):
			first = point
	selected.append(first)
	while selected.size() < max_points and selected.size() < candidates.size():
		var best_point := Vector2.INF
		var best_min_distance := -1.0
		for candidate in candidates:
			if selected.has(candidate):
				continue
			var min_distance := INF
			for existing in selected:
				min_distance = minf(min_distance, candidate.distance_to(existing))
			if min_distance > best_min_distance:
				best_min_distance = min_distance
				best_point = candidate
		if best_point == Vector2.INF or best_min_distance < MIN_OBJECTIVE_DISTANCE:
			break
		selected.append(best_point)
	return selected

func _resolve_cell_center_from_collision(cell: Node2D) -> Vector2:
	var collision_shape := cell.get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		return collision_shape.position
	return Vector2.ZERO
