extends MeshInstance2D

const REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")
const NOISE := preload("res://Player/Weapons/Geometry/plasma_wall_noise.tres")
const CANVAS_SHADER := preload("res://Player/Weapons/Geometry/plasma_wall_2d.gdshader")
const GROUND_SHADER := preload("res://Player/Weapons/Geometry/plasma_wall_3d.gdshader")

var ground_material: ShaderMaterial
var visual_size := Vector2(64.0, 158.0)
var _canvas_material: ShaderMaterial

func setup(width: float, thickness: float, charged: bool) -> void:
	visual_size = Vector2(ceilf(thickness * 3.2), ceilf(width + 8.0))
	position.x = -thickness
	var quad := QuadMesh.new()
	quad.size = visual_size
	mesh = quad
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas_material = ShaderMaterial.new()
	_canvas_material.shader = CANVAS_SHADER
	material = _canvas_material
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_material.render_priority = 30
	for target in [_canvas_material, ground_material]:
		target.set_shader_parameter("plasma_noise", NOISE)
		target.set_shader_parameter("visual_size", visual_size)
		target.set_shader_parameter("wall_width", width)
		target.set_shader_parameter("wall_thickness", thickness)
		target.set_shader_parameter("charged", 1.0 if charged else 0.0)

func _ready() -> void:
	REGISTRATION.register(self, &"register_ground_plasma_wall")

func animate(age: float, dissolve: float) -> void:
	for target in [_canvas_material, ground_material]:
		target.set_shader_parameter("animation_age", age)
		target.set_shader_parameter("dissolve", dissolve)

func _exit_tree() -> void:
	REGISTRATION.unregister(self)
