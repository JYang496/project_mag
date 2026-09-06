shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
#include "burning_spray.gdshaderinc"
instance uniform bool burning_style = false;

instance uniform vec4 flow_color : source_color = vec4(1.0, 0.28, 0.04, 0.72);
instance uniform vec4 edge_color : source_color = vec4(1.0, 0.75, 0.15, 0.92);
instance uniform vec4 range_cue_color : source_color = vec4(1.0, 0.42, 0.10, 1.0);
instance uniform vec4 core_highlight_color : source_color = vec4(1.0, 0.88, 0.42, 1.0);
instance uniform float body_opacity : hint_range(0.0, 1.0) = 0.68;
instance uniform float range_cue_opacity : hint_range(0.0, 1.0) = 0.24;
instance uniform float core_highlight_strength : hint_range(0.0, 1.0) = 0.34;
uniform sampler2D flame_texture : source_color, filter_nearest, repeat_disable;
uniform bool use_flame_texture = false;
uniform float flow_speed = 2.4;
uniform float flow_density = 9.0;
uniform vec2 pixel_grid = vec2(32.0, 12.0);

void fragment() {
	vec2 pixel_uv = (floor(UV * pixel_grid) + vec2(0.5)) / pixel_grid;
	if (burning_style && use_flame_texture) {
		vec4 flame = burning_spray(UV, texture(flame_texture, UV), TIME);
		ALBEDO = flame.rgb;
		EMISSION = flame.rgb * 0.18;
		ALPHA = flame.a * flow_color.a * body_opacity;
	} else if (use_flame_texture) {
		vec4 flame = texture(flame_texture, UV);
		float side = abs(pixel_uv.y * 2.0 - 1.0);
		float side_cue = step(0.82, side) * (1.0 - step(0.97, side));
		float tip_cue = step(0.88, pixel_uv.x) * (1.0 - step(0.98, pixel_uv.x));
		float range_cue = max(side_cue, tip_cue) * range_cue_opacity;
		float core_mask = (1.0 - step(0.30, side)) * (1.0 - step(0.78, pixel_uv.x));
		float core_amount = core_mask * flame.a * core_highlight_strength;
		vec3 layered_color = mix(flame.rgb, core_highlight_color.rgb, core_amount);
		layered_color = mix(layered_color, range_cue_color.rgb, range_cue);
		ALBEDO = layered_color;
		EMISSION = layered_color * (0.06 + core_amount * 0.18);
		ALPHA = max(flame.a * flow_color.a * body_opacity, range_cue * range_cue_color.a);
	} else {
		float side = abs(pixel_uv.y * 2.0 - 1.0);
		float body_mask = 1.0 - step(0.94, side);
		float origin_mask = step(0.04, pixel_uv.x);
		float tip_mask = 1.0 - step(0.94, pixel_uv.x);
		float phase = pixel_uv.x * flow_density - floor(TIME * flow_speed * 4.0) * 0.25 + pixel_uv.y;
		float wave_raw = 0.5 + 0.5 * sin(phase * 6.28318);
		float wave = floor(wave_raw * 3.0) / 3.0;
		float edge_glow = step(0.66, side);
		vec4 color = mix(flow_color, edge_color, min(edge_glow * 0.72 + wave * 0.16, 1.0));
		ALBEDO = color.rgb;
		EMISSION = color.rgb * (0.06 + wave * 0.08);
		ALPHA = color.a * body_mask * origin_mask * tip_mask * (0.48 + wave * 0.24);
	}
}
