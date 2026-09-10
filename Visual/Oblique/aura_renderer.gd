class_name AuraRenderer
extends RefCounted

# One shared procedural material; dimensions stay in world pixels per instance.
static var _support_material: ShaderMaterial

static func sync_support_surface(surface: MeshInstance3D, config: Dictionary, radius: float) -> void:
	if _support_material == null:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
instance uniform vec4 fill_color : source_color = vec4(0.2, 0.8, 1.0, 0.1);
instance uniform vec4 edge_color : source_color = vec4(1.0, 0.2, 0.3, 0.9);
instance uniform vec4 core_color : source_color = vec4(0.2, 0.8, 1.0, 0.8);
instance uniform float radius_px = 180.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p) * radius_px;
	float angle = atan(p.y, p.x) + 3.141593;
	float segment = step(0.38, fract(angle / 6.283185 * 16.0));
	float edge = step(radius_px - 1.5, r) * step(r, radius_px) * segment;
	float core_segment = step(0.22, fract(angle / 6.283185 * 4.0));
	float core = step(18.0, r) * step(r, 20.0) * core_segment;
	float pins = step(24.0, r) * step(r, 28.0) * step(0.90, abs(cos(angle * 2.0)));
	float haze = pow(max(1.0 - r / radius_px, 0.0), 2.0) * min(fill_color.a, 0.035);
	float edge_alpha = edge * min(edge_color.a, 0.55);
	float core_alpha = max(core, pins) * 0.85;
	float alpha = max(haze, max(edge_alpha, core_alpha));
	vec3 color = fill_color.rgb;
	color = mix(color, edge_color.rgb, step(0.001, edge_alpha));
	color = mix(color, core_color.rgb, step(0.001, core_alpha));
	ALBEDO = color;
	ALPHA = alpha;
}
"""
		_support_material = ShaderMaterial.new()
		_support_material.shader = shader
	if not surface.mesh is PlaneMesh:
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.0, 2.0)
		surface.mesh = plane
		surface.material_override = _support_material
	surface.set_instance_shader_parameter("radius_px", radius)
	surface.set_instance_shader_parameter("fill_color", config.get("fill_color", Color.TRANSPARENT))
	surface.set_instance_shader_parameter("edge_color", config.get("line_color", Color.RED))
	surface.set_instance_shader_parameter("core_color", config.get("detail_color", Color.WHITE))

static func draw_support(canvas: Node2D, radius: float, fill: Color, edge: Color, core: Color) -> void:
	# Nested low-alpha discs approximate the same faint radial falloff in 2D.
	for index in range(12):
		var weight := float(index + 1) / 12.0
		canvas.draw_circle(Vector2.ZERO, radius * (1.0 - float(index) / 12.0), Color(fill, minf(fill.a, 0.035) * weight / 6.5))
	for index in range(16):
		var start := TAU * (float(index) + 0.38) / 16.0
		canvas.draw_arc(Vector2.ZERO, radius, start, TAU * float(index + 1) / 16.0, 8, Color(edge, minf(edge.a, 0.55)), 1.5, false)
	for index in range(4):
		var angle := TAU * float(index) / 4.0
		canvas.draw_arc(Vector2.ZERO, 19.0, angle + 0.35, angle + PI * 0.5, 10, Color(core, 0.85), 2.0, false)
		canvas.draw_line(Vector2.from_angle(angle) * 24.0, Vector2.from_angle(angle) * 28.0, Color(core, 0.85), 2.0, false)

var _view: Node
var aura_meshes: Dictionary = {}
var link_sources: Dictionary = {}
var link_meshes: Dictionary = {}

func setup(view: Node) -> void:
	_view = view
	_view._enemy_aura_meshes = aura_meshes
	_view._enemy_link_sources = link_sources
	_view._enemy_link_meshes = link_meshes

func register_source(source: Node2D) -> void:
	if _is_ready():
		_view._register_enemy_support_visual(source)

func sync_late(_delta: float) -> void:
	if not _is_ready():
		return
	_view._sync_enemy_aura_meshes()
	_view._sync_enemy_link_meshes()

func clear() -> void:
	aura_meshes.clear()
	link_sources.clear()
	link_meshes.clear()

func _is_ready() -> bool:
	return _view != null and is_instance_valid(_view)
