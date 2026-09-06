class_name ConnectedEffectRenderer
extends RefCounted

const PLAYER_GROUND_EFFECT_RENDER_PRIORITY := 30
const BeamShader := preload("res://Shaders/ground_beam_flow.gdshader")
const ConeShader := preload("res://Shaders/ground_cone_flow.gdshader")
const ConnectedShader := preload("res://Shaders/ground_connected_effect.gdshader")

var _view: Node
var segment_meshes: Dictionary = {}
var cone_meshes: Dictionary = {}
var shared_box_mesh: BoxMesh
var shared_box_material: ShaderMaterial
var shared_beam_mesh: QuadMesh
var shared_beam_material: ShaderMaterial
var shared_chainsaw_mesh: QuadMesh
var shared_chainsaw_material: ShaderMaterial
var shared_cone_material: ShaderMaterial
var cone_mesh_cache: Dictionary = {}
var cone_material_cache: Dictionary = {}
var trail_meshes: Dictionary = {}

func register_trail(source: MeshInstance2D) -> void:
	if not _is_ready() or trail_meshes.has(source.get_instance_id()):
		return
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2.ONE
	mesh.mesh = quad
	mesh.material_override = source.ground_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view._ground_root.add_child(mesh)
	var motes := MultiMeshInstance3D.new()
	motes.multimesh = MultiMesh.new()
	motes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	motes.multimesh.use_custom_data = true
	motes.multimesh.mesh = QuadMesh.new()
	motes.material_override = source.mote_material
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view._ground_root.add_child(motes)
	trail_meshes[source.get_instance_id()] = {"source": weakref(source), "mesh": mesh, "motes": motes, "version": -1}
	source.visible = false
	source.set_meta(&"hybrid_ground_registered", true)

func unregister_trail(id: int) -> void:
	if not trail_meshes.has(id):
		return
	var mesh: MeshInstance3D = trail_meshes[id]["mesh"]
	if is_instance_valid(mesh):
		mesh.queue_free()
	var motes: MultiMeshInstance3D = trail_meshes[id]["motes"]
	if is_instance_valid(motes):
		motes.queue_free()
	trail_meshes.erase(id)

func _sync_trails() -> void:
	for id in trail_meshes.keys():
		var source: MeshInstance2D = trail_meshes[id]["source"].get_ref()
		var mesh: MeshInstance3D = trail_meshes[id]["mesh"]
		if source == null or not is_instance_valid(mesh):
			unregister_trail(id)
			continue
		var bounds: Rect2 = source.bounds
		mesh.visible = source.enabled
		mesh.position = _view.world_2d_to_3d(bounds.get_center()) + Vector3.UP * 0.028
		mesh.scale = Vector3(maxf(bounds.size.x, 1.0) * _view.world_scale, 1.0, maxf(bounds.size.y, 1.0) * _view.world_scale)
		var motes: MultiMeshInstance3D = trail_meshes[id]["motes"]
		motes.visible = source.enabled
		if int(trail_meshes[id]["version"]) != source.geometry_version:
			trail_meshes[id]["version"] = source.geometry_version
			var samples: PackedVector4Array = source.mote_samples
			motes.multimesh.instance_count = samples.size()
			for index in range(samples.size()):
				var sample := samples[index]
				var height := 22.0 * float(_view.world_scale)
				var width := 18.0 * float(_view.world_scale)
				var position: Vector3 = _view.world_2d_to_3d(Vector2(sample.x, sample.y)) + Vector3.UP * (height * 0.5 + 0.035)
				motes.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3(width, height, 1.0)), position))
				motes.multimesh.set_instance_custom_data(index, Color(sample.z, sample.w, fposmod(sample.x * 0.17 + sample.y * 0.31, 6.28), 0.0))

func setup(view: Node) -> void:
	_view = view
	_view._segment_meshes = segment_meshes
	_view._ground_cone_meshes = cone_meshes
	shared_box_material = ShaderMaterial.new()
	shared_box_material.shader = ConnectedShader
	shared_box_mesh = BoxMesh.new()
	shared_box_mesh.size = Vector3(1.0, 0.008, 1.0)
	shared_box_mesh.material = shared_box_material
	shared_beam_material = ShaderMaterial.new()
	shared_beam_material.shader = BeamShader
	shared_beam_mesh = QuadMesh.new()
	shared_beam_mesh.orientation = PlaneMesh.FACE_Y
	shared_beam_mesh.size = Vector2.ONE
	shared_beam_mesh.material = shared_beam_material
	shared_chainsaw_material = ShaderMaterial.new()
	shared_chainsaw_material.shader = preload("res://Shaders/chainsaw_boundary_3d.gdshader")
	shared_chainsaw_material.render_priority = PLAYER_GROUND_EFFECT_RENDER_PRIORITY
	shared_chainsaw_mesh = QuadMesh.new()
	shared_chainsaw_mesh.orientation = PlaneMesh.FACE_Y
	shared_chainsaw_mesh.size = Vector2.ONE
	shared_chainsaw_mesh.material = shared_chainsaw_material
	shared_cone_material = ShaderMaterial.new()
	shared_cone_material.shader = ConeShader
	shared_cone_material.render_priority = PLAYER_GROUND_EFFECT_RENDER_PRIORITY

func register_segment(line: Line2D) -> void:
	if _is_ready():
		_view._register_ground_segment(line)

func register_cone(source: Node2D) -> void:
	if _is_ready():
		_view._register_ground_cone_effect(source)

func sync_late(_delta: float) -> void:
	if not _is_ready():
		return
	_view._sync_segment_meshes()
	_view._sync_ground_cone_meshes()
	_sync_trails()

func clear() -> void:
	for id in trail_meshes.keys():
		unregister_trail(id)
	segment_meshes.clear()
	cone_meshes.clear()
	cone_mesh_cache.clear()
	cone_material_cache.clear()

func get_cone_mesh(half_angle: float) -> ArrayMesh:
	var cache_key := int(round(rad_to_deg(half_angle) * 10.0))
	if not cone_mesh_cache.has(cache_key):
		cone_mesh_cache[cache_key] = _view._build_ground_cone_array_mesh(1.0, half_angle, shared_cone_material)
	return cone_mesh_cache[cache_key] as ArrayMesh

func get_cone_material(texture: Texture2D) -> ShaderMaterial:
	if texture == null:
		return shared_cone_material
	var texture_id := texture.get_instance_id()
	if cone_material_cache.has(texture_id):
		return cone_material_cache[texture_id] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = ConeShader
	material.render_priority = PLAYER_GROUND_EFFECT_RENDER_PRIORITY
	material.set_shader_parameter("use_flame_texture", true)
	material.set_shader_parameter("flame_texture", texture)
	material.set_shader_parameter("combustion_noise", preload("res://Combat/visual/trail_surface_noise.tres"))
	cone_material_cache[texture_id] = material
	return material

func _is_ready() -> bool:
	return _view != null and is_instance_valid(_view)
