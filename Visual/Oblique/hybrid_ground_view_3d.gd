class_name HybridGroundView3D
extends Node3D

const HybridCameraDefaultsType := preload("res://Visual/Oblique/hybrid_camera_defaults.gd")
const HybridGroundLateSyncType := preload("res://Visual/Oblique/hybrid_ground_late_sync.gd")
const GroundMeshRegistryType := preload("res://Visual/Oblique/ground_mesh_registry.gd")
const BoardGroundRendererType := preload("res://Visual/Oblique/board_ground_renderer.gd")
const ConnectedEffectRendererType := preload("res://Visual/Oblique/connected_effect_renderer.gd")
const AuraRendererType := preload("res://Visual/Oblique/aura_renderer.gd")
const AreaEffectRendererType := preload("res://Visual/Oblique/area_effect_renderer.gd")
const RestAreaZoneGroundShader := preload("res://Shaders/rest_area_zone_ground.gdshader")
const LayeredAreaGroundShader := preload("res://Shaders/layered_area_ground.gdshader")
const ACTIVATION_OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
	uniform vec4 outline_color : source_color;
	uniform float outline_alpha = 0.0;
	uniform float fill_alpha = 0.0;
	uniform float animation_time = 0.0;
void fragment() {
	vec2 edge_uv = min(UV, vec2(1.0) - UV);
	float edge = 1.0 - smoothstep(0.012, 0.035, min(edge_uv.x, edge_uv.y));
		float sweep = 0.68 + 0.32 * sin(animation_time * 2.4 + (UV.x + UV.y) * 10.0);
	vec2 corner_uv = min(UV, vec2(1.0) - UV);
	float corner_band = (1.0 - step(0.18, min(corner_uv.x, corner_uv.y))) * step(0.055, max(corner_uv.x, corner_uv.y));
	float circuit = corner_band * step(0.55, fract((UV.x + UV.y) * 18.0));
	float alpha = fill_alpha + max(edge * sweep, circuit * 0.72) * outline_alpha;
	ALBEDO = outline_color.rgb * (0.82 + sweep * 0.18);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
"""
@export var enabled: bool = true
const DEFAULT_CAMERA_FOV: float = 34.0
const DEFAULT_WORLD_SCALE: float = 0.01
const GROUND_AREA_HEIGHT: float = 0.022
const GROUND_AREA_RENDER_PRIORITY: int = 2
const DANGER_WARNING_HEIGHT: float = 0.032
const DANGER_WARNING_RENDER_PRIORITY: int = 20
const DANGER_PROGRESS_HEIGHT: float = 0.034
const DANGER_PROGRESS_RENDER_PRIORITY: int = 21

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
var _player_resolve_attempted: bool = false
var _activation_meshes: Dictionary = {}
var _cell_meshes: Dictionary = {}
var _shadow_meshes: Dictionary = {}
var _area_meshes: Dictionary = {}
var _segment_meshes: Dictionary = {}
var _enemy_aura_meshes: Dictionary = {}
var _enemy_link_sources: Dictionary = {}
var _enemy_link_meshes: Dictionary = {}
var _dash_telegraph_meshes: Dictionary = {}
var _ground_cone_meshes: Dictionary = {}
var _rest_zone_meshes: Dictionary = {}
var _rest_area: Node2D
var _rest_ground_mesh: MeshInstance3D
var _rest_ground_material: StandardMaterial3D
var _rest_ground_sprite: WeakRef
var _rest_zone_quad: QuadMesh
var _rest_zone_material: ShaderMaterial
var _activation_quad: QuadMesh
var _activation_material: ShaderMaterial
var _shader_animation_time := 0.0
var _border_material: StandardMaterial3D
var _border_meshes: Dictionary = {}
var _projection_ready: bool = false
var _board_visual_active: bool = true
var _late_sync: Node
var _mesh_registry: GroundMeshRegistry
var _board_renderer: BoardGroundRenderer
var _connected_renderer: ConnectedEffectRenderer
var _aura_renderer: AuraRenderer
var _area_renderer: AreaEffectRenderer
var _ground_renderers_initialized: bool = false
var _view_multiplier: float = 1.0
var _view_multiplier_tween: Tween
var _screen_shake_offset := Vector2.ZERO

func _ready() -> void:
	LoadingPerformance.begin_segment("ground_ready")
	# Camera projection must be ready before BillboardVisual2D processes, while
	# ground attachments are synchronized by a separate late-process node.
	process_priority = -100
	add_to_group(&"hybrid_ground_view_3d")
	_camera = Camera3D.new()
	_camera.name = "GroundCamera3D"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.current = enabled
	add_child(_camera)
	_ground_root = Node3D.new()
	_ground_root.name = "GroundMeshes"
	add_child(_ground_root)
	_board_renderer = BoardGroundRendererType.new()
	_board_renderer.setup(self)
	_connected_renderer = ConnectedEffectRendererType.new()
	_connected_renderer.setup(self)
	_aura_renderer = AuraRendererType.new()
	_aura_renderer.setup(self)
	_area_renderer = AreaEffectRendererType.new()
	_area_renderer.setup(self)
	_mesh_registry = GroundMeshRegistryType.new()
	_mesh_registry.setup(self, _board_renderer, _connected_renderer, _aura_renderer, _area_renderer)
	_late_sync = HybridGroundLateSyncType.new()
	_late_sync.name = "LateGroundVisualSync"
	_late_sync.setup(self)
	add_child(_late_sync)
	_board = get_node_or_null(board_path) as Node2D
	_connect_board_signals()
	if _board != null:
		var active_value: Variant = _board.get("_board_active")
		if active_value != null:
			_board_visual_active = bool(active_value)
	_sync_camera_projection()
	call_deferred("_initialize_ground_renderers")
	LoadingPerformance.end_segment("ground_ready")

func _initialize_ground_renderers() -> void:
	LoadingPerformance.begin_segment("ground_initialize_renderers")
	if _board_renderer == null:
		LoadingPerformance.end_segment("ground_initialize_renderers")
		return
	LoadingPerformance.begin_segment("ground_rebuild")
	_board_renderer.rebuild()
	LoadingPerformance.end_segment("ground_rebuild")
	LoadingPerformance.begin_segment("ground_setup_rest_area")
	_board_renderer.setup_rest_area()
	LoadingPerformance.end_segment("ground_setup_rest_area")
	LoadingPerformance.begin_segment("ground_hide_legacy_boundaries")
	_board_renderer.hide_legacy_boundaries()
	LoadingPerformance.end_segment("ground_hide_legacy_boundaries")
	LoadingPerformance.begin_segment("ground_flush_pending_registrations")
	_ground_renderers_initialized = true
	_flush_pending_ground_registrations()
	LoadingPerformance.end_segment("ground_flush_pending_registrations")
	LoadingPerformance.end_segment("ground_initialize_renderers")

func _process(delta: float) -> void:
	if not enabled or _camera == null:
		return
	_shader_animation_time += maxf(delta, 0.0)
	if _rest_zone_material != null:
		_rest_zone_material.set_shader_parameter("animation_time", _shader_animation_time)
	if _activation_material != null:
		_activation_material.set_shader_parameter("animation_time", _shader_animation_time)
	if _ground_renderers_initialized and HybridGroundRegistration.pending_count() > 0:
		HybridGroundRegistration.flush_pending(self)
	_resolve_player()
	_sync_camera_projection()

func _sync_camera_projection() -> void:
	var target_2d := _resolve_camera_target_2d()
	var target_3d := world_2d_to_3d(target_2d)
	var pitch := deg_to_rad(camera_pitch_degrees)
	var yaw := deg_to_rad(camera_yaw_degrees)
	var effective_distance := camera_distance * _view_multiplier
	var horizontal_distance := effective_distance * cos(pitch)
	var height := effective_distance * sin(pitch)
	var backward := Vector3(sin(yaw), 0.0, cos(yaw)) * horizontal_distance
	_camera.position = target_3d + backward + Vector3.UP * height
	_camera.fov = camera_fov
	_apply_screen_shake_offset(effective_distance)
	_camera.look_at(target_3d, Vector3.UP)
	_projection_ready = true

func _resolve_camera_target_2d() -> Vector2:
	if PhaseManager != null and PhaseManager.current_state() == PhaseManager.PREPARE:
		return _resolve_rest_area_center()
	return _player.global_position if _player != null else Vector2.ZERO

func _resolve_rest_area_center() -> Vector2:
	if _rest_area == null or not is_instance_valid(_rest_area) or not _rest_area.is_inside_tree():
		var rest_areas: Array[Node] = get_tree().get_nodes_in_group(&"rest_area")
		_rest_area = rest_areas[0] as Node2D if not rest_areas.is_empty() else null
	if _rest_area != null:
		if _rest_area.has_method("get_spawn_position"):
			return _rest_area.call("get_spawn_position") as Vector2
		return _rest_area.global_position
	if _board != null and _board.has_method("get_rest_area_target_center_global_position"):
		return _board.call("get_rest_area_target_center_global_position") as Vector2
	return _player.global_position if _player != null else Vector2.ZERO

func sync_late_visuals(_delta: float) -> void:
	if not enabled or _camera == null:
		return
	if _mesh_registry != null:
		_mesh_registry.sync_late(_delta)

func configure(pitch: float, yaw: float, distance: float) -> void:
	camera_pitch_degrees = clampf(pitch, 25.0, 75.0)
	camera_yaw_degrees = clampf(yaw, -20.0, 20.0)
	camera_distance = clampf(distance, 5.0, 40.0)

func set_view_multiplier(multiplier: float, duration: float = 0.0) -> void:
	var target := clampf(multiplier, 0.05, 4.0)
	if _view_multiplier_tween != null:
		_view_multiplier_tween.kill()
		_view_multiplier_tween = null
	if duration <= 0.0 or not is_inside_tree():
		_view_multiplier = target
		return
	_view_multiplier_tween = create_tween()
	_view_multiplier_tween.set_trans(Tween.TRANS_SINE)
	_view_multiplier_tween.set_ease(Tween.EASE_OUT)
	_view_multiplier_tween.tween_property(self, "_view_multiplier", target, maxf(duration, 0.01))
	_view_multiplier_tween.finished.connect(_on_view_multiplier_tween_finished, CONNECT_ONE_SHOT)

func get_view_multiplier() -> float:
	return _view_multiplier

func set_screen_shake_offset(offset: Vector2) -> void:
	_screen_shake_offset = offset

func _apply_screen_shake_offset(effective_distance: float) -> void:
	if _camera == null:
		return
	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var visible_height := 2.0 * effective_distance * tan(deg_to_rad(camera_fov) * 0.5)
	var world_units_per_pixel := visible_height / viewport_height
	_camera.h_offset = _screen_shake_offset.x * world_units_per_pixel
	_camera.v_offset = -_screen_shake_offset.y * world_units_per_pixel

func _on_view_multiplier_tween_finished() -> void:
	_view_multiplier_tween = null

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
	if PlayerData.player != null and is_instance_valid(PlayerData.player):
		_player = PlayerData.player as Node2D
		return
	if _player_resolve_attempted:
		return
	_player_resolve_attempted = true
	var players := get_tree().get_nodes_in_group(&"player")
	if not players.is_empty():
		_player = players[0] as Node2D

func _flush_pending_ground_registrations() -> void:
	HybridGroundRegistration.flush_pending(self)

func _exit_tree() -> void:
	if _view_multiplier_tween != null:
		_view_multiplier_tween.kill()
		_view_multiplier_tween = null
	_projection_ready = false
	_player = null
	_rest_area = null
	_clear_ground_visual_caches()

func _rebuild_ground() -> void:
	if _ground_root == null or _board == null:
		return
	if _mesh_registry != null:
		_mesh_registry.clear()
	_clear_ground_visual_caches()
	for child in _ground_root.get_children():
		if not child.is_queued_for_deletion():
			_ground_root.remove_child(child)
			child.queue_free()
	if not enabled or not _board.has_method("get_cells"):
		return
	var cells: Array = _board.call("get_cells")
	for cell_index in range(cells.size()):
		var cell_variant: Variant = cells[cell_index]
		var cell := cell_variant as Node2D
		if cell == null:
			continue
		var texture_sprite := cell.get_node_or_null("Texture/Sprite2D") as Sprite2D
		if texture_sprite == null or texture_sprite.texture == null:
			continue
		var cell_segment := "ground_rebuild_cell_%d" % cell_index
		LoadingPerformance.begin_segment(cell_segment)
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
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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
		LoadingPerformance.end_segment(cell_segment)
	if _board_renderer != null:
		_board_renderer.setup_rest_area()
		_board_renderer.hide_legacy_boundaries()

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
	_enemy_aura_meshes.clear()
	_enemy_link_sources.clear()
	_enemy_link_meshes.clear()
	_dash_telegraph_meshes.clear()
	_ground_cone_meshes.clear()
	_rest_area = null

func _create_cell_border_meshes(cell: Node2D, center: Vector2, cell_size: Vector2) -> void:
	if _border_material == null:
		_border_material = StandardMaterial3D.new()
		_border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_border_material.albedo_color = cell_border_color
	var half_size := cell_size * 0.5
	var thickness := maxf(cell_border_width_2d, 1.0)
	_create_ground_border_strip("%sBorderTop" % cell.name, center + Vector2(0.0, -half_size.y), Vector2(cell_size.x, thickness))
	_create_ground_border_strip("%sBorderBottom" % cell.name, center + Vector2(0.0, half_size.y), Vector2(cell_size.x, thickness))
	_create_ground_border_strip("%sBorderLeft" % cell.name, center + Vector2(-half_size.x, 0.0), Vector2(thickness, cell_size.y))
	_create_ground_border_strip("%sBorderRight" % cell.name, center + Vector2(half_size.x, 0.0), Vector2(thickness, cell_size.y))

func _create_ground_border_strip(strip_name: String, center: Vector2, size_2d: Vector2) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = strip_name
	var box := _border_meshes.get(size_2d) as BoxMesh
	if box == null:
		box = BoxMesh.new()
		box.size = Vector3(size_2d.x * world_scale, 0.006, size_2d.y * world_scale)
		box.material = _border_material
		_border_meshes[size_2d] = box
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
	if _activation_quad == null:
		_activation_quad = QuadMesh.new()
		_activation_quad.orientation = PlaneMesh.FACE_Y
		_activation_quad.size = Vector2(512.0, 512.0) * world_scale * 0.96
		var shader := Shader.new()
		shader.code = ACTIVATION_OUTLINE_SHADER
		_activation_material = ShaderMaterial.new()
		_activation_material.shader = shader
		_activation_quad.material = _activation_material
	mesh.mesh = _activation_quad
	mesh.set_instance_shader_parameter("outline_color", Color(0.38, 0.88, 1.0, 1.0))
	mesh.set_instance_shader_parameter("outline_alpha", 0.0)
	mesh.set_instance_shader_parameter("fill_alpha", 0.0)
	mesh.set_meta(&"hybrid_board_visual", true)
	mesh.position = world_2d_to_3d(cell.global_position + Vector2(256.0, 256.0)) + Vector3.UP * 0.012
	_ground_root.add_child(mesh)
	_activation_meshes[cell.get_instance_id()] = {
		"source": weakref(activation),
		"cell": weakref(cell),
		"mesh": mesh,
	}

func _sync_activation_visuals() -> void:
	for entry_variant in _activation_meshes.values():
		var entry := entry_variant as Dictionary
		var source_ref := entry.source as WeakRef
		var activation := source_ref.get_ref() as Node
		var cell_ref := entry.cell as WeakRef
		var cell := cell_ref.get_ref() as Node2D
		var mesh := entry.mesh as MeshInstance3D
		if activation == null or cell == null or mesh == null:
			continue
		mesh.position = world_2d_to_3d(cell.global_position + Vector2(256.0, 256.0)) + Vector3.UP * 0.012
		var highlighted := float(activation.get("highlight_amount"))
		var active := bool(activation.get("_active"))
		var has_task := bool(activation.get("_has_task"))
		var alpha := 0.0
		var fill_alpha := 0.0
		var color := Color(0.38, 0.88, 1.0, 1.0)
		if highlighted > 0.001:
			alpha = (0.54 + highlighted * 0.32) * highlighted
		elif not active:
			color = Color(0.04, 0.09, 0.12, 1.0)
			alpha = 0.34
			fill_alpha = 0.12
		elif has_task:
			color = Color(1.0, 0.7, 0.2, 1.0)
			alpha = 0.18
		mesh.set_instance_shader_parameter("outline_color", color)
		mesh.set_instance_shader_parameter("outline_alpha", alpha)
		mesh.set_instance_shader_parameter("fill_alpha", fill_alpha)
		mesh.visible = _board_visual_active and bool(cell.get("board_enabled")) and (alpha > 0.001 or fill_alpha > 0.001)

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

func _register_shadow(shadow: CanvasItem) -> void:
	if shadow == null or _shadow_meshes.has(shadow.get_instance_id()):
		return
	var owner_2d := shadow.get_parent() as Node2D
	if owner_2d == null:
		return
	shadow.visible = false
	var mesh := _create_disc_mesh(Color(0.0, 0.0, 0.0, 0.20))
	mesh.visible = false
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
	shadow.set_meta(&"hybrid_ground_registered", true)

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
	if area == null or _area_meshes.has(area.get_instance_id()) or bool(area.get_meta(&"hybrid_animated_area_registered", false)):
		return
	var animated_ground := bool(area.get("animated_visual_is_ground"))
	if bool(area.get("visual_enabled")) and bool(area.get("use_animated_visual")) and not animated_ground:
		# Animated explosions are upright effects, not persistent ground ranges.
		# Keep their Billboard visual and suppress only the legacy debug circle.
		area.set("draw_enabled", false)
		area.set_meta(&"hybrid_animated_area_registered", true)
		return
	var color: Color = area.get("visual_modulate") as Color
	if color.a <= 0.0:
		color = area.get("debug_fill_color") as Color
	color.a = maxf(color.a, 0.18)
	var visual_shape := int(area.get("visual_shape"))
	var render_priority := GROUND_AREA_RENDER_PRIORITY
	var mesh := _create_disc_mesh(color, render_priority) if visual_shape == 0 else _create_polygon_ground_mesh(_build_area_polygon_points(area), color, render_priority)
	_ground_root.add_child(mesh)
	var visual_root := area.get_node_or_null("VisualRoot") as CanvasItem
	if visual_root != null:
		visual_root.visible = false
	area.set("draw_enabled", false)
	var material := mesh.mesh.surface_get_material(0) if mesh.mesh != null and mesh.mesh.get_surface_count() > 0 else null
	var detail_texture := area.get("ground_detail_texture") as Texture2D
	if detail_texture != null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		var layered_material := ShaderMaterial.new()
		layered_material.shader = LayeredAreaGroundShader
		layered_material.render_priority = render_priority
		layered_material.set_shader_parameter("base_texture", _get_area_ground_texture(area))
		layered_material.set_shader_parameter("detail_texture", detail_texture)
		layered_material.set_shader_parameter("base_color", color)
		layered_material.set_shader_parameter("detail_color", area.get("ground_detail_color") as Color)
		layered_material.set_shader_parameter("detail_scale", area.get("ground_detail_scale") as Vector2)
		layered_material.set_shader_parameter("flow_speed", area.get("ground_flow_speed") as Vector2)
		layered_material.set_shader_parameter("distortion", float(area.get("ground_uv_distortion")))
		mesh.mesh.surface_set_material(0, layered_material)
		material = layered_material
	_area_meshes[area.get_instance_id()] = {
		"source": weakref(area),
		"mesh": mesh,
		"visual_shape": visual_shape,
		"material": material,
		"animated_ground": animated_ground,
		"height": GROUND_AREA_HEIGHT,
	}
	area.set_meta(&"hybrid_ground_registered", true)

func _get_area_ground_texture(area: Node2D) -> Texture2D:
	if bool(area.get("use_animated_visual")):
		var animated_sprite := area.get_node_or_null("VisualRoot/AnimatedSprite") as AnimatedSprite2D
		if animated_sprite != null and animated_sprite.sprite_frames != null:
			return animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	return area.get("visual_texture") as Texture2D

func register_area_effect(area: Node2D) -> void:
	if _area_renderer != null:
		_area_renderer.register_area_effect(area)

func register_shadow(shadow: CanvasItem) -> void:
	if _area_renderer != null:
		_area_renderer.register_shadow(shadow)

func _register_enemy_support_visual(source: Node2D) -> void:
	if source == null:
		return
	var source_id := source.get_instance_id()
	if source.has_method("get_hybrid_aura_visual") and not _enemy_aura_meshes.has(source_id):
		var config := source.call("get_hybrid_aura_visual") as Dictionary
		var fill_color := config.get("fill_color", Color(0.2, 0.8, 1.0, 0.14)) as Color
		var line_color := config.get("line_color", Color(0.4, 0.9, 1.0, 0.8)) as Color
		var outline := _create_ring_mesh(line_color)
		var fill := _create_disc_mesh(fill_color)
		_ground_root.add_child(outline)
		_ground_root.add_child(fill)
		_enemy_aura_meshes[source_id] = {
			"source": weakref(source),
			"outline": outline,
			"fill": fill,
			"outline_mesh": outline.mesh,
			"outline_material": outline.mesh.material,
			"fill_material": fill.mesh.material,
		}
	if source.has_method("get_hybrid_link_visuals"):
		_enemy_link_sources[source_id] = weakref(source)
	source.set_meta(&"hybrid_ground_registered", true)

func register_enemy_support_visual(source: Node2D) -> void:
	if _aura_renderer != null:
		_aura_renderer.register_source(source)

func _register_dash_telegraph(source: Node2D) -> void:
	if source == null or _dash_telegraph_meshes.has(source.get_instance_id()):
		return
	var warning_mesh := MeshInstance3D.new()
	var warning_box := BoxMesh.new()
	var warning_material := StandardMaterial3D.new()
	warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_material.render_priority = DANGER_WARNING_RENDER_PRIORITY
	warning_box.material = warning_material
	warning_mesh.mesh = warning_box
	warning_mesh.visible = false
	_ground_root.add_child(warning_mesh)
	var progress_mesh := MeshInstance3D.new()
	var progress_box := BoxMesh.new()
	var progress_material := StandardMaterial3D.new()
	progress_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	progress_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	progress_material.render_priority = DANGER_PROGRESS_RENDER_PRIORITY
	progress_box.material = progress_material
	progress_mesh.mesh = progress_box
	progress_mesh.visible = false
	_ground_root.add_child(progress_mesh)
	_dash_telegraph_meshes[source.get_instance_id()] = {
		"source": weakref(source),
		"warning_mesh": warning_mesh,
		"warning_box": warning_box,
		"warning_material": warning_material,
		"progress_mesh": progress_mesh,
		"progress_box": progress_box,
		"progress_material": progress_material,
	}
	source.set_meta(&"hybrid_ground_registered", true)

func register_dash_telegraph(source: Node2D) -> void:
	if _area_renderer != null:
		_area_renderer.register_dash_telegraph(source)

func _register_ground_cone_effect(source: Node2D) -> void:
	if source == null or _ground_cone_meshes.has(source.get_instance_id()):
		return
	var mesh := _mesh_registry.acquire_mesh(&"ground_cone", _connected_renderer.get_cone_mesh(deg_to_rad(30.0)))
	mesh.visible = false
	_ground_cone_meshes[source.get_instance_id()] = {
		"source": weakref(source),
		"mesh": mesh,
		"material": _connected_renderer.shared_cone_material,
	}
	source.set_meta(&"hybrid_ground_registered", true)

func _register_warning_circle(warning: Node2D) -> void:
	if warning == null or _area_meshes.has(warning.get_instance_id()):
		return
	var color: Color = warning.get("fill_color") as Color
	color.a = maxf(color.a, 0.18)
	var mesh := _create_disc_mesh(color, DANGER_WARNING_RENDER_PRIORITY)
	_ground_root.add_child(mesh)
	warning.modulate.a = 0.0
	_area_meshes[warning.get_instance_id()] = {
		"source": weakref(warning),
		"mesh": mesh,
		"height": DANGER_WARNING_HEIGHT,
	}
	warning.set_meta(&"hybrid_ground_registered", true)

func _register_ground_segment(line: Line2D) -> void:
	if line == null or _segment_meshes.has(line.get_instance_id()):
		return
	var style := line.get_meta("hybrid_segment_style", &"plain") as StringName
	var primitive: PrimitiveMesh
	var material: Material
	if style == &"beam":
		primitive = _connected_renderer.shared_beam_mesh
		material = _connected_renderer.shared_beam_material
	else:
		primitive = _connected_renderer.shared_box_mesh
		material = _connected_renderer.shared_box_material
	var pool_key: StringName = &"beam" if style == &"beam" else &"connected_segment"
	var mesh := _mesh_registry.acquire_mesh(pool_key, primitive)
	line.visible = false
	var start_glow: MeshInstance3D
	var end_glow: MeshInstance3D
	if style == &"beam" and bool(line.get_meta("hybrid_segment_endpoints", false)):
		start_glow = _create_disc_mesh(line.default_color)
		end_glow = _create_disc_mesh(line.default_color)
		start_glow.visible = false
		end_glow.visible = false
		_ground_root.add_child(start_glow)
		_ground_root.add_child(end_glow)
	_segment_meshes[line.get_instance_id()] = {
		"source": weakref(line),
		"mesh": mesh,
		"primitive": primitive,
		"material": material,
		"style": style,
		"start_glow": start_glow,
		"end_glow": end_glow,
		"pool_key": pool_key,
	}
	line.set_meta(&"hybrid_ground_registered", true)

func register_ground_segment(line: Line2D) -> void:
	if _connected_renderer != null:
		_connected_renderer.register_segment(line)

func register_ground_cone_effect(source: Node2D) -> void:
	if _connected_renderer != null:
		_connected_renderer.register_cone(source)

func register_warning_circle(source: Node2D) -> void:
	if _area_renderer != null:
		_area_renderer.register_warning_circle(source)

func unregister_ground_visual(source: Node) -> void:
	if source == null:
		return
	var source_id := source.get_instance_id()
	source.set_meta(&"hybrid_ground_registered", false)
	_erase_visual_entry(_shadow_meshes, source_id)
	_erase_visual_entry(_area_meshes, source_id)
	_erase_visual_entry(_segment_meshes, source_id)
	_erase_visual_entry(_dash_telegraph_meshes, source_id)
	_erase_visual_entry(_ground_cone_meshes, source_id)
	_erase_visual_entry(_enemy_aura_meshes, source_id)
	_enemy_link_sources.erase(source_id)
	var link_prefix := "%d:" % source_id
	for key in _enemy_link_meshes.keys():
		if str(key).begins_with(link_prefix):
			_erase_visual_entry(_enemy_link_meshes, key)

func _erase_visual_entry(cache: Dictionary, key: Variant) -> void:
	if not cache.has(key):
		return
	var entry_variant: Variant = cache.get(key)
	if entry_variant is Dictionary:
		var entry := entry_variant as Dictionary
		for value in entry.values():
			if value is MeshInstance3D and is_instance_valid(value):
				var mesh := value as MeshInstance3D
				if mesh.has_meta(&"hybrid_pool_key") and _mesh_registry != null:
					_mesh_registry.release_mesh(mesh)
				else:
					mesh.queue_free()
	cache.erase(key)

func _create_disc_mesh(color: Color, render_priority: int = 0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 0.008
	cylinder.radial_segments = 48
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = render_priority
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cylinder.material = material
	mesh.mesh = cylinder
	return mesh

func _create_ring_mesh(color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.rings = 64
	torus.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	torus.material = material
	mesh.mesh = torus
	return mesh

func _create_polygon_ground_mesh(points: PackedVector2Array, color: Color, render_priority: int = 0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = render_priority
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.mesh = _build_ground_polygon_array_mesh(points, material)
	return mesh_instance

func _build_ground_polygon_array_mesh(points: PackedVector2Array, material: Material) -> ArrayMesh:
	var array_mesh := ArrayMesh.new()
	if points.size() < 3:
		return array_mesh
	var vertices := PackedVector3Array()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var safe_size := Vector2(maxf(bounds.size.x, 0.001), maxf(bounds.size.y, 0.001))
	var uvs := PackedVector2Array()
	for point in points:
		vertices.append(Vector3(point.x * world_scale, 0.0, point.y * world_scale))
		uvs.append((point - bounds.position) / safe_size)
	var indices := PackedInt32Array()
	for index in range(1, points.size() - 1):
		indices.append(0)
		indices.append(index)
		indices.append(index + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	array_mesh.surface_set_material(0, material)
	return array_mesh

func _build_area_polygon_points(area: Node2D) -> PackedVector2Array:
	var visual_shape := int(area.get("visual_shape"))
	if visual_shape == 1:
		var size := area.get("rectangle_size") as Vector2
		var half := size * 0.5
		return PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	var direction := area.get("cone_direction") as Vector2
	direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	var half_angle := deg_to_rad(float(area.get("cone_half_angle_deg")))
	var cone_range_value := maxf(float(area.get("cone_range")), 1.0)
	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(17):
		var ratio := float(index) / 16.0
		points.append(direction.rotated(lerpf(-half_angle, half_angle, ratio)) * cone_range_value)
	return points

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
	_rest_zone_quad = QuadMesh.new()
	_rest_zone_quad.orientation = PlaneMesh.FACE_Y
	_rest_zone_quad.size = Vector2.ONE
	_rest_zone_material = ShaderMaterial.new()
	_rest_zone_material.shader = RestAreaZoneGroundShader
	_rest_zone_material.render_priority = 3
	_rest_zone_quad.material = _rest_zone_material
	for zone_id in zone_colors:
		var mesh := MeshInstance3D.new()
		mesh.mesh = _rest_zone_quad
		mesh.set_instance_shader_parameter("zone_color", zone_colors[zone_id] as Color)
		mesh.visible = false
		_ground_root.add_child(mesh)
		_rest_zone_meshes[zone_id] = {
			"mesh": mesh,
			"color": zone_colors[zone_id],
		}

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
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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
		var entry_variant: Variant = _rest_zone_meshes.get(zone_id)
		if not entry_variant is Dictionary:
			_rest_zone_meshes.erase(zone_id)
			continue
		var entry := entry_variant as Dictionary
		var mesh := entry.get("mesh") as MeshInstance3D
		if mesh == null or not mesh.is_inside_tree():
			_rest_zone_meshes.erase(zone_id)
			continue
		mesh.visible = rest_visible
		var rect := _rest_area.call("_get_zone_rect_local", zone_id) as Rect2
		var center_global := _rest_area.global_transform * rect.get_center()
		mesh.position = world_2d_to_3d(center_global) + Vector3.UP * 0.026
		var radius := minf(rect.size.x, rect.size.y) * (0.30 if int(zone_id) == 4 else 0.24) * world_scale
		var emphasis := 1.12 if int(zone_id) == hovered or int(zone_id) == selected else 1.0
		var diameter := radius * 2.65 * emphasis
		mesh.scale = Vector3(diameter, 1.0, diameter)
		mesh.set_instance_shader_parameter("hovered", 1.0 if int(zone_id) == hovered else 0.0)
		mesh.set_instance_shader_parameter("selected", 1.0 if int(zone_id) == selected else 0.0)
		mesh.set_instance_shader_parameter("visibility_alpha", clampf(float(_rest_area.modulate.a), 0.0, 1.0))
		var hold_progress := 0.0
		if int(zone_id) == 4:
			var hold_duration := maxf(float(_rest_area.get("zone4_hold_duration")), 0.01)
			hold_progress = clampf(float(_rest_area.get("_zone4_hold_elapsed")) / hold_duration, 0.0, 1.0)
		mesh.set_instance_shader_parameter("hold_progress", hold_progress)

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
		mesh.visible = true

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
		var visual_shape := int(entry.get("visual_shape", 0))
		var radius := maxf(float(area.get("radius")), 1.0) * world_scale
		var height_offset_value: Variant = area.get("ground_height_offset")
		var height_offset := float(height_offset_value) if height_offset_value != null else 0.0
		var base_height := float(entry.get("height", GROUND_AREA_HEIGHT))
		mesh.position = world_2d_to_3d(area.global_position) + Vector3.UP * (base_height + height_offset)
		if visual_shape == 0:
			mesh.scale = Vector3(radius, 1.0, radius)
		else:
			var current_material := entry.get("material") as Material
			mesh.mesh = _build_ground_polygon_array_mesh(_build_area_polygon_points(area), current_material)
		if bool(entry.get("animated_ground", false)):
			_sync_animated_ground_area_texture(area, entry)

func _sync_animated_ground_area_texture(area: Node2D, entry: Dictionary) -> void:
	var shader_material := entry.get("material") as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("base_texture", _get_area_ground_texture(area))
		shader_material.set_shader_parameter("base_color", area.get("visual_modulate") as Color)
		return
	var material := entry.get("material") as StandardMaterial3D
	if material == null:
		return
	var animated_sprite := area.get_node_or_null("VisualRoot/AnimatedSprite") as AnimatedSprite2D
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var frame_texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	material.albedo_texture = frame_texture
	material.albedo_color = area.get("visual_modulate") as Color
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

func _sync_segment_meshes() -> void:
	for id in _segment_meshes.keys():
		var entry := _segment_meshes[id] as Dictionary
		var line := (entry.source as WeakRef).get_ref() as Line2D
		var mesh := entry.mesh as MeshInstance3D
		var primitive := entry.get("primitive") as PrimitiveMesh
		var material := entry.get("material") as Material
		var style := entry.get("style", &"plain") as StringName
		var start_glow := entry.get("start_glow") as MeshInstance3D
		var end_glow := entry.get("end_glow") as MeshInstance3D
		if line == null or mesh == null:
			if mesh != null:
				_mesh_registry.release_mesh(mesh)
			if start_glow != null:
				start_glow.queue_free()
			if end_glow != null:
				end_glow.queue_free()
			_segment_meshes.erase(id)
			continue
		var logical_visible := bool(line.get_meta("hybrid_ground_visible", false))
		mesh.visible = logical_visible and line.points.size() >= 2
		if start_glow != null:
			start_glow.visible = mesh.visible
		if end_glow != null:
			end_glow.visible = mesh.visible
		if not mesh.visible:
			continue
		var parent_2d := line.get_parent() as Node2D
		if parent_2d == null:
			continue
		var start := parent_2d.global_transform * line.points[0]
		var end := parent_2d.global_transform * line.points[line.points.size() - 1]
		var delta := end - start
		var midpoint := (start + end) * 0.5
		var length_3d := maxf(delta.length() * world_scale, 0.01)
		var width_3d := maxf(line.width * world_scale, 0.01)
		mesh.scale = Vector3(length_3d, 1.0, width_3d)
		mesh.position = world_2d_to_3d(midpoint) + Vector3.UP * 0.024
		mesh.rotation.y = -delta.angle()
		var segment_color := line.default_color
		segment_color.a *= line.modulate.a
		mesh.set_instance_shader_parameter("beam_color" if style == &"beam" else "effect_color", segment_color)
		if start_glow != null and end_glow != null:
			start_glow.position = world_2d_to_3d(start) + Vector3.UP * 0.026
			end_glow.position = world_2d_to_3d(end) + Vector3.UP * 0.026
			var glow_scale := maxf(width_3d * 0.8, 0.025)
			start_glow.scale = Vector3(glow_scale, 1.0, glow_scale)
			end_glow.scale = start_glow.scale
			var start_material := start_glow.mesh.material as StandardMaterial3D
			var end_material := end_glow.mesh.material as StandardMaterial3D
			var glow_color := segment_color.lightened(0.35)
			if start_material != null:
				start_material.albedo_color = glow_color
			if end_material != null:
				end_material.albedo_color = glow_color

func _sync_enemy_aura_meshes() -> void:
	for source_id in _enemy_aura_meshes.keys():
		var entry := _enemy_aura_meshes[source_id] as Dictionary
		var source_ref := entry.get("source") as WeakRef
		var source := source_ref.get_ref() as Node2D if source_ref != null else null
		var outline := entry.get("outline") as MeshInstance3D
		var fill := entry.get("fill") as MeshInstance3D
		if source == null or outline == null or fill == null:
			if outline != null:
				outline.queue_free()
			if fill != null:
				fill.queue_free()
			_enemy_aura_meshes.erase(source_id)
			continue
		var config := source.call("get_hybrid_aura_visual") as Dictionary
		var visible := bool(config.get("visible", true))
		var radius_2d := maxf(float(config.get("radius", 1.0)), 1.0)
		var line_width_2d := maxf(float(config.get("line_width", 2.0)), 0.5)
		var radius_3d := radius_2d * world_scale
		var inner_radius_3d := maxf((radius_2d - line_width_2d) * world_scale, 0.001)
		outline.visible = visible
		fill.visible = visible
		outline.position = world_2d_to_3d(source.global_position) + Vector3.UP * 0.020
		fill.position = world_2d_to_3d(source.global_position) + Vector3.UP * 0.021
		outline.scale = Vector3.ONE
		fill.scale = Vector3(inner_radius_3d, 1.0, inner_radius_3d)
		var outline_mesh := entry.get("outline_mesh") as TorusMesh
		if outline_mesh != null:
			outline_mesh.inner_radius = inner_radius_3d
			outline_mesh.outer_radius = radius_3d
		var outline_material := entry.get("outline_material") as StandardMaterial3D
		var fill_material := entry.get("fill_material") as StandardMaterial3D
		if outline_material != null:
			outline_material.albedo_color = config.get("line_color", outline_material.albedo_color) as Color
		if fill_material != null:
			fill_material.albedo_color = config.get("fill_color", fill_material.albedo_color) as Color

func _sync_enemy_link_meshes() -> void:
	var active_keys: Dictionary = {}
	for source_id in _enemy_link_sources.keys():
		var source_ref := _enemy_link_sources[source_id] as WeakRef
		var source := source_ref.get_ref() as Node2D if source_ref != null else null
		if source == null:
			_enemy_link_sources.erase(source_id)
			continue
		var links := source.call("get_hybrid_link_visuals") as Array
		for index in range(links.size()):
			var config := links[index] as Dictionary
			var target := config.get("target") as Node2D
			if target == null or not is_instance_valid(target):
				continue
			var key := "%d:%d:%d" % [source_id, target.get_instance_id(), index]
			active_keys[key] = true
			var entry: Dictionary
			if not _enemy_link_meshes.has(key):
				var mesh := _mesh_registry.acquire_mesh(&"connected_link", _connected_renderer.shared_box_mesh)
				entry = {"mesh": mesh, "pool_key": &"connected_link"}
				_enemy_link_meshes[key] = entry
			else:
				entry = _enemy_link_meshes[key] as Dictionary
			var mesh := entry.get("mesh") as MeshInstance3D
			var delta := target.global_position - source.global_position
			var midpoint := (source.global_position + target.global_position) * 0.5
			var width_2d := maxf(float(config.get("width", 2.0)), 0.5)
			mesh.scale = Vector3(maxf(delta.length() * world_scale, 0.01), 1.0, maxf(width_2d * world_scale, 0.01))
			mesh.position = world_2d_to_3d(midpoint) + Vector3.UP * 0.025
			mesh.rotation.y = -delta.angle()
			mesh.visible = bool(config.get("visible", true))
			mesh.set_instance_shader_parameter("effect_color", config.get("color", Color.WHITE) as Color)
	for key in _enemy_link_meshes.keys():
		if active_keys.has(key):
			continue
		var stale := _enemy_link_meshes[key] as Dictionary
		var stale_mesh := stale.get("mesh") as MeshInstance3D
		if stale_mesh != null:
			_mesh_registry.release_mesh(stale_mesh)
		_enemy_link_meshes.erase(key)

func _sync_dash_telegraph_meshes() -> void:
	for source_id in _dash_telegraph_meshes.keys():
		var entry := _dash_telegraph_meshes[source_id] as Dictionary
		var source_ref := entry.get("source") as WeakRef
		var source := source_ref.get_ref() as Node2D if source_ref != null else null
		var warning_mesh := entry.get("warning_mesh") as MeshInstance3D
		var progress_mesh := entry.get("progress_mesh") as MeshInstance3D
		if source == null or warning_mesh == null or progress_mesh == null:
			if warning_mesh != null:
				warning_mesh.queue_free()
			if progress_mesh != null:
				progress_mesh.queue_free()
			_dash_telegraph_meshes.erase(source_id)
			continue
		var config := source.call("get_hybrid_dash_telegraph_visual") as Dictionary
		var active := bool(config.get("active", false))
		warning_mesh.visible = active
		progress_mesh.visible = active and float(config.get("progress", 0.0)) > 0.001
		if not active:
			continue
		var origin := config.get("origin", source.global_position) as Vector2
		var direction := config.get("direction", Vector2.RIGHT) as Vector2
		direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
		var distance := maxf(float(config.get("distance", 0.0)), 0.0)
		var width := maxf(float(config.get("half_width", 1.0)) * 2.0, 1.0)
		var warning_box := entry.get("warning_box") as BoxMesh
		warning_box.size = Vector3(maxf(distance * world_scale, 0.01), 0.008, width * world_scale)
		warning_mesh.position = world_2d_to_3d(origin + direction * distance * 0.5) + Vector3.UP * DANGER_WARNING_HEIGHT
		warning_mesh.rotation.y = -direction.angle()
		var warning_material := entry.get("warning_material") as StandardMaterial3D
		warning_material.albedo_color = config.get("warning_color", Color(1.0, 0.1, 0.1, 0.28)) as Color
		var reach := distance * clampf(float(config.get("progress", 0.0)), 0.0, 1.0)
		var progress_box := entry.get("progress_box") as BoxMesh
		progress_box.size = Vector3(maxf(reach * world_scale, 0.01), 0.006, width * world_scale)
		progress_mesh.position = world_2d_to_3d(origin + direction * reach * 0.5) + Vector3.UP * DANGER_PROGRESS_HEIGHT
		progress_mesh.rotation.y = -direction.angle()
		var progress_material := entry.get("progress_material") as StandardMaterial3D
		progress_material.albedo_color = config.get("progress_color", Color(1.0, 0.15, 0.15, 0.95)) as Color

func _sync_ground_cone_meshes() -> void:
	for source_id in _ground_cone_meshes.keys():
		var entry := _ground_cone_meshes[source_id] as Dictionary
		var source_ref := entry.get("source") as WeakRef
		var source := source_ref.get_ref() as Node2D if source_ref != null else null
		var mesh := entry.get("mesh") as MeshInstance3D
		var material := entry.get("material") as ShaderMaterial
		if source == null or mesh == null:
			if mesh != null:
				_mesh_registry.release_mesh(mesh)
			_ground_cone_meshes.erase(source_id)
			continue
		var config := source.call("get_hybrid_ground_cone_visual") as Dictionary
		mesh.visible = bool(config.get("visible", false))
		if not mesh.visible:
			continue
		var origin := config.get("origin", source.global_position) as Vector2
		var direction := config.get("direction", Vector2.RIGHT) as Vector2
		direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
		var range_value := maxf(float(config.get("range", 1.0)), 1.0)
		var half_angle := deg_to_rad(float(config.get("half_angle_degrees", 30.0)))
		mesh.mesh = _connected_renderer.get_cone_mesh(half_angle)
		mesh.scale = Vector3(range_value, 1.0, range_value)
		mesh.position = world_2d_to_3d(origin) + Vector3.UP * 0.029
		mesh.rotation.y = -direction.angle()
		var color := config.get("color", Color(1.0, 0.3, 0.05, 0.75)) as Color
		mesh.set_instance_shader_parameter("flow_color", color)
		mesh.set_instance_shader_parameter("edge_color", Color(minf(color.r * 1.5 + 0.2, 1.0), minf(color.g * 1.35 + 0.15, 1.0), minf(color.b * 1.2 + 0.1, 1.0), minf(color.a * 1.2, 1.0)))

func _build_ground_cone_array_mesh(range_value: float, half_angle: float, material: Material) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3.ZERO])
	var uvs := PackedVector2Array([Vector2(0.0, 0.5)])
	for index in range(25):
		var ratio := float(index) / 24.0
		var point := Vector2.RIGHT.rotated(lerpf(-half_angle, half_angle, ratio)) * range_value
		vertices.append(Vector3(point.x * world_scale, 0.0, point.y * world_scale))
		uvs.append(Vector2(1.0, ratio))
	var indices := PackedInt32Array()
	for index in range(1, vertices.size() - 1):
		indices.append(0)
		indices.append(index)
		indices.append(index + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, material)
	return result
