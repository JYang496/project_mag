class_name ArenaBoundaryRenderer
extends RefCounted

## One surface seam per shared edge, and one node per shared vertex.
## Geometry follows the existing floor footprint; it never changes blockers.
const BoundaryShader := preload("res://Visual/Oblique/arena_boundary.gdshader")
const Groove := preload("res://Visual/Oblique/assets/arena_boundary/groove.svg")
const Junction := preload("res://Visual/Oblique/assets/arena_boundary/junction.svg")
const WIDTH := 8.0
const NODE_SIZE := 12.0
const SURFACE_HEIGHT := 0.019

var _view: Node
var _material: ShaderMaterial
var _edges: Dictionary = {}
var _junctions: Dictionary = {}

func setup(view: Node) -> void:
	_view = view
	_material = ShaderMaterial.new()
	_material.shader = BoundaryShader
	_material.set_shader_parameter("groove_texture", Groove)
	_material.set_shader_parameter("junction_texture", Junction)

func clear() -> void:
	for collection in [_edges, _junctions]:
		for entry: Dictionary in collection.values():
			var mesh := entry.get("mesh") as MeshInstance3D
			if is_instance_valid(mesh) and not mesh.is_queued_for_deletion():
				if mesh.get_parent() != null:
					mesh.get_parent().remove_child(mesh)
				mesh.queue_free()
		collection.clear()

func rebuild(cells: Array) -> void:
	clear()
	for value: Variant in cells:
		var cell := value as Node2D
		if cell == null:
			continue
		var sprite := cell.get_node_or_null("Texture/Sprite2D") as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var size := sprite.texture.get_size() * sprite.global_scale.abs()
		var rect := Rect2(sprite.global_position - size * 0.5, size)
		var a := Vector2i(rect.position.round())
		var b := Vector2i(Vector2(rect.end.x, rect.position.y).round())
		var c := Vector2i(rect.end.round())
		var d := Vector2i(Vector2(rect.position.x, rect.end.y).round())
		_add_edge(a, b, cell)
		_add_edge(b, c, cell)
		_add_edge(d, c, cell)
		_add_edge(a, d, cell)
	for key: Vector4i in _edges:
		var entry: Dictionary = _edges[key]
		var start := Vector2(key.x, key.y)
		var finish := Vector2(key.z, key.w)
		var delta := finish - start
		var vertical := absf(delta.y) > absf(delta.x)
		var length := maxf(delta.length() - NODE_SIZE, 1.0)
		entry.mesh = _make_mesh("ArenaGroove", Vector2(WIDTH, length) if vertical else Vector2(length, WIDTH), vertical)
		entry.mesh.set_instance_shader_parameter("segment_length", length)
		entry.mesh.set_instance_shader_parameter("flow_offset", start.x + start.y + NODE_SIZE * 0.5)
		_add_junction(Vector2i(start), key, 3 if vertical else 1, entry)
		_add_junction(Vector2i(finish), key, 2 if vertical else 0, entry)
	for point: Vector2i in _junctions:
		var entry: Dictionary = _junctions[point]
		entry.mesh = _make_mesh("ArenaJunction", Vector2.ONE * NODE_SIZE)
		entry.mesh.set_instance_shader_parameter("junction", true)
	sync()

func _add_edge(a: Vector2i, b: Vector2i, cell: Node2D) -> void:
	var key := Vector4i(a.x, a.y, b.x, b.y)
	if not _edges.has(key):
		_edges[key] = {
			"owners": [], "anchor": weakref(cell),
			"offset": (Vector2(a) + Vector2(b)) * 0.5 - cell.global_position,
			"state": 0.0, "visible": false,
		}
	_edges[key].owners.append(weakref(cell))

func _add_junction(point: Vector2i, key: Vector4i, arm: int, edge: Dictionary) -> void:
	if not _junctions.has(point):
		var anchor := (edge.anchor as WeakRef).get_ref() as Node2D
		_junctions[point] = {"arms": {}, "anchor": edge.anchor, "offset": Vector2(point) - anchor.global_position}
	_junctions[point].arms[arm] = key

func _make_mesh(label: String, size: Vector2, vertical := false) -> MeshInstance3D:
	# Explicit UVs keep the same flow direction and arm orientation on X/Z.
	var half_size := size * float(_view.world_scale) * 0.5
	var vertices := PackedVector3Array([
		Vector3(-half_size.x, 0, -half_size.y), Vector3(half_size.x, 0, -half_size.y),
		Vector3(half_size.x, 0, half_size.y), Vector3(-half_size.x, 0, half_size.y),
	])
	var uv := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	if vertical:
		uv = PackedVector2Array([Vector2.ZERO, Vector2.DOWN, Vector2.ONE, Vector2.RIGHT])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface.surface_set_material(0, _material)
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_meta(&"hybrid_board_visual", true)
	_view._ground_root.add_child(mesh)
	return mesh

func sync() -> void:
	if _view == null or not is_instance_valid(_view):
		return
	_material.set_shader_parameter("animation_time", float(_view._shader_animation_time))
	for entry: Dictionary in _edges.values():
		var state := 0.0
		var supported := false
		for owner_ref: WeakRef in entry.owners:
			var cell := owner_ref.get_ref() as Node2D
			if cell == null or not bool(cell.get("board_enabled")):
				continue
			var cell_state := 1.0
			if cell.has_method("has_player_inside") and bool(cell.call("has_player_inside")):
				cell_state = 2.0
			var ground_entry: Dictionary = _view._cell_meshes.get(cell.get_instance_id(), {})
			var ground := ground_entry.get("mesh") as MeshInstance3D
			if ground != null:
				var progress: Variant = ground.get_instance_shader_parameter("deployment_progress")
				# The floor reveals radially. Wait for its corners before drawing a
				# complete seam, so channels cannot float over undiscovered floor.
				if progress != null and float(progress) < 0.95:
					continue
				var dim: Variant = ground.get_instance_shader_parameter("deployment_dim")
				if dim != null and float(dim) < 0.95:
					cell_state = 0.0
			supported = true
			state = maxf(state, cell_state)
		entry.state = state
		entry.visible = supported and bool(_view._board_visual_active)
		var mesh := entry.mesh as MeshInstance3D
		mesh.visible = entry.visible
		mesh.set_instance_shader_parameter("boundary_state", state)
		_position_mesh(entry)
	for entry: Dictionary in _junctions.values():
		var states := Vector4(-1, -1, -1, -1)
		var supported := false
		for arm: int in entry.arms:
			var edge: Dictionary = _edges[entry.arms[arm]]
			if bool(edge.visible):
				states[arm] = float(edge.state)
				supported = true
		var mesh := entry.mesh as MeshInstance3D
		mesh.visible = supported
		mesh.set_instance_shader_parameter("arm_states", states)
		_position_mesh(entry)

func _position_mesh(entry: Dictionary) -> void:
	var anchor := (entry.anchor as WeakRef).get_ref() as Node2D
	var mesh := entry.mesh as MeshInstance3D
	if anchor == null:
		mesh.visible = false
		return
	mesh.position = _view.world_2d_to_3d(anchor.global_position + (entry.offset as Vector2)) + Vector3.UP * SURFACE_HEIGHT
