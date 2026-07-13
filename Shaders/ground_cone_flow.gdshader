shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

instance uniform vec4 flow_color : source_color = vec4(1.0, 0.28, 0.04, 0.72);
instance uniform vec4 edge_color : source_color = vec4(1.0, 0.75, 0.15, 0.92);
uniform float flow_speed = 2.4;
uniform float flow_density = 9.0;
uniform float edge_softness = 0.16;

void fragment() {
	float side = abs(UV.y * 2.0 - 1.0);
	float side_fade = 1.0 - smoothstep(1.0 - edge_softness, 1.0, side);
	float origin_fade = smoothstep(0.015, 0.10, UV.x);
	float tip_fade = 1.0 - smoothstep(0.76, 1.0, UV.x);
	float wave = 0.55 + 0.45 * sin(UV.x * flow_density * 6.28318 - TIME * flow_speed * 6.28318 + UV.y * 5.0);
	float edge_glow = smoothstep(0.55, 1.0, side);
	vec4 color = mix(flow_color, edge_color, edge_glow * 0.70 + wave * 0.18);
	ALBEDO = color.rgb;
	EMISSION = color.rgb * (0.25 + wave * 0.35);
	ALPHA = color.a * side_fade * origin_fade * tip_fade * (0.62 + wave * 0.38);
}
