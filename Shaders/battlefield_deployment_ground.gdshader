shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D terrain_texture : source_color, filter_nearest;
instance uniform float deployment_progress : hint_range(0.0, 1.0) = 1.0;
instance uniform float deployment_dim : hint_range(0.0, 1.0) = 1.0;
instance uniform float deployment_pulse : hint_range(0.0, 1.0) = 0.0;
instance uniform float deployment_seed = 0.0;
instance uniform vec4 deployment_color : source_color = vec4(0.38, 0.88, 1.0, 1.0);
instance uniform float arena_variant : hint_range(0.0, 5.0, 1.0) = 0.0;
instance uniform float arena_detail_seed : hint_range(0.0, 1.0) = 0.0;
instance uniform float arena_detail_strength : hint_range(0.0, 0.12) = 0.07;
instance uniform float arena_decal_id : hint_range(0.0, 11.0, 1.0) = 0.0;
instance uniform float arena_decal_rotation : hint_range(0.0, 3.0, 1.0) = 0.0;
instance uniform float arena_decal_strength : hint_range(0.0, 0.05) = 0.03;
instance uniform float arena_ambient_phase : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7)) + deployment_seed) * 43758.5453);
}

float line_mask(float coordinate, float position, float width) {
	return 1.0 - smoothstep(width, width + 0.004, abs(coordinate - position));
}

float arena_detail(vec2 uv) {
	float variant = floor(arena_variant + 0.5);
	float major = 0.0;
	float minor = 0.0;
	if (variant < 0.5) {
		major = max(line_mask(uv.x, 0.34, 0.007), line_mask(uv.x, 0.66, 0.007));
		minor = line_mask(uv.y, 0.50, 0.004);
	} else if (variant < 1.5) {
		major = max(line_mask(uv.y, 0.31, 0.007), line_mask(uv.y, 0.69, 0.007));
		minor = line_mask(uv.x, 0.50, 0.004);
	} else if (variant < 2.5) {
		vec2 centered = abs(uv - vec2(0.5));
		major = 1.0 - smoothstep(0.008, 0.014, abs(max(centered.x, centered.y) - 0.31));
	} else if (variant < 3.5) {
		vec2 vent_uv = abs(uv - vec2(0.5));
		float vent_zone = step(vent_uv.x, 0.19) * step(vent_uv.y, 0.12);
		minor = vent_zone * step(0.58, fract((uv.y + arena_detail_seed * 0.08) * 52.0));
	} else if (variant < 4.5) {
		major = max(line_mask(uv.x + uv.y * 0.18, 0.43, 0.006), line_mask(uv.x + uv.y * 0.18, 0.72, 0.006));
	} else {
		major = max(line_mask(uv.y + uv.x * 0.16, 0.39, 0.006), line_mask(uv.y + uv.x * 0.16, 0.68, 0.006));
	}
	vec2 circuit_grid = floor(uv * 16.0);
	float sparse_circuit = step(0.91, hash21(circuit_grid + arena_detail_seed * 37.0));
	float circuit_pixel = sparse_circuit * step(0.72, max(fract(uv.x * 16.0), fract(uv.y * 16.0)));
	return clamp(major * 0.72 + minor * 0.42 + circuit_pixel * 0.20, 0.0, 1.0);
}

vec2 rotate_decal_uv(vec2 uv) {
	vec2 point = uv - vec2(0.5);
	float rotation = floor(arena_decal_rotation + 0.5);
	if (rotation < 0.5) return point;
	if (rotation < 1.5) return vec2(-point.y, point.x);
	if (rotation < 2.5) return -point;
	return vec2(point.y, -point.x);
}

float arena_decal(vec2 uv) {
	vec2 point = rotate_decal_uv(uv);
	float id = floor(arena_decal_id + 0.5);
	float radius = length(point);
	float ring = 1.0 - smoothstep(0.012, 0.022, abs(radius - 0.18));
	float inner_ring = 1.0 - smoothstep(0.010, 0.018, abs(radius - 0.11));
	float slash = line_mask(point.x + point.y * 0.55 + 0.5, 0.5, 0.008) * step(radius, 0.24);
	float bars = step(abs(point.x), 0.17) * step(abs(point.y), 0.06) * step(0.62, fract((point.x + 0.5) * 34.0));
	float corner = max(
		line_mask(abs(point.x) + 0.5, 0.66, 0.009) * step(abs(point.y), 0.16),
		line_mask(abs(point.y) + 0.5, 0.66, 0.009) * step(abs(point.x), 0.16)
	);
	float circuit = max(
		line_mask(point.x + 0.5, 0.43, 0.007) * step(abs(point.y), 0.19),
		line_mask(point.y + 0.5, 0.57, 0.007) * step(abs(point.x), 0.13)
	);
	float scorch_noise = step(0.63, hash21(floor((point + vec2(0.5)) * 42.0) + arena_detail_seed * 91.0));
	float scorch = scorch_noise * (1.0 - smoothstep(0.08, 0.25, radius));
	float chevron = line_mask(abs(point.x) + point.y * 0.72 + 0.5, 0.54, 0.010) * step(radius, 0.24);
	if (id < 0.5) return ring;
	if (id < 1.5) return inner_ring + slash;
	if (id < 2.5) return bars;
	if (id < 3.5) return corner;
	if (id < 4.5) return circuit;
	if (id < 5.5) return scorch;
	if (id < 6.5) return max(ring * step(0.0, point.x), slash);
	if (id < 7.5) return chevron;
	if (id < 8.5) return max(chevron, chevron * step(point.y, 0.0));
	if (id < 9.5) return max(circuit, inner_ring * 0.55);
	if (id < 10.5) return max(bars, corner * 0.65);
	return max(scorch * 0.70, ring * step(0.08, abs(point.x)));
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
	float mechanical_detail = arena_detail(UV);
	float decal_detail = clamp(arena_decal(UV), 0.0, 1.0);
	terrain.rgb *= 1.0 - mechanical_detail * arena_detail_strength - decal_detail * arena_decal_strength;
	float ambient_scan = step(0.985, fract(UV.x * 0.72 + UV.y * 0.28 - TIME * 0.018 + arena_ambient_phase));
	float circuit_gate = step(0.78, hash21(floor(UV * 12.0) + arena_detail_seed * 53.0));
	terrain.rgb += deployment_color.rgb * ambient_scan * circuit_gate * 0.018;
	float front = 1.0 - smoothstep(0.0, 0.055, abs(reveal_distance - threshold));
	float dim = mix(0.34, 1.0, deployment_dim);
	vec3 scan_color = mix(terrain.rgb * dim, deployment_color.rgb, front * 0.72);
	ALBEDO = scan_color;
	EMISSION = deployment_color.rgb * (front * 0.68 + deployment_pulse * 0.24 + ambient_scan * circuit_gate * 0.012);
}
