extends Node2D

const VISUAL_UPDATE_INTERVAL_SEC := 0.05
const MEDIUM_DETAIL_TRAIL_COUNT := 4
const LOW_DETAIL_TRAIL_COUNT := 7

var area: Node2D
var _fill_mesh: ArrayMesh
var _line_mesh: ArrayMesh
var _visual_update_elapsed := VISUAL_UPDATE_INTERVAL_SEC


func _ready() -> void:
	add_to_group(&"glacier_ground_visual")
	_rebuild_meshes()


func _process(delta: float) -> void:
	_visual_update_elapsed += maxf(delta, 0.0)
	if _visual_update_elapsed < VISUAL_UPDATE_INTERVAL_SEC:
		return
	_visual_update_elapsed = fmod(_visual_update_elapsed, VISUAL_UPDATE_INTERVAL_SEC)
	_rebuild_meshes()


func _project(point: Vector2, view: Node) -> Vector2:
	var world := area.to_global(point)
	if view != null:
		world = view.call("project_world_to_canvas", world, get_viewport())
	return to_local(world).round()


func _rebuild_meshes() -> void:
	if not is_instance_valid(area):
		_fill_mesh = null
		_line_mesh = null
		queue_redraw()
		return
	var length: float = area.get("path_length")
	var width: float = area.get("path_width")
	var enhanced: bool = area.get("cold_snap_active")
	var crumble: float = area.get_crumble_progress()
	var extension: float = area.get_extension_progress()
	var view := get_tree().get_first_node_in_group(&"hybrid_ground_view_3d")
	var detail := _get_detail_profile()
	var columns := clampi(ceili(length / float(detail["column_spacing"])), 1, 48)
	var rows := int(detail["rows"])
	var tile_width := length / columns
	var fill_builder := SurfaceTool.new()
	var line_builder := SurfaceTool.new()
	fill_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	line_builder.begin(Mesh.PRIMITIVE_LINES)
	var fill_vertex_count := 0
	var line_vertex_count := 0
	for column in range(columns):
		var reveal := clampf(extension * columns - column, 0.0, 1.0)
		if reveal <= 0.0:
			continue
		for row in range(rows):
			var variant := (column + row * 2) % 4
			if crumble > float(variant + 1) / 4.0:
				continue
			var x := column * tile_width
			var row_height := width / rows
			var y := -width * 0.5 + row * row_height
			var drift := Vector2((variant - 1) * 5, (row - (rows - 1) * 0.5) * 7) * crumble
			var inset := 2.0 + float(variant % 2) * 2.0
			var points := PackedVector2Array()
			var projectable := true
			for corner in [
				Vector2(inset, 1), Vector2(tile_width - 2, 0),
				Vector2(tile_width - 1, row_height - 3), Vector2(2, row_height - 1),
				Vector2(0, 4),
			]:
				var point := Vector2(x, y) + Vector2(corner.x * reveal, corner.y) + drift
				if view != null and not view.call("can_project_world_point", area.to_global(point)):
					projectable = false
					break
				points.append(_project(point, view))
			if not projectable:
				continue
			var indices := Geometry2D.triangulate_polygon(points)
			if indices.is_empty():
				continue
			var fill_color := Color(0.28 + variant * 0.03, 0.64, 0.83, 0.32 * (1.0 - crumble) * reveal)
			for point_index in indices:
				fill_builder.set_color(fill_color)
				fill_builder.add_vertex(Vector3(points[point_index].x, points[point_index].y, 0.0))
				fill_vertex_count += 1
			if bool(detail["draw_cracks"]) and (columns <= 8 or column % 2 == 0):
				var crack := PackedVector2Array()
				for offset in [Vector2(3, 3), Vector2(tile_width * 0.55, row_height * 0.5), Vector2(tile_width - 3, row_height - 3)]:
					crack.append(_project(Vector2(x, y) + Vector2(offset.x * reveal, offset.y) + drift, view))
				line_vertex_count += _append_line_strip(line_builder, crack, Color(0.7, 0.92, 1.0, 0.55 * (1.0 - crumble) * reveal))
			if enhanced and bool(detail["draw_accents"]) and variant % 2 == 0 and reveal >= 1.0:
				var center := _project(Vector2(x + tile_width * 0.5, y + row_height * 0.5) + drift, view)
				line_vertex_count += _append_line_segment(line_builder, center - Vector2(0, 4), center + Vector2(0, 4), Color(0.86, 1.0, 1.0, 0.7 * (1.0 - crumble)))
				line_vertex_count += _append_line_segment(line_builder, center - Vector2(3, 0), center + Vector2(3, 0), Color(0.86, 1.0, 1.0, 0.7 * (1.0 - crumble)))
	if _fill_mesh == null:
		_fill_mesh = ArrayMesh.new()
	else:
		_fill_mesh.clear_surfaces()
	if fill_vertex_count > 0:
		fill_builder.commit(_fill_mesh)
	if _line_mesh == null:
		_line_mesh = ArrayMesh.new()
	else:
		_line_mesh.clear_surfaces()
	if line_vertex_count > 0:
		line_builder.commit(_line_mesh)
	queue_redraw()


func _get_detail_profile() -> Dictionary:
	var active_count := get_tree().get_node_count_in_group(&"glacier_ground_visual")
	if active_count >= LOW_DETAIL_TRAIL_COUNT:
		return {"column_spacing": 36.0, "rows": 2, "draw_cracks": false, "draw_accents": false}
	if active_count >= MEDIUM_DETAIL_TRAIL_COUNT:
		return {"column_spacing": 26.0, "rows": 2, "draw_cracks": true, "draw_accents": false}
	return {"column_spacing": 18.0, "rows": 3, "draw_cracks": true, "draw_accents": true}


func _append_line_strip(builder: SurfaceTool, points: PackedVector2Array, color: Color) -> int:
	var added := 0
	for index in range(points.size() - 1):
		added += _append_line_segment(builder, points[index], points[index + 1], color)
	return added


func _append_line_segment(builder: SurfaceTool, from: Vector2, to: Vector2, color: Color) -> int:
	builder.set_color(color)
	builder.add_vertex(Vector3(from.x, from.y, 0.0))
	builder.set_color(color)
	builder.add_vertex(Vector3(to.x, to.y, 0.0))
	return 2


func _draw() -> void:
	if _fill_mesh != null and _fill_mesh.get_surface_count() > 0:
		draw_mesh(_fill_mesh, null)
	if _line_mesh != null and _line_mesh.get_surface_count() > 0:
		draw_mesh(_line_mesh, null)
