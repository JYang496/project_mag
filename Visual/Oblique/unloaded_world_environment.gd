class_name UnloadedWorldEnvironment
extends Node3D

## A single, camera-following background texture for the unloaded world.
## The camera-facing quad is visual-only and never creates collision or navigation.

const BACKGROUND_TEXTURE := preload(
	"res://Visual/Oblique/assets/background_variants/unloaded_world_quarantine_sector_vertical.png"
)

@export var hybrid_view_path: NodePath = NodePath("../HybridGroundView3D")
@export var world_scale: float = 0.01
@export_range(10.0, 100.0, 1.0) var backdrop_distance: float = 30.0
@export_range(1.0, 1.2, 0.005) var viewport_overscan: float = 1.025
@export_range(0.5, 0.98, 0.01) var visible_texture_fraction: float = 0.88
@export var parallax_uv_per_2d_unit := Vector2(0.00004, 0.000025)
@export var maximum_uv_offset := Vector2(0.045, 0.035)
@export_range(0.1, 20.0, 0.1) var parallax_smoothing: float = 6.0
@export_range(0.0, 2.0, 0.05) var anchor_settle_duration: float = 0.35
@export var background_tint := Color(0.78, 0.84, 0.90, 1.0)

var _hybrid_view: Node3D
var _camera: Camera3D
var _background_mesh: MeshInstance3D
var _background_quad: QuadMesh
var _background_material: StandardMaterial3D
var _camera_anchor_2d := Vector2.ZERO
var _smoothed_uv_offset := Vector2.ZERO
var _cover_scale := Vector2.ONE
var _anchor_settle_remaining := 0.0
var _last_viewport_size := Vector2.ZERO
var _last_camera_fov := -1.0


func _ready() -> void:
	process_priority = -90
	call_deferred("_build_backdrop")


func _process(delta: float) -> void:
	if _camera == null or _background_material == null:
		return
	_update_backdrop_geometry_if_needed()
	var camera_position_2d := _camera_world_position_2d()
	if _anchor_settle_remaining > 0.0:
		_anchor_settle_remaining = maxf(_anchor_settle_remaining - maxf(delta, 0.0), 0.0)
		_camera_anchor_2d = camera_position_2d
		_smoothed_uv_offset = Vector2.ZERO
		_apply_uv_offset(Vector2.ZERO)
		return
	var desired_offset := (camera_position_2d - _camera_anchor_2d) * parallax_uv_per_2d_unit
	desired_offset = _clamp_uv_offset_to_crop_margin(desired_offset)
	var smoothing_weight := 1.0 - exp(-maxf(parallax_smoothing, 0.1) * maxf(delta, 0.0))
	_smoothed_uv_offset = _smoothed_uv_offset.lerp(desired_offset, smoothing_weight)
	_apply_uv_offset(_snap_uv_offset_to_texture_grid(_smoothed_uv_offset))


func _build_backdrop() -> void:
	_hybrid_view = get_node_or_null(hybrid_view_path) as Node3D
	if _hybrid_view == null:
		push_warning("UnloadedWorldEnvironment could not resolve HybridGroundView3D.")
		return
	_camera = _hybrid_view.get_node_or_null("GroundCamera3D") as Camera3D
	if _camera == null:
		push_warning("UnloadedWorldEnvironment could not resolve GroundCamera3D.")
		return
	_background_mesh = MeshInstance3D.new()
	_background_mesh.name = "CameraFollowingBackdrop"
	_background_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_background_mesh.set_meta(&"non_playable_background", true)
	_background_mesh.position = Vector3(0.0, 0.0, -backdrop_distance)
	_background_quad = QuadMesh.new()
	_background_quad.orientation = PlaneMesh.FACE_Z
	_background_material = _create_background_material()
	_background_quad.material = _background_material
	_background_mesh.mesh = _background_quad
	_camera.add_child(_background_mesh)
	_anchor_settle_remaining = anchor_settle_duration
	_camera_anchor_2d = _camera_world_position_2d()
	_update_backdrop_geometry(true)
	_attach_camera_environment()


func _create_background_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = BACKGROUND_TEXTURE
	material.albedo_color = background_tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.texture_repeat = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material


func _update_backdrop_geometry_if_needed() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _last_viewport_size or not is_equal_approx(_camera.fov, _last_camera_fov):
		_update_backdrop_geometry(true)


func _update_backdrop_geometry(force: bool = false) -> void:
	if _camera == null or _background_quad == null or _background_material == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	if not force and viewport_size == _last_viewport_size and is_equal_approx(_camera.fov, _last_camera_fov):
		return
	_last_viewport_size = viewport_size
	_last_camera_fov = _camera.fov
	var viewport_aspect := viewport_size.x / viewport_size.y
	var visible_height := 2.0 * backdrop_distance * tan(deg_to_rad(_camera.fov) * 0.5)
	_background_quad.size = Vector2(
		visible_height * viewport_aspect,
		visible_height
	) * viewport_overscan
	_cover_scale = _calculate_cover_scale(viewport_aspect)
	_background_material.uv1_scale = Vector3(_cover_scale.x, _cover_scale.y, 1.0)
	_apply_uv_offset(_snap_uv_offset_to_texture_grid(_smoothed_uv_offset))


func _calculate_cover_scale(viewport_aspect: float) -> Vector2:
	var texture_size := Vector2(BACKGROUND_TEXTURE.get_size())
	var texture_aspect := texture_size.x / maxf(texture_size.y, 1.0)
	var fraction := clampf(visible_texture_fraction, 0.5, 0.98)
	if viewport_aspect >= texture_aspect:
		return Vector2(fraction, fraction * texture_aspect / viewport_aspect)
	return Vector2(fraction * viewport_aspect / texture_aspect, fraction)


func _apply_uv_offset(parallax_offset: Vector2) -> void:
	if _background_material == null:
		return
	var centered_crop_offset := (Vector2.ONE - _cover_scale) * 0.5
	var final_offset := centered_crop_offset + _clamp_uv_offset_to_crop_margin(parallax_offset)
	_background_material.uv1_offset = Vector3(final_offset.x, final_offset.y, 0.0)


func _clamp_uv_offset_to_crop_margin(offset: Vector2) -> Vector2:
	var crop_margin := (Vector2.ONE - _cover_scale) * 0.5
	var safe_maximum := Vector2(
		minf(maximum_uv_offset.x, maxf(crop_margin.x, 0.0)),
		minf(maximum_uv_offset.y, maxf(crop_margin.y, 0.0))
	)
	return Vector2(
		clampf(offset.x, -safe_maximum.x, safe_maximum.x),
		clampf(offset.y, -safe_maximum.y, safe_maximum.y)
	)


func _snap_uv_offset_to_texture_grid(offset: Vector2) -> Vector2:
	var texture_size := Vector2(BACKGROUND_TEXTURE.get_size())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return offset
	return Vector2(
		roundf(offset.x * texture_size.x) / texture_size.x,
		roundf(offset.y * texture_size.y) / texture_size.y
	)


func _camera_world_position_2d() -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	var safe_world_scale := maxf(world_scale, 0.0001)
	return Vector2(_camera.global_position.x, _camera.global_position.z) / safe_world_scale


func _attach_camera_environment() -> void:
	if _camera == null or _camera.environment != null:
		return
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.006, 0.012, 0.025, 1.0)
	environment.background_energy_multiplier = 0.65
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.08, 0.16, 0.24, 1.0)
	environment.ambient_light_energy = 0.25
	_camera.environment = environment


func _exit_tree() -> void:
	if _background_mesh != null and is_instance_valid(_background_mesh):
		if _background_mesh.get_parent() != null:
			_background_mesh.get_parent().remove_child(_background_mesh)
		_background_mesh.queue_free()
	_background_mesh = null
	_background_quad = null
	_background_material = null
	_camera = null
	_hybrid_view = null
