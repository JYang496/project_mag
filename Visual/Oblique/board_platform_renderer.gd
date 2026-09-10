class_name BoardPlatformRenderer
extends RefCounted

## A shallow levitation frame built only on the union boundary of enabled tiles.
## All curtain faces share exact boundary endpoints, including reentrant corners.
const UnderlightShader := preload("res://Visual/Oblique/arena_underlight.gdshader")
const BoundaryBuilderType := preload("res://Visual/Oblique/board_support_boundary_builder.gd")
const EnergyShader := preload("res://Visual/Oblique/board_support_energy.gdshader")
const SupportAtlas := preload("res://Visual/Oblique/assets/board_support/levitation/support_atlas.png")
const FacadeShader := preload("res://Visual/Oblique/board_support_facade.gdshader")
const EDGE_OVERLAP_WORLD := 0.002
const MODULE_WIDTH_2D := 128.0
const CONTACT_BOTTOM := -0.045
const FRAME_BOTTOM := -0.70
const FIELD_TOP := -0.05
const FIELD_BOTTOM := -2.4
const DARK := Color(0.025, 0.043, 0.065)
const METAL := Color(0.15, 0.20, 0.26)
const BEVEL := Color(0.24, 0.30, 0.36)
const RECESS := Color(0.009, 0.017, 0.027)
const CYAN := Color(0.035, 0.55, 0.72)

var _view: Node
var _visual_nodes: Array[Node3D] = []
var _last_model: Dictionary = {}

func setup(view: Node) -> void:
	_view = view

func clear() -> void:
	for node in _visual_nodes:
		if not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
	_visual_nodes.clear()
	_last_model.clear()

func get_last_model() -> Dictionary:
	return _last_model.duplicate(true)

func rebuild(cells: Array) -> void:
	clear()
	if not _is_ready():
		return
	var rects := collect_active_cell_rects(cells)
	_last_model = BoundaryBuilderType.build_model(rects, 512.0)
	var segments: Array = _last_model.segments
	if segments.is_empty():
		return
	var rim: Array[AABB] = []
	var frame: Array[AABB] = []
	var armor: Array[AABB] = []
	var bevels: Array[AABB] = []
	var lights: Array[AABB] = []
	var corners: Dictionary = {}
	var module_count := 0
	for segment: Dictionary in segments:
		var front: bool = segment.edge == &"bottom"
		var rear: bool = segment.edge == &"top"
		var bottom := FRAME_BOTTOM if front else (-0.16 if rear else -0.30)
		rim.append(_edge_prism(segment, 5.0, CONTACT_BOTTOM, -0.002))
		frame.append(_edge_prism(segment, 8.0, bottom, CONTACT_BOTTOM))
		# Continuous narrow underside rail connects separate armor panels.
		bevels.append(_edge_prism(segment, 10.0, bottom, bottom + 0.025))
		var start: Vector2 = segment.start
		var finish: Vector2 = segment.end
		if front:
			module_count += maxi(1, ceili(start.distance_to(finish) / MODULE_WIDTH_2D))
		for point: Vector2 in [start, finish]:
			if not corners.has(point):
				corners[point] = bottom
			corners[point] = minf(float(corners[point]), bottom)
	for point: Vector2 in corners:
		var bottom: float = corners[point]
		frame.append(_point_prism(point, 28.0, bottom - 0.07, -0.015))
		armor.append(_point_prism(point, 22.0, bottom - 0.04, -0.008))
		lights.append(_point_prism(point, 10.0, -0.009, -0.004))
	_add_box_mesh("BoardSupportContactRim", rim, _solid_material(RECESS))
	_add_box_mesh("BoardSupportLevitationFrame", frame, _solid_material(DARK))
	_add_box_mesh("BoardSupportArmor", armor, _solid_material(METAL))
	_add_box_mesh("BoardSupportBevels", bevels, _solid_material(BEVEL))

	_add_box_mesh("BoardSupportGenerators", lights, _solid_material(CYAN))
	_create_textured_facade(segments, corners)
	_create_energy_field(segments)
	_create_underlight(rects)
	_last_model["front_module_count"] = module_count
	_last_model["corner_node_count"] = corners.size()
	_last_model["energy_segment_count"] = segments.size()

func _create_underlight(rects: Array[Rect2]) -> void:
	if rects.is_empty():
		return
	var bounds := rects[0]
	for rect in rects:
		bounds = bounds.merge(rect)
	var plane := PlaneMesh.new()
	plane.size = bounds.size * _world_scale() * 1.22
	var material := ShaderMaterial.new()
	material.shader = UnderlightShader
	plane.material = material
	var instance := MeshInstance3D.new()
	instance.name = "ArenaUndersideAmbientGlow"
	instance.mesh = plane
	var center := bounds.get_center() * _world_scale()
	instance.position = Vector3(center.x, FIELD_BOTTOM - 0.15, center.y)
	_add_geometry(instance)


func _create_textured_facade(segments: Array, corners: Dictionary) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for segment: Dictionary in segments:
		var front: bool = segment.edge == &"bottom"
		var rear: bool = segment.edge == &"top"
		var start: Vector2 = segment.start
		var finish: Vector2 = segment.end
		var length := start.distance_to(finish)
		var count := maxi(1, ceili(length / MODULE_WIDTH_2D))
		var offset: Vector2 = segment.outward * 8.5
		var bottom := -0.80 if front else (-0.16 if rear else -0.30)
		for index in range(count):
			var a := start.lerp(finish, float(index) / count) + offset
			var b := start.lerp(finish, float(index + 1) / count) + offset
			var tile := (1 if index % 4 == 1 else 0) if front else 2
			_append_facade(vertices, uvs, colors, indices, a, b, CONTACT_BOTTOM, bottom, tile, 1.0 if front else 0.65)
	# Full textured corner sleeves bridge offset faces at convex and concave turns.
	for point: Vector2 in corners:
		var p := point - Vector2.ONE * 14.1
		var q := point + Vector2.ONE * 14.1
		var loop := [p, Vector2(q.x, p.y), q, Vector2(p.x, q.y)]
		for side in range(4):
			_append_facade(vertices, uvs, colors, indices, loop[side], loop[(side + 1) % 4], -0.015, float(corners[point]) - 0.07, 3, 0.85)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = FacadeShader
	material.set_shader_parameter("support_atlas", SupportAtlas)
	mesh.surface_set_material(0, material)
	_add_mesh_instance("BoardSupportTexturedFacade", mesh)

func _append_facade(vertices: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, a: Vector2, b: Vector2, top: float, bottom: float, tile: int, brightness: float) -> void:
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([
		Vector3(a.x * _world_scale(), top, a.y * _world_scale()),
		Vector3(b.x * _world_scale(), top, b.y * _world_scale()),
		Vector3(b.x * _world_scale(), bottom, b.y * _world_scale()),
		Vector3(a.x * _world_scale(), bottom, a.y * _world_scale()),
	]))
	# Half-texel inset prevents the neighbouring atlas cell bleeding at its edge.
	var origin := Vector2(tile % 2, floori(float(tile) / 2.0)) * 0.5
	var lo := origin + Vector2.ONE / 512.0
	var hi := origin + Vector2.ONE * (0.5 - 1.0 / 512.0)
	uvs.append_array(PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]))
	for index in range(4):
		colors.append(Color(brightness, brightness, brightness))
	indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

func _create_energy_field(segments: Array) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for segment: Dictionary in segments:
		var start: Vector2 = segment.start
		var finish: Vector2 = segment.end
		var base := vertices.size()
		# No normal offset: every convex/concave pair meets on the same line.
		for point: Vector2 in [start, finish]:
			vertices.append(Vector3(point.x * _world_scale(), FIELD_TOP, point.y * _world_scale()))
			vertices.append(Vector3(point.x * _world_scale(), FIELD_BOTTOM, point.y * _world_scale()))
		uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 2, base + 1, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = EnergyShader
	mesh.surface_set_material(0, material)
	_add_mesh_instance("BoardSupportEnergyField", mesh)

func collect_active_cell_rects(cells: Array) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for cell_variant in cells:
		var cell := cell_variant as Node2D
		if cell == null or not bool(cell.get("board_enabled")):
			continue
		var sprite := cell.get_node_or_null("Texture/Sprite2D") as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var rect := _sprite_global_aabb(sprite)
		if rect.position.is_finite() and rect.size.is_finite() \
				and rect.size.x > 0.0 and rect.size.y > 0.0:
			rects.append(rect)
	return rects


func _sprite_global_aabb(sprite: Sprite2D) -> Rect2:
	var local_rect := sprite.get_rect()
	var local_corners := PackedVector2Array([
		local_rect.position,
		Vector2(local_rect.end.x, local_rect.position.y),
		local_rect.end,
		Vector2(local_rect.position.x, local_rect.end.y),
	])
	var first := sprite.global_transform * local_corners[0]
	var minimum := first
	var maximum := first
	for index in range(1, local_corners.size()):
		var point := sprite.global_transform * local_corners[index]
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _point_prism(point: Vector2, size_2d: float, bottom_y: float, top_y: float) -> AABB:
	var world_scale := _world_scale()
	var half_size := size_2d * world_scale * 0.5
	return AABB(
		Vector3(point.x * world_scale - half_size, bottom_y, point.y * world_scale - half_size),
		Vector3(size_2d * world_scale, top_y - bottom_y, size_2d * world_scale)
	)


func _edge_prism(segment: Dictionary, width_2d: float, bottom_y: float, top_y: float) -> AABB:
	var world_scale := _world_scale()
	var start := segment.get("start", Vector2.ZERO) as Vector2
	var end := segment.get("end", Vector2.ZERO) as Vector2
	var outward := segment.get("outward", Vector2.ZERO) as Vector2
	var width := width_2d * world_scale
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	if absf(end.x - start.x) >= absf(end.y - start.y):
		minimum.x = minf(start.x, end.x) * world_scale - EDGE_OVERLAP_WORLD
		maximum.x = maxf(start.x, end.x) * world_scale + EDGE_OVERLAP_WORLD
		var z := start.y * world_scale
		minimum.z = z - width if outward.y < 0.0 else z - EDGE_OVERLAP_WORLD
		maximum.z = z + EDGE_OVERLAP_WORLD if outward.y < 0.0 else z + width
	else:
		minimum.z = minf(start.y, end.y) * world_scale - EDGE_OVERLAP_WORLD
		maximum.z = maxf(start.y, end.y) * world_scale + EDGE_OVERLAP_WORLD
		var x := start.x * world_scale
		minimum.x = x - width if outward.x < 0.0 else x - EDGE_OVERLAP_WORLD
		maximum.x = x + EDGE_OVERLAP_WORLD if outward.x < 0.0 else x + width
	minimum.y = bottom_y
	maximum.y = top_y
	return AABB(minimum, maximum - minimum)


func _add_box_mesh(mesh_name: String, boxes: Array[AABB], material: Material) -> void:
	if boxes.is_empty():
		return
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for box in boxes:
		_append_box(vertices, indices, box)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	_add_mesh_instance(mesh_name, mesh)


func _append_box(vertices: PackedVector3Array, indices: PackedInt32Array, box: AABB) -> void:
	var p := box.position
	var e := box.end
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([
		Vector3(p.x, p.y, p.z), Vector3(e.x, p.y, p.z), Vector3(e.x, e.y, p.z), Vector3(p.x, e.y, p.z),
		Vector3(p.x, p.y, e.z), Vector3(e.x, p.y, e.z), Vector3(e.x, e.y, e.z), Vector3(p.x, e.y, e.z),
	]))
	indices.append_array(PackedInt32Array([
		base, base + 2, base + 1, base, base + 3, base + 2,
		base + 4, base + 5, base + 6, base + 4, base + 6, base + 7,
		base, base + 4, base + 7, base, base + 7, base + 3,
		base + 1, base + 2, base + 6, base + 1, base + 6, base + 5,
		base + 3, base + 7, base + 6, base + 3, base + 6, base + 2,
		base, base + 1, base + 5, base, base + 5, base + 4,
	]))


func _add_mesh_instance(mesh_name: String, mesh: Mesh) -> void:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	_add_geometry(instance)


func _add_geometry(instance: GeometryInstance3D) -> void:
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta(&"hybrid_board_visual", true)
	instance.set_meta(&"board_support_visual", true)
	instance.visible = bool(_view.get("_board_visual_active"))
	_view._ground_root.add_child(instance)
	_visual_nodes.append(instance)


func _solid_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _world_scale() -> float:
	return maxf(float(_view.get("world_scale")), 0.0001)


func _is_ready() -> bool:
	return _view != null \
		and is_instance_valid(_view) \
		and _view.get("_ground_root") != null \
		and is_instance_valid(_view._ground_root)
