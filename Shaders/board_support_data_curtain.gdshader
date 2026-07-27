shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D data_texture : source_color, repeat_enable, filter_nearest;
uniform float field_alpha : hint_range(0.0, 1.0) = 0.68;
uniform float packet_speed : hint_range(0.0, 4.0) = 0.55;
uniform vec3 cyan_signal = vec3(0.025, 0.54, 0.82);
uniform vec3 violet_signal = vec3(0.26, 0.10, 0.62);

void fragment() {
	// Quantize both UV and time so the field reads as authored pixel data,
	// not as a smooth translucent plane.
	vec2 grid = vec2(64.0, 56.0);
	vec2 pixel_uv = floor(UV * grid) / grid;
	float stepped_time = floor(TIME * packet_speed * 8.0) / 8.0;
	vec4 source = texture(data_texture, pixel_uv);
	float source_intensity = max(source.r, max(source.g, source.b));

	float column_id = floor(pixel_uv.x * 19.0);
	float row_id = floor((pixel_uv.y + stepped_time * 0.025) * 31.0);
	float column_gate = step(0.58, fract(sin(column_id * 17.17 + 3.1) * 43758.5453));
	float packet_gate = step(0.73, fract(sin(column_id * 9.7 + row_id * 4.3) * 15731.743));
	float wire = step(0.91, fract(pixel_uv.x * 23.0)) * step(0.18, source_intensity);
	float packet = column_gate * packet_gate;
	float lattice_x = step(0.93, fract(pixel_uv.x * 17.0));
	float lattice_y = step(0.955, fract(pixel_uv.y * 15.0));
	float lattice = max(lattice_x * 0.30, lattice_y * 0.18);
	float visible_mask = max(smoothstep(0.08, 0.28, source_intensity) * 0.72, max(max(wire, packet), lattice));

	float top_lock = smoothstep(0.0, 0.045, UV.y);
	float lower_dissolve = 1.0 - smoothstep(0.64, 0.98, UV.y);
	float bay_gap = 1.0 - step(0.84, fract(pixel_uv.x * 5.0 + 0.13));
	float violet_mix = step(0.72, source.b - source.r * 0.35);
	vec3 signal = mix(cyan_signal, violet_signal, violet_mix);
	vec3 source_tint = max(source.rgb * 0.76, signal * visible_mask);

	ALBEDO = source_tint;
	EMISSION = source_tint * 0.34;
	ALPHA = visible_mask * top_lock * lower_dissolve * bay_gap * field_alpha;
}
