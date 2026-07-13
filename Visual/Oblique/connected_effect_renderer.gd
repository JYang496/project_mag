class_name ConnectedEffectRenderer
extends RefCounted

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
var shared_cone_material: ShaderMaterial
var cone_mesh_cache: Dictionary = {}

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
	shared_cone_material = ShaderMaterial.new()
	shared_cone_material.shader = ConeShader

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

func clear() -> void:
	segment_meshes.clear()
	cone_meshes.clear()
	cone_mesh_cache.clear()

func get_cone_mesh(half_angle: float) -> ArrayMesh:
	var cache_key := int(round(rad_to_deg(half_angle) * 10.0))
	if not cone_mesh_cache.has(cache_key):
		cone_mesh_cache[cache_key] = _view._build_ground_cone_array_mesh(1.0, half_angle, shared_cone_material)
	return cone_mesh_cache[cache_key] as ArrayMesh

func _is_ready() -> bool:
	return _view != null and is_instance_valid(_view)
