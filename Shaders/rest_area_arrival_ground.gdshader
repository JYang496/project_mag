shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D terrain_texture : source_color, filter_nearest;
instance uniform float visibility_alpha : hint_range(0.0, 1.0) = 1.0;
instance uniform float arrival_progress : hint_range(0.0, 1.0) = 1.0;
instance uniform float arrival_pulse : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 arrival_color : source_color = vec4(0.38, 0.92, 0.58, 1.0);

void fragment() {
	vec2 block = floor(UV * 64.0) / 64.0;
	float radial = length(block - vec2(0.5));
	float threshold = mix(-0.08, 0.78, arrival_progress);
	if (radial > threshold) {
		discard;
	}

	vec4 terrain = texture(terrain_texture, UV);
	if (terrain.a < 0.01) {
		discard;
	}
	float front = 1.0 - smoothstep(0.0, 0.045, abs(radial - threshold));
	vec3 color = mix(terrain.rgb, arrival_color.rgb, front * 0.56);
	ALBEDO = color;
	EMISSION = arrival_color.rgb * (front * 0.58 + arrival_pulse * front * 0.18);
	ALPHA = terrain.a * visibility_alpha;
}
