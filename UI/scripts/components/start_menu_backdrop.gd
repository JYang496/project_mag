extends Control
class_name StartMenuRestPreview

const PLATFORM_TEXTURE: Texture2D = preload("res://asset/images/cells/rest_area_safe_medical.png")
const PLAYER_TEXTURE: Texture2D = preload("res://asset/images/characters/pixel/idle_bottom.png")

const MENU_PREVIEW_RECT := Rect2(552.0, 38.0, 688.0, 630.0)
const FULL_PREVIEW_MARGIN := Vector2(28.0, 22.0)
const LOOP_DURATION := 6.0
const GRID_SIZE := 3
const COLOR_SYSTEM := Color(0.34, 0.78, 0.88, 1.0)
const COLOR_SAFE := Color(0.38, 0.92, 0.58, 1.0)
const COLOR_PENDING := Color(0.20, 0.50, 0.62, 1.0)

var handoff_progress := 0.0
var loading_progress := 0.0
var loading_active := false
var _elapsed := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + maxf(delta, 0.0), LOOP_DURATION)
	queue_redraw()


func set_handoff_progress(value: float) -> void:
	handoff_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func begin_loading() -> void:
	loading_active = true
	loading_progress = 0.0
	queue_redraw()


func set_loading_progress(value: float) -> void:
	loading_progress = maxf(loading_progress, clampf(value, 0.0, 1.0))
	queue_redraw()


func reset_handoff() -> void:
	handoff_progress = 0.0
	loading_progress = 0.0
	loading_active = false
	_elapsed = 0.0
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var layout := preview_layout(size, handoff_progress)
	_draw_data_space(layout)
	_draw_platform_depth(layout)
	_draw_materializing_cells(layout)
	_draw_center_state(layout)
	_draw_player(layout)
	_draw_scan(layout)
	_draw_status(layout)


static func preview_layout(viewport_size: Vector2, progress: float) -> Dictionary:
	var resolved_progress := clampf(progress, 0.0, 1.0)
	var scale := Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	var menu_rect := Rect2(
		Vector2(MENU_PREVIEW_RECT.position.x * scale.x, MENU_PREVIEW_RECT.position.y * scale.y),
		Vector2(MENU_PREVIEW_RECT.size.x * scale.x, MENU_PREVIEW_RECT.size.y * scale.y)
	)
	var full_rect := Rect2(
		Vector2(FULL_PREVIEW_MARGIN.x * scale.x, FULL_PREVIEW_MARGIN.y * scale.y),
		viewport_size - Vector2(FULL_PREVIEW_MARGIN.x * 2.0 * scale.x, FULL_PREVIEW_MARGIN.y * 2.0 * scale.y)
	)
	var stage_rect := Rect2(
		menu_rect.position.lerp(full_rect.position, resolved_progress),
		menu_rect.size.lerp(full_rect.size, resolved_progress)
	)
	var top_left := Vector2(
		lerpf(676.0 * scale.x, 206.0 * scale.x, resolved_progress),
		lerpf(78.0 * scale.y, 48.0 * scale.y, resolved_progress)
	)
	var top_right := Vector2(
		lerpf(1116.0 * scale.x, 1074.0 * scale.x, resolved_progress),
		top_left.y
	)
	var bottom_left := Vector2(
		lerpf(608.0 * scale.x, 56.0 * scale.x, resolved_progress),
		lerpf(608.0 * scale.y, 674.0 * scale.y, resolved_progress)
	)
	var bottom_right := Vector2(
		lerpf(1184.0 * scale.x, 1224.0 * scale.x, resolved_progress),
		bottom_left.y
	)
	var platform_quad := PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
	var platform_rect := _bounds_for_points(platform_quad)
	var grid_points: Array[PackedVector2Array] = []
	var cells: Array[Dictionary] = []
	for row in range(GRID_SIZE + 1):
		var row_points := PackedVector2Array()
		for column in range(GRID_SIZE + 1):
			row_points.append(_project_to_quad(platform_quad, float(column) / GRID_SIZE, float(row) / GRID_SIZE))
		grid_points.append(row_points)
	for row in range(GRID_SIZE):
		for column in range(GRID_SIZE):
			cells.append({
				"row": row,
				"column": column,
				"quad": PackedVector2Array([
					grid_points[row][column],
					grid_points[row][column + 1],
					grid_points[row + 1][column + 1],
					grid_points[row + 1][column],
				]),
			})
	var player_center := _project_to_quad(platform_quad, 0.5, 0.515)
	return {
		"progress": resolved_progress,
		"stage_rect": stage_rect,
		"platform_rect": platform_rect,
		"platform_quad": platform_quad,
		"grid_points": grid_points,
		"cells": cells,
		"player_center": player_center,
		"player_size": Vector2.ONE * lerpf(58.0, 86.0, resolved_progress) * minf(scale.x, scale.y),
		"top_width": top_left.distance_to(top_right),
		"bottom_width": bottom_left.distance_to(bottom_right),
		"depth": lerpf(13.0, 24.0, resolved_progress) * scale.y,
	}


static func animation_state_at(seconds: float) -> Dictionary:
	var loop_time := fposmod(seconds, LOOP_DURATION)
	var progress := loop_time / LOOP_DURATION
	return {
		"progress": progress,
		"pulse": 0.5 + 0.5 * sin(progress * TAU),
		"scan": progress,
		"bob": sin(progress * TAU),
	}


static func _project_to_quad(quad: PackedVector2Array, u: float, v: float) -> Vector2:
	var top := quad[0].lerp(quad[1], u)
	var bottom := quad[3].lerp(quad[2], u)
	return top.lerp(bottom, v)


static func _bounds_for_points(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _draw_data_space(layout: Dictionary) -> void:
	var stage: Rect2 = layout.stage_rect
	var progress: float = layout.progress
	draw_rect(stage, Color(0.006, 0.018, 0.030, lerpf(0.66, 0.96, progress)), true)
	var horizon_y := lerpf(stage.position.y + stage.size.y * 0.20, stage.position.y + stage.size.y * 0.13, progress)
	var vanishing_point := Vector2(stage.get_center().x, horizon_y)
	var grid_color := Color(0.10, 0.34, 0.46, lerpf(0.10, 0.18, progress))
	for index in range(13):
		var edge_x := lerpf(stage.position.x, stage.end.x, float(index) / 12.0)
		draw_line(vanishing_point, Vector2(edge_x, stage.end.y), grid_color, 1.0)
	for index in range(8):
		var t := float(index) / 7.0
		var y := lerpf(horizon_y, stage.end.y, t * t)
		draw_line(Vector2(stage.position.x, y), Vector2(stage.end.x, y), grid_color, 1.0)
	draw_line(Vector2(stage.position.x, horizon_y), Vector2(stage.end.x, horizon_y), Color(COLOR_SYSTEM.r, COLOR_SYSTEM.g, COLOR_SYSTEM.b, 0.20), 1.0)
	draw_rect(stage, Color(0.24, 0.68, 0.78, 0.36), false, 1.0)


func _draw_platform_depth(layout: Dictionary) -> void:
	var quad: PackedVector2Array = layout.platform_quad
	var depth: float = layout.depth
	var bottom_drop := Vector2(0.0, depth)
	var left_face := PackedVector2Array([quad[0], quad[3], quad[3] + bottom_drop, quad[0] + bottom_drop * 0.36])
	var right_face := PackedVector2Array([quad[1], quad[2], quad[2] + bottom_drop, quad[1] + bottom_drop * 0.36])
	var front_face := PackedVector2Array([quad[3], quad[2], quad[2] + bottom_drop, quad[3] + bottom_drop])
	draw_colored_polygon(left_face, Color(0.035, 0.10, 0.15, 0.92))
	draw_colored_polygon(right_face, Color(0.025, 0.075, 0.12, 0.94))
	draw_colored_polygon(front_face, Color(0.025, 0.12, 0.17, 0.96))
	draw_polyline(PackedVector2Array([quad[3], quad[3] + bottom_drop, quad[2] + bottom_drop, quad[2]]), Color(0.25, 0.70, 0.80, 0.34), 1.0)


func _draw_materializing_cells(layout: Dictionary) -> void:
	var animation := animation_state_at(_elapsed)
	var sweep := float(animation.progress)
	var cells: Array[Dictionary] = layout.cells
	for index in range(cells.size()):
		var cell: Dictionary = cells[index]
		var row := int(cell.row)
		var column := int(cell.column)
		var quad: PackedVector2Array = cell.quad
		var readiness := _cell_readiness(index, row, column, sweep)
		draw_colored_polygon(quad, Color(0.025, 0.075, 0.105, lerpf(0.72, 0.42, readiness)))
		if readiness > 0.02:
			var uv_left := float(column) / GRID_SIZE
			var uv_top := float(row) / GRID_SIZE
			var uv_right := float(column + 1) / GRID_SIZE
			var uv_bottom := float(row + 1) / GRID_SIZE
			var colors := PackedColorArray()
			for unused in range(4):
				colors.append(Color(0.72, 0.84, 0.92, lerpf(0.16, 0.90, readiness)))
			draw_polygon(
				quad,
				colors,
				PackedVector2Array([
					Vector2(uv_left, uv_top), Vector2(uv_right, uv_top),
					Vector2(uv_right, uv_bottom), Vector2(uv_left, uv_bottom),
				]),
				PLATFORM_TEXTURE
			)
		var outline_alpha := lerpf(0.22, 0.62, readiness)
		_draw_closed_polyline(quad, Color(COLOR_SYSTEM.r, COLOR_SYSTEM.g, COLOR_SYSTEM.b, outline_alpha), 1.0 if readiness < 0.8 else 1.5)
		if readiness < 0.72:
			_draw_cell_corners(quad, Color(COLOR_PENDING.r, COLOR_PENDING.g, COLOR_PENDING.b, 0.44))


func _cell_readiness(index: int, row: int, column: int, sweep: float) -> float:
	if row == 1 and column == 1:
		return 1.0
	# Build outward from the occupied center so newly resolved floor always reads
	# as one connected space instead of disconnected finished islands.
	var order := [1, 3, 5, 7, 0, 2, 6, 8]
	var sequence_index := order.find(index)
	if loading_active:
		var start := 0.10 + float(sequence_index) * 0.085
		return 0.04 + 0.96 * smoothstep(start, start + 0.24, loading_progress)
	var loop_offset := fposmod(sweep - float(maxi(sequence_index, 0)) * 0.085, 1.0)
	return 0.06 + 0.18 * smoothstep(0.0, 0.22, loop_offset) * (1.0 - smoothstep(0.50, 0.88, loop_offset))


func _draw_center_state(layout: Dictionary) -> void:
	var center: Vector2 = layout.player_center
	var progress: float = layout.progress
	var pulse := float(animation_state_at(_elapsed).pulse)
	var radius_x := lerpf(48.0, 82.0, progress) + pulse * 4.0
	var radius_y := radius_x * 0.34
	_draw_ellipse(Rect2(center - Vector2(radius_x, radius_y), Vector2(radius_x * 2.0, radius_y * 2.0)), Color(0.20, 0.78, 0.52, 0.10 + pulse * 0.05))
	_draw_ellipse_outline(center, Vector2(radius_x, radius_y), Color(COLOR_SAFE.r, COLOR_SAFE.g, COLOR_SAFE.b, 0.48 + pulse * 0.18), 2.0)
	_draw_ellipse_outline(center, Vector2(radius_x * 0.64, radius_y * 0.64), Color(COLOR_SYSTEM.r, COLOR_SYSTEM.g, COLOR_SYSTEM.b, 0.36), 1.0)


func _draw_player(layout: Dictionary) -> void:
	var player_size: Vector2 = layout.player_size
	var bob := float(animation_state_at(_elapsed).bob) * lerpf(1.5, 2.5, float(layout.progress))
	var center: Vector2 = layout.player_center + Vector2(0.0, -player_size.y * 0.24 + bob)
	var shadow_size := Vector2(player_size.x * 0.62, player_size.y * 0.12)
	_draw_ellipse(Rect2(layout.player_center - shadow_size * 0.5, shadow_size), Color(0.0, 0.0, 0.0, 0.34))
	var rect := Rect2(center - player_size * 0.5, player_size)
	draw_texture_rect(PLAYER_TEXTURE, rect, false, Color(0.96, 0.98, 1.0, 1.0))


func _draw_scan(layout: Dictionary) -> void:
	var quad: PackedVector2Array = layout.platform_quad
	var scan := float(animation_state_at(_elapsed).scan)
	var left := quad[0].lerp(quad[3], scan)
	var right := quad[1].lerp(quad[2], scan)
	draw_line(left, right, Color(COLOR_SYSTEM.r, COLOR_SYSTEM.g, COLOR_SYSTEM.b, 0.18), 2.0)


func _draw_status(layout: Dictionary) -> void:
	if not loading_active:
		return
	var stage: Rect2 = layout.stage_rect
	var status := _loading_status()
	var font := get_theme_default_font()
	var font_size := 13
	var text_size := font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var position := Vector2(stage.end.x - text_size.x - 16.0, stage.end.y - 15.0)
	draw_string(font, position, status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.42, 0.82, 0.90, 0.78))


func _loading_status() -> String:
	if not loading_active:
		return "SPATIAL BUFFER // CALIBRATING"
	if loading_progress < 0.26:
		return "RUN STATE // SYNCHRONIZING"
	if loading_progress < 0.82:
		return "REST NODE // MATERIALIZING"
	return "WORLD LINK // STABILIZING"


func _draw_cell_corners(quad: PackedVector2Array, color: Color) -> void:
	for index in range(4):
		var current := quad[index]
		var previous := quad[(index + 3) % 4]
		var next := quad[(index + 1) % 4]
		draw_line(current, current.lerp(previous, 0.16), color, 1.5)
		draw_line(current, current.lerp(next, 0.16), color, 1.5)


func _draw_closed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, false)


func _draw_ellipse(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		points.append(rect.get_center() + Vector2(cos(angle) * rect.size.x * 0.5, sin(angle) * rect.size.y * 0.5))
	draw_colored_polygon(points, color)


func _draw_ellipse_outline(center: Vector2, radius: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(33):
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, color, width, false)
