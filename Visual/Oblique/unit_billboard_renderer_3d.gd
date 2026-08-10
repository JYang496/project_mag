class_name UnitBillboardRenderer3D
extends RefCounted

const UNIT_SHADER := preload("res://Shaders/unit_billboard_3d.gdshader")
const UNIT_RENDER_PRIORITY := 15
# Camera-facing quads can rotate below their ground anchor even though the unit
# itself is above the floor. Move every unit by the same view-depth clearance so
# terrain cannot clip weapons while preserving unit-to-unit depth ordering.
const TERRAIN_DEPTH_CLEARANCE_WORLD := 0.50

var _view: Node
var _root: Node3D
var _camera: Camera3D
var _quad: QuadMesh
var _entries: Dictionary = {}
var _material_cache: Dictionary = {}
var _available_meshes: Array[MeshInstance3D] = []
var max_visible_billboards := 320
var cull_margin_pixels := 96.0
var _visible_count := 0
var _culled_count := 0
var _shader_parameter_updates := 0


func setup(view: Node, root: Node3D, camera: Camera3D) -> void:
	_view = view
	_root = root
	_camera = camera
	_quad = QuadMesh.new()
	_quad.orientation = PlaneMesh.FACE_Z
	_quad.size = Vector2.ONE


func register(source: Node2D) -> void:
	if not _is_ready() or source == null or _entries.has(source.get_instance_id()):
		return
	if not source.has_method("get_unit_billboard_config"):
		return
	var unit_owner := source.get_parent() as Node2D
	if unit_owner == null:
		return
	var mesh := _acquire_mesh()
	mesh.name = "%s%sBillboard3D" % [unit_owner.name, source.name]
	_entries[source.get_instance_id()] = {
		"source": weakref(source),
		"owner": weakref(unit_owner),
		"mesh": mesh,
	}
	if source.has_method("mark_hybrid_billboard_registered"):
		source.call("mark_hybrid_billboard_registered")
	source.set_meta(&"hybrid_unit_billboard_registered", true)


func unregister(source: Node) -> void:
	if source == null:
		return
	var source_id := source.get_instance_id()
	if not _entries.has(source_id):
		return
	var entry := _entries[source_id] as Dictionary
	_release_mesh(entry.get("mesh") as MeshInstance3D)
	_entries.erase(source_id)
	source.set_meta(&"hybrid_unit_billboard_registered", false)


func sync_late(_delta: float) -> void:
	if not _is_ready():
		return
	_visible_count = 0
	_culled_count = 0
	for source_id in _entries.keys():
		var entry := _entries[source_id] as Dictionary
		var source_ref := entry.get("source") as WeakRef
		var owner_ref := entry.get("owner") as WeakRef
		var source := source_ref.get_ref() as Node2D if source_ref != null else null
		var unit_owner := owner_ref.get_ref() as Node2D if owner_ref != null else null
		var mesh := entry.get("mesh") as MeshInstance3D
		if source == null or unit_owner == null or mesh == null or not is_instance_valid(mesh):
			_release_mesh(mesh)
			_entries.erase(source_id)
			continue
		var config := source.call("get_unit_billboard_config") as Dictionary
		_sync_entry(source, unit_owner, mesh, config, entry)


func _sync_entry(source: Node2D, unit_owner: Node2D, mesh: MeshInstance3D, config: Dictionary, entry: Dictionary) -> void:
	var texture := config.get("texture") as Texture2D
	var visual_size_px := config.get("visual_size_px", Vector2.ZERO) as Vector2
	var local_anchor := config.get("local_ground_anchor", Vector2.ZERO) as Vector2
	var logical_anchor := unit_owner.global_transform * local_anchor
	var depth_anchor_world := config.get("depth_anchor_world", logical_anchor) as Vector2
	var ground_anchor_3d := _view.call("world_2d_to_ground_anchor", depth_anchor_world) as Vector3
	var anchor_3d := terrain_safe_anchor(ground_anchor_3d)
	var units_per_pixel := _world_units_per_pixel(anchor_3d)
	var screen_feedback_offset := config.get("screen_feedback_offset", Vector2.ZERO) as Vector2
	var next_mesh_position := anchor_3d \
		+ _camera.global_transform.basis.x.normalized() * screen_feedback_offset.x * units_per_pixel \
		- _camera.global_transform.basis.y.normalized() * screen_feedback_offset.y * units_per_pixel
	if entry.get("last_anchor", Vector3.INF) != next_mesh_position:
		mesh.position = next_mesh_position
		entry["last_anchor"] = next_mesh_position
	var inside_view := bool(_view.call("is_world_point_within_visual_bounds", logical_anchor, cull_margin_pixels))
	var visible := bool(config.get("visible", true)) and texture != null and visual_size_px.x > 0.0 and visual_size_px.y > 0.0 and inside_view and _visible_count < max_visible_billboards
	mesh.visible = visible
	if not visible:
		_culled_count += 1
		return
	_visible_count += 1
	var appearance_version := int(config.get("appearance_version", -1))
	var visibility_version := int(config.get("visibility_version", -1))
	var appearance_changed := appearance_version != int(entry.get("appearance_version", -2))
	var visibility_changed := visibility_version != int(entry.get("visibility_version", -2))
	if appearance_changed:
		mesh.material_override = _get_material(texture)
	var size_world := visual_size_px * units_per_pixel
	if appearance_changed or entry.get("last_size_world", Vector2.INF) != size_world:
		mesh.set_instance_shader_parameter("billboard_size_world", size_world)
		entry["last_size_world"] = size_world
		mesh.set_instance_shader_parameter("bottom_padding_ratio", clampf(float(config.get("bottom_padding_px", 0.0)) / maxf(visual_size_px.y, 1.0), 0.0, 0.49))
		mesh.set_instance_shader_parameter("visual_rotation_radians", float(config.get("visual_rotation_radians", 0.0)))
		mesh.set_instance_shader_parameter("vertical_anchor_offset", float(config.get("vertical_anchor_offset", 0.5)))
		mesh.set_instance_shader_parameter("flip_h", bool(config.get("flip_h", false)))
		mesh.set_instance_shader_parameter("flip_v", bool(config.get("flip_v", false)))
		mesh.set_instance_shader_parameter("visual_color", config.get("color", Color.WHITE) as Color)
		mesh.set_instance_shader_parameter("flash_color", config.get("flash_color", Color.WHITE) as Color)
		mesh.set_instance_shader_parameter("flash_amount", float(config.get("flash_amount", 0.0)))
		mesh.set_instance_shader_parameter("warning_color", config.get("warning_color", Color.WHITE) as Color)
		mesh.set_instance_shader_parameter("warning_amount", float(config.get("warning_amount", 0.0)))
		mesh.set_instance_shader_parameter("outline_color", config.get("outline_color", Color.TRANSPARENT) as Color)
		mesh.set_instance_shader_parameter("outline_width_px", float(config.get("outline_width_px", 0.0)))
		_shader_parameter_updates += 12
	if appearance_changed:
		mesh.set_instance_shader_parameter("source_id", float(source.get_instance_id() % 4096))
		_shader_parameter_updates += 1
	entry["appearance_version"] = appearance_version
	entry["visibility_version"] = visibility_version
	if visibility_changed:
		entry["last_visible"] = visible


func terrain_safe_anchor(ground_anchor_3d: Vector3) -> Vector3:
	if _camera == null or not is_instance_valid(_camera):
		return ground_anchor_3d
	var toward_camera := ground_anchor_3d.direction_to(_camera.global_position)
	if toward_camera.length_squared() <= 0.0001:
		return ground_anchor_3d
	return ground_anchor_3d + toward_camera * TERRAIN_DEPTH_CLEARANCE_WORLD


func _world_units_per_pixel(anchor_3d: Vector3) -> float:
	var viewport_height := maxf(_view.get_viewport().get_visible_rect().size.y, 1.0)
	var camera_local := _camera.global_transform.affine_inverse() * anchor_3d
	var depth := maxf(absf(camera_local.z), 0.01)
	return 2.0 * depth * tan(deg_to_rad(_camera.fov) * 0.5) / viewport_height


func _get_material(texture: Texture2D) -> ShaderMaterial:
	var texture_id := texture.get_instance_id()
	if _material_cache.has(texture_id):
		return _material_cache[texture_id] as ShaderMaterial
	var shader_material := ShaderMaterial.new()
	shader_material.shader = UNIT_SHADER
	# Units must remain above terrain, cell activation outlines, ordinary ground
	# effects, and affiliation markers while danger telegraphs (priority 20+)
	# retain the final warning layer.
	shader_material.render_priority = UNIT_RENDER_PRIORITY
	shader_material.set_shader_parameter("sprite_texture", texture)
	_material_cache[texture_id] = shader_material
	return shader_material


func _acquire_mesh() -> MeshInstance3D:
	var mesh: MeshInstance3D
	if _available_meshes.is_empty():
		mesh = MeshInstance3D.new()
		mesh.mesh = _quad
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(mesh)
	else:
		mesh = _available_meshes.pop_back()
	mesh.visible = false
	return mesh


func _release_mesh(mesh: MeshInstance3D) -> void:
	if mesh == null or not is_instance_valid(mesh):
		return
	mesh.visible = false
	mesh.material_override = null
	if not _available_meshes.has(mesh):
		_available_meshes.append(mesh)


func clear() -> void:
	_entries.clear()
	_available_meshes.clear()
	_material_cache.clear()
	if _root != null and is_instance_valid(_root):
		for child in _root.get_children():
			child.queue_free()


func get_debug_entries() -> Dictionary:
	return _entries


func get_performance_metrics() -> Dictionary:
	return {
		"registered": _entries.size(),
		"visible": _visible_count,
		"culled": _culled_count,
		"shader_parameter_updates": _shader_parameter_updates,
		"visible_limit": max_visible_billboards,
	}


func _is_ready() -> bool:
	return _view != null and is_instance_valid(_view) and _root != null and is_instance_valid(_root) and _camera != null and is_instance_valid(_camera)
