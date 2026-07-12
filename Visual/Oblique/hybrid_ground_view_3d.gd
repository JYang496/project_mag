class_name HybridGroundView3D
extends Node3D

const HybridCameraDefaultsType := preload("res://Visual/Oblique/hybrid_camera_defaults.gd")
@export var enabled: bool = true
const DEFAULT_CAMERA_FOV: float = 34.0
const DEFAULT_WORLD_SCALE: float = 0.01

var camera_fov: float = DEFAULT_CAMERA_FOV
@export_range(25.0, 75.0, 0.5) var camera_pitch_degrees: float = 52.0
@export_range(-20.0, 20.0, 0.5) var camera_yaw_degrees: float = 0.0
@export_range(5.0, 40.0, 0.5) var camera_distance: float = HybridCameraDefaultsType.CAMERA_DISTANCE
var world_scale: float = DEFAULT_WORLD_SCALE
@export var board_path: NodePath = NodePath("../Board")
@export var cell_border_color: Color = Color(0.08, 0.12, 0.15, 0.82)
@export_range(1.0, 8.0, 0.5) var cell_border_width_2d: float = 3.0

var _camera: Camera3D
var _ground_root: Node3D
var _board: Node2D
var _player: Node2D
var _activation_meshes: Dictionary = {}
var _cell_meshes: Dictionary = {}
var _shadow_meshes: Dictionary = {}
var _area_meshes: Dictionary = {}
var _segment_meshes: Dictionary = {}
var _rest_zone_meshes: Dictionary = {}
var _rest_area: Node2D
var _rest_ground_mesh: MeshInstance3D
var _rest_ground_material: StandardMaterial3D
var _rest_ground_sprite: WeakRef
var _scan_cooldown: float = 0.0
var _projection_ready: bool = false
var _board_visual_active: bool = true

func _ready() -> void:
	add_to_group(&"hybrid_ground_view_3d")
	_camera = Camera3D.new()
	_camera.name = "GroundCamera3D"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.current = enabled
	add_child(_camera)
	_camera.position = Vector3(0.0, 14.0, 11.0)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_projection_ready = true
	_ground_root = Node3D.new()
	_ground_root.name = "GroundMeshes"
	add_child(_ground_root)
	_board = get_node_or_null(board_path) as Node2D
	_connect_board_signals()
	if _board != null:
		var active_value: Variant = _board.get("_board_active")
		if active_value != null:
			_board_visual_active = bool(active_value)
	call_deferred("_rebuild_ground")
	call_deferred("_setup_rest_area_ground")
	call_deferred("_hide_legacy_board_boundary_visuals")

func _process(delta: float) -> void:
	if not enabled or _camera == null:
		return
	_resolve_player()
	var target_2d := _player.global_position if _player != null else Vector2.ZERO
	var target_3d := world_2d_to_3d(target_2d)
	var pitch := deg_to_rad(camera_pitch_degrees)
	var yaw := deg_to_rad(camera_yaw_degrees)
	var horizontal_distance := camera_distance * cos(pitch)
	var height := camera_distance * sin(pitch)
	var backward := Vector3(sin(yaw), 0.0, cos(yaw)) * horizontal_distance
	_camera.position = target_3d + backward + Vector3.UP * height
	_camera.fov = camera_fov
	_camera.look_at(target_3d, Vector3.UP)
	_projection_ready = true
	_sync_cell_meshes()
	_sync_activation_visuals()
	_sync_rest_ground_mesh()
	_sync_rest_zone_meshes()
	_scan_cooldown -= delta
	if _scan_cooldown <= 0.0:
		_scan_cooldown = 0.25
		_discover_ground_overlays()
	_sync_runtime_overlays()

func configure(pitch: float, yaw: float, distance: float) -> void:
	camera_pitch_degrees = clampf(pitch, 25.0, 75.0)
	camera_yaw_degrees = clampf(yaw, -20.0, 20.0)
	camera_distance = clampf(distance, 5.0, 40.0)

func world_2d_to_3d(point: Vector2) -> Vector3:
	return Vector3(point.x * world_scale, 0.0, point.y * world_scale)

func project_world_to_screen(point: Vector2) -> Vector2:
	if _camera == null or not _projection_ready:
		return Vector2.ZERO
	var point_3d := world_2d_to_3d(point)
	var camera_local := _camera.global_transform.affine_inverse() * point_3d
	if absf(camera_local.z) <= 0.0001 or _camera.is_position_behind(point_3d):
		return get_viewport().get_visible_rect().size * 0.5
	return _camera.unproject_position(point_3d)

func can_project_world_point(point: Vector2) -> bool:
	if _camera == null or not _projection_ready or not is_instance_valid(_camera):
		return false
	var point_3d := world_2d_to_3d(point)
	var camera_local := _camera.global_transform.affine_inverse() * point_3d
	return camera_local.z < -0.0001 and not _camera.is_position_behind(point_3d)

func project_world_to_canvas(point: Vector2, viewport: Viewport) -> Vector2:
	if viewport == null:
		return point
	return viewport.get_canvas_transform().affine_inverse() * project_world_to_screen(point)

func screen_to_world_2d(screen_position: Vector2) -> Vector2:
	if _camera == null or not _projection_ready or not is_instance_valid(_camera):
		return Vector2.ZERO
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) <= 0.00001:
		return Vector2.ZERO
	var distance_to_ground := -ray_origin.y / ray_direction.y
	if distance_to_ground < 0.0:
		return Vector2.ZERO
	var hit := ray_origin + ray_direction * distance_to_ground
	return Vector2(hit.x, hit.z) / maxf(world_scale, 0.0001)

func screen_vector_to_world(vector: Vector2) -> Vector2:
	if vector == Vector2.ZERO or _camera == null:
		return vector
	var right_3d := _camera.global_basis.x
	var forward_3d := -_camera.global_basis.z
	var right := Vector2(right_3d.x, right_3d.z).normalized()
	var up := Vector2(forward_3d.x, forward_3d.z).normalized()
	return (right * vector.x - up * vector.y).normalized()

func world_vector_to_screen(vector: Vector2, origin: Vector2) -> Vector2:
	if vector == Vector2.ZERO:
		return vector
	var sample_vector := vector.normalized() * 100.0
	return project_world_to_screen(origin + sample_vector) - project_world_to_screen(origin)

func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var players := get_tree().get_nodes_in_group(&"player")
	if not players.is_empty():
		_player = players[0] as Node2D

func _exit_tree() -> void:
	_projection_ready = false
	_player = null
	_rest_area = null
	_clear_ground_visual_caches()

func _rebuild_ground() -> void:
	if _ground_root == null or _board == null:
		return
	_clear_ground_visual_caches()
	for child in _ground_root.get_children():
		child.queue_free()
	if not enabled or not _board.has_method("get_cells"):
		return
	for cell_variant in _board.call("get_cells"):
		var cell := cell_variant as Node2D
		if cell == null:
			continue
		var texture_sprite := cell.get_node_or_null("Texture/Sprite2D") as Sprite2D
		if texture_sprite == null or texture_sprite.texture == null:
			continue
		var texture_root := cell.get_node_or_null("Texture") as CanvasItem
		if texture_root != null:
			texture_root.visible = false
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "%sGround" % cell.name
		var quad := QuadMesh.new()
		quad.orientation = PlaneMesh.FACE_Y
		var texture_size := texture_sprite.texture.get_size() * texture_sprite.scale
		var texture_parent := texture_sprite.get_parent() as Node2D
		if texture_parent != null:
			texture_size *= texture_parent.scale
		quad.size = texture_size * world_scale
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_texture = texture_sprite.texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = material
		mesh_instance.mesh = quad
		mesh_instance.set_meta(&"hybrid_board_visual", true)
		var center := cell.global_position + Vector2(256.0, 256.0)
		mesh_instance.position = world_2d_to_3d(center)
		_ground_root.add_child(mesh_instance)
		_cell_meshes[cell.get_instance_id()] = {
			"cell": weakref(cell),
			"sprite": weakref(texture_sprite),
			"mesh": mesh_instance,
			"material": material,
		}
		_connect_cell_signal(cell)
		var cell_enabled := bool(cell.get("board_enabled"))
		mesh_instance.visible = _board_visual_active and cell_enabled
		if cell_enabled:
			_create_cell_border_meshes(cell, center, texture_size)
		_create_activation_mesh(cell)
	call_deferred("_setup_rest_area_ground")
	call_deferred("_hide_legacy_board_boundary_visuals")

func _clear_ground_visual_caches() -> void:
	_activation_meshes.clear()
	_cell_meshes.clear()
	_rest_zone_meshes.clear()
	_rest_ground_mesh = null
	_rest_ground_material = null
	_rest_ground_sprite = null
	_shadow_meshes.clear()
	_area_meshes.clear()
	_segment_meshes.clear()
	_rest_area = null
	_scan_cooldown = 0.0

func _create_cell_border_meshes(cell: Node2D, center: Vector2, cell_size: Vector2) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = cell_border_color
	var half_size := cell_size * 0.5
	var thickness := maxf(cell_border_width_2d, 1.0)
	_create_ground_border_strip("%sBorderTop" % cell.name, center + Vector2(0.0, -half_size.y), Vector2(cell_size.x, thickness), material)
	_create_ground_border_strip("%sBorderBottom" % cell.name, center + Vector2(0.0, half_size.y), Vector2(cell_size.x, thickness), material)
	_create_ground_border_strip("%sBorderLeft" % cell.name, center + Vector2(-half_size.x, 0.0), Vector2(thickness, cell_size.y), material)
	_create_ground_border_strip("%sBorderRight" % cell.name, center + Vector2(half_size.x, 0.0), Vector2(thickness, cell_size.y), material)

func _create_ground_border_strip(strip_name: String, center: Vector2, size_2d: Vector2, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = strip_name
	var box := BoxMesh.new()
	box.size = Vector3(size_2d.x * world_scale, 0.006, size_2d.y * world_scale)
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.set_meta(&"hybrid_board_visual", true)
	mesh_instance.visible = _board_visual_active
	mesh_instance.position = world_2d_to_3d(center) + Vector3.UP * 0.009
	_ground_root.add_child(mesh_instance)

func _hide_legacy_board_boundary_visuals() -> void:
	if not is_inside_tree():
		return
	for visual_variant in get_tree().get_nodes_in_group(&"legacy_board_boundary_visual"):
		var visual := visual_variant as CanvasItem
		if visual != null:
			visual.visible = false

func _create_activation_mesh(cell: Node2D) -> void:
	var activation := cell.get_node_or_null("ActivationVisual") as CanvasItem
	if activation == null:
		return
	activation.visible = false
	var mesh := MeshInstance3D.new()
	mesh.name = "%sActivation" % cell.name
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2(512.0, 512.0) * world_scale * 0.96
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.9, 0.45, 0.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	mesh.mesh = quad
	mesh.set_meta(&"hybrid_board_visual", true)
	mesh.position = world_2d_to_3d(cell.global_position + Vector2(256.0, 256.0)) + Vector3.UP * 0.012
	_ground_root.add_child(mesh)
	_activation_meshes[cell.get_instance_id()] = {
		"source": weakref(activation),
		"cell": weakref(cell),
		"mesh": mesh,
		"material": material,
	}

func _sync_activation_visuals() -> void:
	for entry_variant in _activation_meshes.values():
		var entry := entry_variant as Dictionary
		var source_ref := entry.source as WeakRef
		var activation := source_ref.get_ref() as Node
		var cell_ref := entry.cell as WeakRef
		var cell := cell_ref.get_ref() as Node2D
		var mesh := entry.mesh as MeshInstance3D
		var material := entry.material as StandardMaterial3D
		if activation == null or cell == null or mesh == null:
			continue
		mesh.position = world_2d_to_3d(cell.global_position + Vector2(256.0, 256.0)) + Vector3.UP * 0.012
		var highlighted := float(activation.get("highlight_amount"))
		var active := bool(activation.get("_active"))
		var has_task := bool(activation.get("_has_task"))
		var alpha := 0.0
		var color := Color(0.2, 0.9, 0.45, 1.0)
		if highlighted > 0.001:
			alpha = 0.16 + highlighted * 0.14
		elif not active:
			color = Color(0.04, 0.09, 0.12, 1.0)
			alpha = 0.34
		elif has_task:
			color = Color(1.0, 0.7, 0.2, 1.0)
			alpha = 0.08
		material.albedo_color = Color(color.r, color.g, color.b, alpha)
		mesh.visible = _board_visual_active and bool(cell.get("board_enabled")) and alpha > 0.001

func _connect_board_signals() -> void:
	if _board == null:
		return
	var active_callable := Callable(self, "_on_board_visual_active_changed")
	if _board.has_signal("board_visual_active_changed") and not _board.is_connected("board_visual_active_changed", active_callable):
		_board.connect("board_visual_active_changed", active_callable)
	var recenter_callable := Callable(self, "_on_board_recentered")
	if _board.has_signal("board_recentered") and not _board.is_connected("board_recentered", recenter_callable):
		_board.connect("board_recentered", recenter_callable)
	var cells_callable := Callable(self, "_on_active_cells_changed")
	if _board.has_signal("active_cells_changed") and not _board.is_connected("active_cells_changed", cells_callable):
		_board.connect("active_cells_changed", cells_callable)

func _connect_cell_signal(cell: Node2D) -> void:
	if not cell.has_signal("terrain_visual_changed"):
		return
	var callable := Callable(self, "_on_cell_terrain_visual_changed")
	if not cell.is_connected("terrain_visual_changed", callable):
		cell.connect("terrain_visual_changed", callable)

func _on_board_visual_active_changed(active: bool, _immediate: bool) -> void:
	_board_visual_active = active
	_set_board_mesh_visibility(active)
	if active:
		_sync_cell_meshes()
		_sync_activation_visuals()

func _on_board_recentered(offset: Vector2) -> void:
	var offset_3d := world_2d_to_3d(offset)
	if _ground_root != null:
		for child in _ground_root.get_children():
			var visual := child as GeometryInstance3D
			if visual != null and visual.has_meta(&"hybrid_board_visual"):
				visual.position += offset_3d
	_sync_cell_meshes()

func _on_active_cells_changed(_active_cell_ids: PackedInt32Array) -> void:
	call_deferred("_rebuild_ground")

func _on_cell_terrain_visual_changed(cell: Cell, texture: Texture2D) -> void:
	var entry_variant: Variant = _cell_meshes.get(cell.get_instance_id())
	if not entry_variant is Dictionary:
		return
	var entry := entry_variant as Dictionary
	var material := entry.get("material") as StandardMaterial3D
	if material != null:
		material.albedo_texture = texture

func _sync_cell_meshes() -> void:
	for entry_variant in _cell_meshes.values():
		var entry := entry_variant as Dictionary
		var cell_ref := entry.get("cell") as WeakRef
		var sprite_ref := entry.get("sprite") as WeakRef
		var cell := cell_ref.get_ref() as Node2D if cell_ref != null else null
		var sprite := sprite_ref.get_ref() as Sprite2D if sprite_ref != null else null
		var mesh := entry.get("mesh") as MeshInstance3D
		var material := entry.get("material") as StandardMaterial3D
		if cell == null or mesh == null or not is_instance_valid(mesh):
			continue
		mesh.position = world_2d_to_3d(cell.global_position + Vector2(256.0, 256.0))
		mesh.visible = _board_visual_active and bool(cell.get("board_enabled"))
		if sprite != null and material != null and material.albedo_texture != sprite.texture:
			material.albedo_texture = sprite.texture

func _set_board_mesh_visibility(active: bool) -> void:
	if _ground_root == null:
		return
	for child in _ground_root.get_children():
		var visual := child as GeometryInstance3D
		if visual != null and visual.has_meta(&"hybrid_board_visual"):
			visual.visible = active

func _discover_ground_overlays() -> void:
	_hide_legacy_board_boundary_visuals()
	for shadow in get_tree().get_nodes_in_group(&"hybrid_ground_shadow"):
		register_shadow(shadow as CanvasItem)
	for area in get_tree().get_nodes_in_group(&"hybrid_ground_area_effect"):
		_register_area_effect(area as Node2D)
	for warning in get_tree().get_nodes_in_group(&"hybrid_ground_warning_circle"):
		_register_warning_circle(warning as Node2D)
	for segment in get_tree().get_nodes_in_group(&"hybrid_ground_segment"):
		_register_ground_segment(segment as Line2D)

func register_shadow(shadow: CanvasItem) -> void:
	if shadow == null or _shadow_meshes.has(shadow.get_instance_id()):
		return
	var owner_2d := shadow.get_parent() as Node2D
	if owner_2d == null:
		return
	shadow.visible = false
	var mesh := _create_disc_mesh(Color(0.0, 0.0, 0.0, 0.20))
	_ground_root.add_child(mesh)
	var shadow_2d := shadow as Node2D
	var local_anchor := shadow_2d.position if shadow_2d != null else Vector2.ZERO
	var size_2d := _get_shadow_visual_size(shadow)
	_shadow_meshes[shadow.get_instance_id()] = {
		"source": weakref(shadow),
		"owner": weakref(owner_2d),
		"mesh": mesh,
		"local_anchor": local_anchor,
		"size_2d": size_2d,
	}

func _get_shadow_visual_size(shadow: CanvasItem) -> Vector2:
	if shadow is Sprite2D:
		var sprite := shadow as Sprite2D
		if sprite.texture != null:
			return sprite.texture.get_size() * sprite.scale.abs()
	if shadow is Polygon2D:
		var polygon := shadow as Polygon2D
		if not polygon.polygon.is_empty():
			var bounds := Rect2(polygon.polygon[0], Vector2.ZERO)
			for point in polygon.polygon:
				bounds = bounds.expand(point)
			return bounds.size * polygon.scale.abs()
	return Vector2(36.0, 18.0)

func _register_area_effect(area: Node2D) -> void:
	if area == null or _area_meshes.has(area.get_instance_id()):
		return
	var color: Color = area.get("visual_modulate") as Color
	if color.a <= 0.0:
		color = area.get("debug_fill_color") as Color
	color.a = maxf(color.a, 0.18)
	var mesh := _create_disc_mesh(color)
	_ground_root.add_child(mesh)
	var visual_root := area.get_node_or_null("VisualRoot") as CanvasItem
	if visual_root != null:
		visual_root.visible = false
	area.set("draw_enabled", false)
	_area_meshes[area.get_instance_id()] = {"source": weakref(area), "mesh": mesh}

func _register_warning_circle(warning: Node2D) -> void:
	if warning == null or _area_meshes.has(warning.get_instance_id()):
		return
	var color: Color = warning.get("fill_color") as Color
	color.a = maxf(color.a, 0.18)
	var mesh := _create_disc_mesh(color)
	_ground_root.add_child(mesh)
	warning.modulate.a = 0.0
	_area_meshes[warning.get_instance_id()] = {"source": weakref(warning), "mesh": mesh}

func _register_ground_segment(line: Line2D) -> void:
	if line == null or _segment_meshes.has(line.get_instance_id()):
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = line.default_color
	box.material = material
	mesh.mesh = box
	_ground_root.add_child(mesh)
	line.modulate.a = 0.0
	_segment_meshes[line.get_instance_id()] = {"source": weakref(line), "mesh": mesh, "box": box, "material": material}

func _create_disc_mesh(color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 0.008
	cylinder.radial_segments = 48
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cylinder.material = material
	mesh.mesh = cylinder
	return mesh

func _setup_rest_area_ground() -> void:
	if _ground_root == null or not is_instance_valid(_ground_root):
		return
	if not _rest_zone_meshes.is_empty():
		return
	var nodes := get_tree().get_nodes_in_group(&"rest_area")
	if nodes.is_empty():
		return
	_rest_area = nodes[0] as Node2D
	if _rest_area == null:
		return
	var texture_root := _rest_area.get_node_or_null("Texture") as CanvasItem
	if texture_root != null:
		texture_root.visible = false
	_create_rest_ground_mesh()
	var zone_visuals := _rest_area.get_node_or_null("ZoneVisuals") as CanvasItem
	if zone_visuals != null:
		zone_visuals.set_meta("hybrid_ground_active", true)
		zone_visuals.call_deferred("_ensure_hybrid_props")
	var zone_colors := {
		0: Color(1.0, 0.76, 0.22, 0.20),
		1: Color(1.0, 0.38, 0.18, 0.20),
		2: Color(0.38, 0.68, 1.0, 0.20),
		4: Color(0.42, 1.0, 0.48, 0.24),
		6: Color(0.34, 1.0, 0.78, 0.20),
	}
	for zone_id in zone_colors:
		var mesh := _create_disc_mesh(zone_colors[zone_id] as Color)
		_ground_root.add_child(mesh)
		_rest_zone_meshes[zone_id] = mesh

func _create_rest_ground_mesh() -> void:
	if _rest_area == null or _ground_root == null:
		return
	var sprite := _rest_area.get_node_or_null("Texture/Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	var texture_size := sprite.texture.get_size() * sprite.global_scale.abs()
	quad.size = texture_size * world_scale
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = sprite.texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	_rest_ground_mesh = MeshInstance3D.new()
	_rest_ground_mesh.name = "RestAreaGround"
	_rest_ground_mesh.mesh = quad
	_ground_root.add_child(_rest_ground_mesh)
	_rest_ground_material = material
	_rest_ground_sprite = weakref(sprite)
	_sync_rest_ground_mesh()

func _sync_rest_ground_mesh() -> void:
	if _rest_area == null or not is_instance_valid(_rest_area):
		return
	if _rest_ground_mesh == null or not is_instance_valid(_rest_ground_mesh):
		return
	var sprite := _rest_ground_sprite.get_ref() as Sprite2D if _rest_ground_sprite != null else null
	if sprite == null or not is_instance_valid(sprite):
		return
	_rest_ground_mesh.position = world_2d_to_3d(sprite.global_position)
	var rest_visible := _rest_area.visible and float(_rest_area.modulate.a) > 0.001
	_rest_ground_mesh.visible = rest_visible
	if _rest_ground_material != null:
		_rest_ground_material.albedo_color.a = clampf(float(_rest_area.modulate.a), 0.0, 1.0)

func _sync_rest_zone_meshes() -> void:
	if _rest_area == null or not is_instance_valid(_rest_area) or not _rest_area.is_inside_tree():
		_rest_area = null
		_rest_zone_meshes.clear()
		return
	var selected := int(_rest_area.get("selected_zone_id"))
	var hovered := int(_rest_area.get("hover_zone_id"))
	var rest_visible := _rest_area.visible and float(_rest_area.modulate.a) > 0.001
	for zone_id in _rest_zone_meshes.keys():
		var mesh_variant: Variant = _rest_zone_meshes.get(zone_id)
		if not is_instance_valid(mesh_variant):
			_rest_zone_meshes.erase(zone_id)
			continue
		var mesh := mesh_variant as MeshInstance3D
		if mesh == null or not mesh.is_inside_tree():
			_rest_zone_meshes.erase(zone_id)
			continue
		mesh.visible = rest_visible
		var rect := _rest_area.call("_get_zone_rect_local", zone_id) as Rect2
		var center_global := _rest_area.global_transform * rect.get_center()
		mesh.position = world_2d_to_3d(center_global) + Vector3.UP * 0.026
		var radius := minf(rect.size.x, rect.size.y) * (0.30 if int(zone_id) == 4 else 0.24) * world_scale
		var emphasis := 1.16 if int(zone_id) == hovered or int(zone_id) == selected else 1.0
		mesh.scale = Vector3(radius * emphasis, 1.0, radius * emphasis)

func _sync_runtime_overlays() -> void:
	_sync_shadow_meshes()
	_sync_area_meshes()
	_sync_segment_meshes()

func _sync_shadow_meshes() -> void:
	for id in _shadow_meshes.keys():
		var entry := _shadow_meshes[id] as Dictionary
		var source := (entry.source as WeakRef).get_ref() as CanvasItem
		var owner_2d := (entry.owner as WeakRef).get_ref() as Node2D
		var mesh := entry.mesh as MeshInstance3D
		if source == null or owner_2d == null or mesh == null:
			if mesh != null:
				mesh.queue_free()
			_shadow_meshes.erase(id)
			continue
		var local_anchor := entry.get("local_anchor", Vector2.ZERO) as Vector2
		var size_2d := entry.get("size_2d", Vector2(36.0, 18.0)) as Vector2
		var logical_anchor := owner_2d.global_transform * local_anchor
		mesh.position = world_2d_to_3d(logical_anchor) + Vector3.UP * 0.018
		mesh.scale = Vector3(size_2d.x * 0.5 * world_scale, 1.0, size_2d.y * 0.5 * world_scale)

func _sync_area_meshes() -> void:
	for id in _area_meshes.keys():
		var entry := _area_meshes[id] as Dictionary
		var area := (entry.source as WeakRef).get_ref() as Node2D
		var mesh := entry.mesh as MeshInstance3D
		if area == null or mesh == null:
			if mesh != null:
				mesh.queue_free()
			_area_meshes.erase(id)
			continue
		var radius := maxf(float(area.get("radius")), 1.0) * world_scale
		mesh.position = world_2d_to_3d(area.global_position) + Vector3.UP * 0.022
		mesh.scale = Vector3(radius, 1.0, radius)

func _sync_segment_meshes() -> void:
	for id in _segment_meshes.keys():
		var entry := _segment_meshes[id] as Dictionary
		var line := (entry.source as WeakRef).get_ref() as Line2D
		var mesh := entry.mesh as MeshInstance3D
		var box := entry.box as BoxMesh
		var material := entry.material as StandardMaterial3D
		if line == null or mesh == null:
			if mesh != null:
				mesh.queue_free()
			_segment_meshes.erase(id)
			continue
		var logical_visible := bool(line.get_meta("hybrid_ground_visible", false))
		mesh.visible = logical_visible and line.points.size() >= 2
		if not mesh.visible:
			continue
		var parent_2d := line.get_parent() as Node2D
		if parent_2d == null:
			continue
		var start := parent_2d.global_transform * line.points[0]
		var end := parent_2d.global_transform * line.points[line.points.size() - 1]
		var delta := end - start
		var midpoint := (start + end) * 0.5
		box.size = Vector3(maxf(delta.length() * world_scale, 0.01), 0.008, maxf(line.width * world_scale, 0.01))
		mesh.position = world_2d_to_3d(midpoint) + Vector3.UP * 0.024
		mesh.rotation.y = -delta.angle()
		material.albedo_color = line.default_color
