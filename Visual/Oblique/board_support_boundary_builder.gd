class_name BoardSupportBoundaryBuilder
extends RefCounted

## Builds the exposed outline of an arbitrary union of axis-aligned rectangles.
## Coordinate compression lets differently sized cells share partial edges without
## leaving support seams or generating internal walls.

const EPSILON := 0.01


static func build_model(source_rects: Array, pillar_spacing: float) -> Dictionary:
	var segments := build_exposed_segments(source_rects)
	return {
		"segments": segments,
		"pillar_points": collect_pillar_points(segments, pillar_spacing),
		"perimeter": calculate_perimeter(segments),
	}


static func build_exposed_segments(source_rects: Array) -> Array[Dictionary]:
	var rects := _normalize_rects(source_rects)
	if rects.is_empty():
		return []
	var x_coordinates := _collect_coordinates(rects, true)
	var y_coordinates := _collect_coordinates(rects, false)
	if x_coordinates.size() < 2 or y_coordinates.size() < 2:
		return []
	var occupied: Array = []
	for x_index in range(x_coordinates.size() - 1):
		var column: Array[bool] = []
		for y_index in range(y_coordinates.size() - 1):
			var midpoint := Vector2(
				(x_coordinates[x_index] + x_coordinates[x_index + 1]) * 0.5,
				(y_coordinates[y_index] + y_coordinates[y_index + 1]) * 0.5
			)
			column.append(_point_is_covered(midpoint, rects))
		occupied.append(column)
	var raw_segments: Array[Dictionary] = []
	for x_index in range(x_coordinates.size() - 1):
		for y_index in range(y_coordinates.size() - 1):
			if not bool(occupied[x_index][y_index]):
				continue
			var x0: float = x_coordinates[x_index]
			var x1: float = x_coordinates[x_index + 1]
			var y0: float = y_coordinates[y_index]
			var y1: float = y_coordinates[y_index + 1]
			if y_index == 0 or not bool(occupied[x_index][y_index - 1]):
				raw_segments.append(_segment(&"top", Vector2(x0, y0), Vector2(x1, y0), Vector2.UP))
			if y_index == y_coordinates.size() - 2 or not bool(occupied[x_index][y_index + 1]):
				raw_segments.append(_segment(&"bottom", Vector2(x0, y1), Vector2(x1, y1), Vector2.DOWN))
			if x_index == 0 or not bool(occupied[x_index - 1][y_index]):
				raw_segments.append(_segment(&"left", Vector2(x0, y0), Vector2(x0, y1), Vector2.LEFT))
			if x_index == x_coordinates.size() - 2 or not bool(occupied[x_index + 1][y_index]):
				raw_segments.append(_segment(&"right", Vector2(x1, y0), Vector2(x1, y1), Vector2.RIGHT))
	return _merge_collinear_segments(raw_segments)


static func collect_pillar_points(segments: Array, pillar_spacing: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var safe_spacing := maxf(pillar_spacing, 1.0)
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		var start := segment.get("start", Vector2.ZERO) as Vector2
		var end := segment.get("end", Vector2.ZERO) as Vector2
		var length := start.distance_to(end)
		if length <= EPSILON:
			continue
		var direction := (end - start) / length
		_append_unique_point(result, start)
		var distance := safe_spacing
		while distance < length - EPSILON:
			_append_unique_point(result, start + direction * distance)
			distance += safe_spacing
		_append_unique_point(result, end)
	return result


static func calculate_perimeter(segments: Array) -> float:
	var perimeter := 0.0
	for segment_variant in segments:
		var segment := segment_variant as Dictionary
		perimeter += (segment.get("start", Vector2.ZERO) as Vector2).distance_to(
			segment.get("end", Vector2.ZERO) as Vector2
		)
	return perimeter


static func _normalize_rects(source_rects: Array) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for rect_variant in source_rects:
		if not rect_variant is Rect2:
			continue
		var rect := (rect_variant as Rect2).abs()
		if not rect.position.is_finite() or not rect.size.is_finite():
			continue
		if rect.size.x <= EPSILON or rect.size.y <= EPSILON:
			continue
		result.append(rect)
	return result


static func _collect_coordinates(rects: Array[Rect2], horizontal: bool) -> Array[float]:
	var values: Array[float] = []
	for rect in rects:
		values.append(rect.position.x if horizontal else rect.position.y)
		values.append(rect.end.x if horizontal else rect.end.y)
	values.sort()
	var unique_values: Array[float] = []
	for value in values:
		if unique_values.is_empty() or absf(value - unique_values[-1]) > EPSILON:
			unique_values.append(value)
	return unique_values


static func _point_is_covered(point: Vector2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if point.x > rect.position.x - EPSILON and point.x < rect.end.x + EPSILON \
				and point.y > rect.position.y - EPSILON and point.y < rect.end.y + EPSILON:
			return true
	return false


static func _segment(edge: StringName, start: Vector2, end: Vector2, outward: Vector2) -> Dictionary:
	return {
		"edge": edge,
		"start": start,
		"end": end,
		"outward": outward,
	}


static func _merge_collinear_segments(raw_segments: Array[Dictionary]) -> Array[Dictionary]:
	var groups: Dictionary = {}
	for segment in raw_segments:
		var edge := segment.get("edge", &"") as StringName
		var start := segment.get("start", Vector2.ZERO) as Vector2
		var coordinate := start.y if edge == &"top" or edge == &"bottom" else start.x
		var key := "%s:%.4f" % [String(edge), coordinate]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(segment)
	var result: Array[Dictionary] = []
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var group := groups[key] as Array
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var edge := a.get("edge", &"") as StringName
			var a_start := a.get("start", Vector2.ZERO) as Vector2
			var b_start := b.get("start", Vector2.ZERO) as Vector2
			return a_start.x < b_start.x if edge == &"top" or edge == &"bottom" else a_start.y < b_start.y
		)
		var current := (group[0] as Dictionary).duplicate()
		for index in range(1, group.size()):
			var candidate := group[index] as Dictionary
			var current_end := current.get("end", Vector2.ZERO) as Vector2
			var candidate_start := candidate.get("start", Vector2.ZERO) as Vector2
			if current_end.distance_to(candidate_start) <= EPSILON:
				current["end"] = candidate.get("end", current_end)
			else:
				result.append(current)
				current = candidate.duplicate()
		result.append(current)
	return result


static func _append_unique_point(points: PackedVector2Array, point: Vector2) -> void:
	for existing in points:
		if existing.distance_to(point) <= EPSILON:
			return
	points.append(point)
