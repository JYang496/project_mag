extends RefCounted
class_name OffscreenIndicatorGeometry

const ProjectedUi := preload("res://Visual/Oblique/projected_world_ui_service.gd")
const DEFAULT_SAFE_MARGIN := Vector2(54.0, 54.0)

static func project_world_to_screen(tree: SceneTree, viewport: Viewport, world_position: Vector2) -> Vector2:
	var view := ProjectedUi.get_hybrid_view(tree)
	if view != null:
		return view.call("project_world_to_screen", world_position) as Vector2
	return viewport.get_canvas_transform() * world_position

static func make_safe_rect(viewport_size: Vector2, margin: Vector2 = DEFAULT_SAFE_MARGIN) -> Rect2:
	var clamped_margin := Vector2(
		minf(maxf(margin.x, 0.0), viewport_size.x * 0.5),
		minf(maxf(margin.y, 0.0), viewport_size.y * 0.5)
	)
	return Rect2(clamped_margin, (viewport_size - clamped_margin * 2.0).max(Vector2.ZERO))

static func resolve(target_screen: Vector2, viewport_size: Vector2, safe_rect: Rect2) -> Dictionary:
	var screen_center := viewport_size * 0.5
	var direction := (target_screen - screen_center).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	return {
		"is_inside_viewport": Rect2(Vector2.ZERO, viewport_size).has_point(target_screen),
		"is_inside_safe_rect": safe_rect.has_point(target_screen),
		"direction": direction,
		"angle": direction.angle(),
		"edge_position": ray_rect_intersection(screen_center, direction, safe_rect),
	}

static func ray_rect_intersection(origin: Vector2, direction: Vector2, rect: Rect2) -> Vector2:
	var distances: Array[float] = []
	if absf(direction.x) > 0.0001:
		distances.append((rect.position.x - origin.x) / direction.x)
		distances.append((rect.end.x - origin.x) / direction.x)
	if absf(direction.y) > 0.0001:
		distances.append((rect.position.y - origin.y) / direction.y)
		distances.append((rect.end.y - origin.y) / direction.y)
	var best := INF
	for distance in distances:
		if distance <= 0.0:
			continue
		var point := origin + direction * distance
		if rect.grow(0.5).has_point(point):
			best = minf(best, distance)
	return origin + direction * best if best < INF else rect.get_center()
