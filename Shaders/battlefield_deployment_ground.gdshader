shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D terrain_texture : source_color, filter_nearest;
instance uniform float deployment_progress : hint_range(0.0, 1.0) = 1.0;
instance uniform float deployment_dim : hint_range(0.0, 1.0) = 1.0;
instance uniform float deployment_pulse : hint_range(0.0, 1.0) = 0.0;
instance uniform float deployment_seed = 0.0;
instance uniform vec4 deployment_color : source_color = vec4(0.38, 0.88, 1.0, 1.0);

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7)) + deployment_seed) * 43758.5453);
}

void fragment() {
	vec2 block = floor(UV * 64.0) / 64.0;
	float radial = length(block - vec2(0.5));
	float noise = hash21(block) * 0.045;
	float threshold = mix(-0.08, 0.80, deployment_progress);
	float reveal_distance = radial + noise;
	if (reveal_distance > threshold) {
		discard;
	}

	vec4 terrain = texture(terrain_texture, UV);
	if (terrain.a < 0.01) {
		discard;
	}
	float front = 1.0 - smoothstep(0.0, 0.055, abs(reveal_distance - threshold));
	float dim = mix(0.34, 1.0, deployment_dim);
	vec3 scan_color = mix(terrain.rgb * dim, deployment_color.rgb, front * 0.72);
	ALBEDO = scan_color;
	EMISSION = deployment_color.rgb * (front * 0.68 + deployment_pulse * 0.24);
}
