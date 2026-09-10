shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D far_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D circuit_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 far_scale = vec2(1.0);
uniform vec2 far_offset = vec2(0.0);
uniform vec2 circuit_scale = vec2(1.0);
uniform vec2 circuit_offset = vec2(0.0);
uniform vec4 background_tint : source_color = vec4(1.0);
uniform float circuit_saturation : hint_range(0.0, 1.0) = 0.18;
// The current artwork already contains architectural detail. The legacy fine
// circuit overlay added speckle over its clean surfaces at gameplay scale.
uniform float circuit_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 far_color = texture(far_texture, UV * far_scale + far_offset).rgb;
	vec3 circuit = texture(circuit_texture, UV * circuit_scale + circuit_offset).rgb;
	float luminance = dot(circuit, vec3(0.2126, 0.7152, 0.0722));
	vec3 muted_circuit = mix(vec3(luminance), circuit, circuit_saturation);
	// Keep the old circuit detail at the perimeter, leaving the colored center quiet.
	float perimeter = smoothstep(0.22, 0.46, abs(UV.x - 0.5));
	ALBEDO = far_color * background_tint.rgb + muted_circuit * circuit_strength * perimeter;
}
