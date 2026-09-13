class_name UnloadedWorldEnvironment
extends Node3D

## Three visual-only camera-facing planes, ordered from sky to nearby cities.
## Mid/near images carry alpha; no legacy circuit texture is superimposed.
const LAYER_TEXTURES: Array[Texture2D] = [
	preload("res://Visual/Oblique/assets/background_layers/abyss_far.png"),
	preload("res://Visual/Oblique/assets/background_layers/abyss_mid.png"),
	preload("res://Visual/Oblique/assets/background_layers/abyss_near.png"),
]
const LAYER_NAMES := [&"FarSkyCities", &"MiddleCities", &"NearCities"]

@export var hybrid_view_path: NodePath = NodePath("../HybridGroundView3D")
@export var world_scale: float = 0.01
# Camera-space depths: all remain behind the playable board.
@export var layer_distances := Vector3(180.0, 120.0, 80.0)
@export var layer_parallax_speeds := Vector3(0.18, 0.50, 1.0)
@export var layer_visible_fractions := Vector3(0.92, 0.88, 0.84)
@export_range(1.0, 1.2, 0.005) var viewport_overscan: float = 1.025
@export var parallax_uv_per_2d_unit := Vector2(0.00004, 0.000025)
@export_range(0.1, 20.0, 0.1) var parallax_smoothing: float = 6.0
@export_range(0.0, 2.0, 0.05) var anchor_settle_duration: float = 0.35
@export var background_tint := Color.WHITE

var _camera: Camera3D
var _layer_meshes: Array[MeshInstance3D] = []
var _layer_materials: Array[StandardMaterial3D] = []
var _cover_scales: Array[Vector2] = []
var _offsets: Array[Vector2] = []
var _camera_anchor_2d := Vector2.ZERO
var _anchor_settle_remaining := 0.0
var _last_viewport_size := Vector2.ZERO
var _last_camera_fov := -1.0
var _last_keep_aspect := -1


func _ready() -> void:
	process_priority = -90
	call_deferred("_build_backdrop")


func _build_backdrop() -> void:
	var hybrid_view := get_node_or_null(hybrid_view_path)
	if hybrid_view == null:
		push_warning("UnloadedWorldEnvironment could not resolve HybridGroundView3D.")
		return
	_camera = hybrid_view.get_node_or_null("GroundCamera3D") as Camera3D
	if _camera == null:
		push_warning("UnloadedWorldEnvironment could not resolve GroundCamera3D.")
		return
	for index in range(LAYER_TEXTURES.size()):
		var material := _create_layer_material(index)
		var quad := QuadMesh.new()
		quad.material = material
		var instance := MeshInstance3D.new()
		instance.name = LAYER_NAMES[index]
		instance.mesh = quad
		instance.position.z = -maxf(layer_distances[index], 1.0)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.set_meta(&"non_playable_background", true)
		_camera.add_child(instance)
		_layer_meshes.append(instance)
		_layer_materials.append(material)
		_cover_scales.append(Vector2.ONE)
		_offsets.append(Vector2.ZERO)
	_camera_anchor_2d = _camera_world_position_2d()
	_anchor_settle_remaining = anchor_settle_duration
	_update_geometry()
	_attach_camera_environment()


func _create_layer_material(index: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_fog = true
	material.albedo_texture = LAYER_TEXTURES[index]
	material.albedo_color = background_tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.texture_repeat = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if index > 0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.render_priority = -100 + index
	return material


func _process(delta: float) -> void:
	if not is_instance_valid(_camera) or _layer_materials.is_empty():
		return
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	if viewport_size != _last_viewport_size or not is_equal_approx(_camera.fov, _last_camera_fov) or _camera.keep_aspect != _last_keep_aspect:
		_update_geometry()
	var camera_position := _camera_world_position_2d()
	if _anchor_settle_remaining > 0.0:
		_anchor_settle_remaining = maxf(_anchor_settle_remaining - maxf(delta, 0.0), 0.0)
		_camera_anchor_2d = camera_position
	var movement := camera_position - _camera_anchor_2d
	var weight := 1.0 - exp(-maxf(parallax_smoothing, 0.1) * maxf(delta, 0.0))
	for index in range(_layer_materials.size()):
		var margin := (Vector2.ONE - _cover_scales[index]) * 0.5
		var target := movement * parallax_uv_per_2d_unit * maxf(layer_parallax_speeds[index], 0.0)
		target = target.clamp(-margin, margin)
		_offsets[index] = _offsets[index].lerp(target, weight)
		_apply_layer_offset(index)


func _update_geometry() -> void:
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_last_viewport_size = viewport_size
	_last_camera_fov = _camera.fov
	_last_keep_aspect = _camera.keep_aspect
	var aspect := viewport_size.x / viewport_size.y
	for index in range(_layer_meshes.size()):
		var distance := maxf(layer_distances[index], 1.0)
		var height := 2.0 * distance * tan(deg_to_rad(_camera.fov) * 0.5)
		if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
			height /= aspect
		var quad := _layer_meshes[index].mesh as QuadMesh
		quad.size = Vector2(height * aspect, height) * viewport_overscan
		_layer_meshes[index].position.z = -distance
		var texture_size := Vector2(LAYER_TEXTURES[index].get_size())
		var texture_aspect := texture_size.x / texture_size.y
		var fraction := clampf(layer_visible_fractions[index], 0.5, 0.98)
		var scale_uv := Vector2(fraction, fraction * texture_aspect / aspect) if aspect >= texture_aspect else Vector2(fraction * aspect / texture_aspect, fraction)
		_cover_scales[index] = scale_uv
		_layer_materials[index].uv1_scale = Vector3(scale_uv.x, scale_uv.y, 1.0)
		_apply_layer_offset(index)


func _apply_layer_offset(index: int) -> void:
	var margin := (Vector2.ONE - _cover_scales[index]) * 0.5
	var texture_size := Vector2(LAYER_TEXTURES[index].get_size())
	# Snap the full UV origin to the source grid, including centered crop.
	var origin := ((margin + _offsets[index]) * texture_size).round() / texture_size
	origin = origin.clamp(Vector2.ZERO, Vector2.ONE - _cover_scales[index])
	_layer_materials[index].uv1_offset = Vector3(origin.x, origin.y, 0.0)


func _camera_world_position_2d() -> Vector2:
	return Vector2(_camera.global_position.x, _camera.global_position.z) / maxf(world_scale, 0.0001)


func _attach_camera_environment() -> void:
	if _camera.environment != null:
		return
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.09, 0.14, 0.20, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.08, 0.16, 0.24, 1.0)
	environment.ambient_light_energy = 0.25
	_camera.environment = environment


func _exit_tree() -> void:
	for instance in _layer_meshes:
		if is_instance_valid(instance):
			if instance.get_parent() != null:
				instance.get_parent().remove_child(instance)
			instance.queue_free()
	_layer_meshes.clear()
	_layer_materials.clear()
	_cover_scales.clear()
	_offsets.clear()
	_camera = null
