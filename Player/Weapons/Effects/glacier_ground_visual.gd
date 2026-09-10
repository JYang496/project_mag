extends Node2D

var area: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _project(point: Vector2, view: Node) -> Vector2:
	var world := area.to_global(point)
	if view != null:
		world = view.call("project_world_to_canvas", world, get_viewport())
	return to_local(world).round()

func _draw() -> void:
	if not is_instance_valid(area):
		return
	var length: float = area.get("path_length")
	var width: float = area.get("path_width")
	var enhanced: bool = area.get("cold_snap_active")
	var crumble: float = area.get_crumble_progress()
	var extension: float = area.get_extension_progress()
	var view := get_tree().get_first_node_in_group(&"hybrid_ground_view_3d")
	var columns := clampi(ceili(length / 18.0), 1, 48)
	var tile_width := length / columns
	for column in range(columns):
		var reveal := clampf(extension * columns - column, 0.0, 1.0)
		if reveal <= 0.0:
			continue
		for row in range(3):
			var variant := (column + row * 2) % 4
			if crumble > float(variant + 1) / 4.0:
				continue
			var x := column * tile_width
			var y := -width * 0.5 + row * width / 3.0
			var drift := Vector2((variant - 1) * 5, (row - 1) * 7) * crumble
			var inset := 2.0 + float(variant % 2) * 2
			var points := PackedVector2Array()
			var projectable := true
			for corner in [Vector2(inset,1),Vector2(tile_width-2,0),Vector2(tile_width-1,width/3-3),Vector2(2,width/3-1),Vector2(0,4)]:
				var point: Vector2 = Vector2(x,y)+Vector2(corner.x * reveal, corner.y)+drift
				if view != null and not view.call("can_project_world_point", area.to_global(point)):
					projectable = false
					break
				points.append(_project(point,view))
			# Pixel snapping can collapse the narrow advancing edge to a line,
			# or fold adjacent corners. Wait until it has a valid visible surface.
			if not projectable or Geometry2D.triangulate_polygon(points).is_empty():
				continue
			draw_colored_polygon(points,Color(0.28+variant*0.03,0.64,0.83,0.32*(1-crumble)*reveal))
			var crack := PackedVector2Array()
			for offset in [Vector2(3,3),Vector2(tile_width*0.55, width/6),Vector2(tile_width-3,width/3-3)]:
				crack.append(_project(Vector2(x,y)+Vector2(offset.x * reveal, offset.y)+drift,view))
			draw_polyline(crack,Color(0.7,0.92,1,0.55*(1-crumble)*reveal),1)
			if enhanced and variant % 2 == 0 and reveal >= 1.0:
				var center := _project(Vector2(x+tile_width/2,y+width/6)+drift,view)
				draw_line(center-Vector2(0,4),center+Vector2(0,4),Color(0.86,1,1,0.7*(1-crumble)),2)
				draw_line(center-Vector2(3,0),center+Vector2(3,0),Color(0.86,1,1,0.7*(1-crumble)),1)
