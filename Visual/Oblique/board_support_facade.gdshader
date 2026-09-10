shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D support_atlas : source_color, filter_nearest, repeat_disable;

void fragment() {
	vec3 texel = texture(support_atlas, UV).rgb;
	// Isolate authored cyan emitters; neutral metal never pulses.
	float emitter = smoothstep(0.12, 0.35, min(texel.g, texel.b) - texel.r);
	float pulse = 0.92 + 0.08 * sin(TIME * 1.8);
	ALBEDO = texel * COLOR.rgb * mix(0.82, pulse, emitter);
}
