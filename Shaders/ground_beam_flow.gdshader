shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

instance uniform vec4 beam_color : source_color = vec4(0.35, 0.85, 1.0, 0.95);
uniform float flow_speed = 3.0;
uniform float flow_density = 8.0;
uniform float edge_softness = 0.24;

void fragment() {
	float side = abs(UV.y * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(1.0 - edge_softness, 1.0, side);
	float pulse = 0.60 + 0.40 * sin(UV.x * flow_density * 6.28318 - TIME * flow_speed * 6.28318);
	float core = 1.0 - smoothstep(0.0, 0.72, side);
	vec3 color = beam_color.rgb * (0.75 + pulse * 0.35 + core * 0.45);
	ALBEDO = color;
	EMISSION = color * (0.45 + core * 0.55);
	ALPHA = beam_color.a * edge * (0.72 + pulse * 0.28);
}
