shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
#include "res://Shaders/chainsaw_boundary.gdshaderinc"
instance uniform vec4 effect_color : source_color = vec4(1.0);
instance uniform float boundary_length = 512.0;
instance uniform float boundary_width = 104.0;
void fragment() {
	vec4 ink = chainsaw_boundary(vec2(UV.x * boundary_length, (UV.y - 0.5) * boundary_width), TIME, boundary_width);
	ALBEDO = ink.rgb;
	EMISSION = ink.rgb * vec3(0.25) * step(0.9, ink.r);
	ALPHA = ink.a * effect_color.a;
}
