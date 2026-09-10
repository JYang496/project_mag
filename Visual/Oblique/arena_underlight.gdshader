shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 glow_color : source_color = vec4(0.07, 0.20, 0.26, 1.0);
uniform float strength : hint_range(0.0, 0.1) = 0.035;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float falloff = pow(max(0.0, 1.0 - dot(p, p)), 3.0);
	ALBEDO = glow_color.rgb;
	ALPHA = falloff * strength;
}
