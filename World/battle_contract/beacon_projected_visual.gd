extends Control

const ProjectedUi := preload("res://Visual/Oblique/projected_world_ui_service.gd")

const OPERATION := &"operation"
const CONTAINMENT := &"containment"
const EXTRACTION := &"extraction"
const TAU_F := TAU

var target: Node2D
var visual_kind: StringName = OPERATION
var beacon_id := 0
var radius := 70.0
var progress := 0.0
var player_inside := false
var enemy_count := 0
var completed := false
var removing := false
var _elapsed := 0.0
var _completion_elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func configure(owner_target: Node2D, kind: StringName, id: int, world_radius: float) -> void:
	target = owner_target
	visual_kind = kind
	beacon_id = id
	radius = world_radius
	queue_redraw()

func set_presence(inside: bool, enemies: int) -> void:
	player_inside = inside
	enemy_count = maxi(enemies, 0)
	queue_redraw()

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if progress >= 1.0 and visual_kind != EXTRACTION:
		play_completion()
	queue_redraw()

func play_completion() -> void:
	if completed:
		return
	completed = true
	_completion_elapsed = 0.0
	queue_redraw()

func play_completion_and_remove() -> void:
	play_completion()
	removing = true

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	_elapsed += delta
	if completed:
		_completion_elapsed += delta
	if removing and _completion_elapsed >= 0.72:
		queue_free()
		return
	var viewport_size := get_viewport_rect().size
	if size != viewport_size:
		position = Vector2.ZERO
		size = viewport_size
	queue_redraw()

func _draw() -> void:
	if target == null or not is_instance_valid(target) or size.x <= 1.0 or size.y <= 1.0:
		return
	var center := _project(target.global_position)
	var safe_rect := Rect2(Vector2(54.0, 54.0), size - Vector2(108.0, 108.0))
	if safe_rect.has_point(center):
		_draw_world_marker(center)
	else:
		_draw_offscreen_arrow(center, safe_rect)

func _draw_world_marker(center: Vector2) -> void:
	var color := _primary_color()
	var danger := Color(1.0, 0.25, 0.20, 0.95)
	var pulse := 0.5 + 0.5 * sin(_elapsed * (5.6 if player_inside else 2.4))
	var x_axis := _project(target.global_position + Vector2(radius, 0.0)) - center
	var y_axis := _project(target.global_position + Vector2(0.0, radius)) - center
	if x_axis.length() < 8.0 or y_axis.length() < 5.0:
		x_axis = Vector2(radius, 0.0)
		y_axis = Vector2(0.0, radius * 0.58)

	var state_alpha := 0.78 + pulse * 0.18 if player_inside else 0.58 + pulse * 0.10
	_draw_protocol_outline(center, x_axis, y_axis, Color(color.r, color.g, color.b, state_alpha))
	_draw_elliptic_arc(center, x_axis * 0.83, y_axis * 0.83, 0.0, TAU_F, Color(0.03, 0.08, 0.12, 0.72), 5.0, 64)
	if progress > 0.001:
		_draw_elliptic_arc(center, x_axis * 0.83, y_axis * 0.83, -PI * 0.5, -PI * 0.5 + TAU_F * progress, color, 4.0, maxi(8, ceili(64.0 * progress)))

	if player_inside and not completed:
		var wave_scale := 0.55 + fmod(_elapsed * 0.9, 1.0) * 0.34
		var wave_alpha := (1.0 - fmod(_elapsed * 0.9, 1.0)) * 0.28
		_draw_elliptic_arc(center, x_axis * wave_scale, y_axis * wave_scale, 0.0, TAU_F, Color(color.r, color.g, color.b, wave_alpha), 2.0, 48)

	if enemy_count > 0 and not completed:
		var jitter := sin(_elapsed * 17.0) * 0.035
		for index in range(4):
			var start := -PI * 0.5 + float(index) * PI * 0.5 + jitter
			_draw_elliptic_arc(center, x_axis * 1.07, y_axis * 1.07, start, start + 0.32, danger, 4.0, 8)

	_draw_center_icon(center, color, pulse)
	if completed:
		var completion_ratio := clampf(_completion_elapsed / 0.72, 0.0, 1.0)
		var flash_alpha := (1.0 - completion_ratio) * 0.7
		_draw_elliptic_arc(center, x_axis * (0.72 + completion_ratio * 0.58), y_axis * (0.72 + completion_ratio * 0.58), 0.0, TAU_F, Color(color.r, color.g, color.b, flash_alpha), 4.0, 64)
		_draw_check(center, Color(0.86, 1.0, 0.80, 0.98))

func _draw_protocol_outline(center: Vector2, x_axis: Vector2, y_axis: Vector2, color: Color) -> void:
	match visual_kind:
		CONTAINMENT:
			var points := PackedVector2Array()
			for index in range(25):
				var angle := TAU_F * float(index) / 24.0
				var jag := 1.0 if index % 2 == 0 else 0.88
				points.append(center + x_axis * cos(angle) * jag + y_axis * sin(angle) * jag)
			draw_polyline(points, color, 3.0, true)
		EXTRACTION:
			var hex := PackedVector2Array()
			for index in range(7):
				var angle := -PI * 0.5 + TAU_F * float(index) / 6.0
				hex.append(center + x_axis * cos(angle) + y_axis * sin(angle))
			draw_polyline(hex, color, 3.0, true)
			for index in range(3):
				var angle := -PI * 0.5 + TAU_F * float(index) / 3.0
				var outer := center + x_axis * cos(angle) * 0.72 + y_axis * sin(angle) * 0.72
				var inner := center + x_axis * cos(angle) * 0.48 + y_axis * sin(angle) * 0.48
				draw_line(outer, inner, color, 3.0, true)
		_:
			for index in range(12):
				var start := TAU_F * float(index) / 12.0 + _elapsed * 0.08
				_draw_elliptic_arc(center, x_axis, y_axis, start, start + 0.30, color, 3.0, 5)

func _draw_center_icon(center: Vector2, color: Color, pulse: float) -> void:
	draw_circle(center, 14.0 + pulse * 1.5, Color(0.025, 0.07, 0.10, 0.88))
	draw_arc(center, 14.0 + pulse * 1.5, 0.0, TAU_F, 28, Color(color.r, color.g, color.b, 0.92), 2.0, true)
	match visual_kind:
		CONTAINMENT:
			var rift := PackedVector2Array([
				center + Vector2(0.0, -9.0),
				center + Vector2(5.0, -3.0),
				center + Vector2(-2.0, 1.0),
				center + Vector2(4.0, 8.0),
				center + Vector2(-5.0, 3.0),
				center + Vector2(0.0, -9.0),
			])
			draw_polyline(rift, color, 3.0, true)
		EXTRACTION:
			for offset_x in [-5.0, 0.0, 5.0]:
				var tip := center + Vector2(offset_x, -7.0)
				draw_line(tip, tip + Vector2(0.0, 11.0), color, 2.0, true)
				draw_line(tip, tip + Vector2(-3.0, 4.0), color, 2.0, true)
				draw_line(tip, tip + Vector2(3.0, 4.0), color, 2.0, true)
		_:
			draw_line(center + Vector2(0.0, 7.0), center + Vector2(0.0, -5.0), color, 2.5, true)
			draw_circle(center + Vector2(0.0, -7.0), 2.8, color)
			draw_arc(center + Vector2(0.0, -5.0), 7.0, -PI * 0.86, -PI * 0.14, 12, color, 2.0, true)
			draw_string(ThemeDB.fallback_font, center + Vector2(8.0, -7.0), str(beacon_id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, color)

func _draw_offscreen_arrow(target_screen: Vector2, safe_rect: Rect2) -> void:
	var screen_center := size * 0.5
	var direction := (target_screen - screen_center).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var edge := _ray_rect_intersection(screen_center, direction, safe_rect)
	var color := _primary_color()
	var angle := direction.angle()
	var tip := edge + direction * 7.0
	var left := edge - direction * 13.0 + direction.rotated(PI * 0.5) * 10.0
	var right := edge - direction * 13.0 - direction.rotated(PI * 0.5) * 10.0
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(color.r, color.g, color.b, 0.96))
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color(0.02, 0.06, 0.09, 0.95), 2.0, true)
	var icon_center := edge - direction * 25.0
	draw_circle(icon_center, 11.0, Color(0.02, 0.06, 0.09, 0.90))
	draw_arc(icon_center, 11.0, 0.0, TAU_F, 20, color, 2.0, true)
	_draw_small_protocol_glyph(icon_center, color, angle)

func _draw_small_protocol_glyph(center: Vector2, color: Color, _angle: float) -> void:
	match visual_kind:
		CONTAINMENT:
			draw_polyline(PackedVector2Array([center + Vector2(0, -6), center + Vector2(3, -1), center + Vector2(-2, 2), center + Vector2(2, 6)]), color, 2.0, true)
		EXTRACTION:
			draw_line(center + Vector2(0, 5), center + Vector2(0, -5), color, 2.0, true)
			draw_line(center + Vector2(0, -5), center + Vector2(-4, 0), color, 2.0, true)
			draw_line(center + Vector2(0, -5), center + Vector2(4, 0), color, 2.0, true)
		_:
			draw_line(center + Vector2(0, 5), center + Vector2(0, -4), color, 2.0, true)
			draw_circle(center + Vector2(0, -5), 2.0, color)

func _draw_check(center: Vector2, color: Color) -> void:
	draw_line(center + Vector2(-7.0, 0.0), center + Vector2(-2.0, 6.0), color, 3.0, true)
	draw_line(center + Vector2(-2.0, 6.0), center + Vector2(8.0, -6.0), color, 3.0, true)

func _draw_elliptic_arc(center: Vector2, x_axis: Vector2, y_axis: Vector2, start_angle: float, end_angle: float, color: Color, width: float, segments: int) -> void:
	var points := PackedVector2Array()
	var count := maxi(segments, 2)
	for index in range(count + 1):
		var angle := lerpf(start_angle, end_angle, float(index) / float(count))
		points.append(center + x_axis * cos(angle) + y_axis * sin(angle))
	draw_polyline(points, color, width, true)

func _ray_rect_intersection(origin: Vector2, direction: Vector2, rect: Rect2) -> Vector2:
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

func _project(world_position: Vector2) -> Vector2:
	var view := ProjectedUi.get_hybrid_view(get_tree())
	if view != null:
		return view.call("project_world_to_screen", world_position) as Vector2
	return get_viewport().get_canvas_transform() * world_position

func _primary_color() -> Color:
	match visual_kind:
		CONTAINMENT:
			return Color(0.92, 0.32, 0.96, 0.98)
		EXTRACTION:
			return Color(0.72, 1.0, 0.36, 0.98)
		_:
			return Color(0.30, 0.86, 1.0, 0.98)
