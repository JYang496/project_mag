shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

instance uniform vec4 marker_color : source_color = vec4(1.0, 0.3, 0.37, 0.78);
instance uniform float line_width_ratio : hint_range(0.005, 0.125) = 0.04;
instance uniform float half_arc_radians : hint_range(0.05, 0.8) = 0.23;
instance uniform int marker_shape = 1;
instance uniform int marker_rank = 0;

void fragment() {
	vec2 point = UV * 2.0 - vec2(1.0);
	float radius = length(point);
	float radial_edge = max(fwidth(radius), 0.006);
	float ring = 1.0 - smoothstep(
		line_width_ratio,
		line_width_ratio + radial_edge,
		abs(radius - 0.78)
	);
	float angle = atan(point.y, point.x);
	float sector_distance = abs(mod(angle, 1.5707963) - 0.7853982);
	float arc_edge = max(fwidth(sector_distance), 0.012);
	float four_segments = 1.0 - smoothstep(
		half_arc_radians,
		half_arc_radians + arc_edge,
		sector_distance
	);
	float friendly_segments = 1.0 - smoothstep(0.58, 0.58 + arc_edge, sector_distance);
	float dash_distance = abs(mod(angle, 0.7853982) - 0.3926991);
	float dashes = 1.0 - smoothstep(0.17, 0.17 + arc_edge, dash_distance);
	float pattern = marker_shape == 0 ? 1.0 : (marker_shape == 2 ? friendly_segments : (marker_shape == 3 ? dashes : four_segments));
	float outer_ring = 1.0 - smoothstep(
		line_width_ratio * 0.82,
		line_width_ratio * 0.82 + radial_edge,
		abs(radius - 0.96)
	);
	float cardinal_distance = abs(mod(angle + 0.3926991, 1.5707963) - 0.7853982);
	float elite_ticks = 1.0 - smoothstep(0.10, 0.10 + arc_edge, cardinal_distance);
	float elite_accent = marker_rank == 1 ? outer_ring * elite_ticks : 0.0;
	float vertical_sector = 1.0 - smoothstep(0.16, 0.16 + arc_edge, abs(abs(angle) - 1.5707963));
	float hunt_outer = marker_rank == 2 ? outer_ring * vertical_sector : 0.0;
	float hunt_inner = marker_rank == 2 ? (1.0 - smoothstep(line_width_ratio, line_width_ratio + radial_edge, abs(radius - 0.88))) * vertical_sector : 0.0;
	float rank_accent = max(elite_accent, max(hunt_outer, hunt_inner));
	float alpha = max(ring * pattern, rank_accent) * marker_color.a;
	if (alpha <= 0.005) {
		discard;
	}
	ALBEDO = marker_color.rgb * (1.0 + rank_accent * 0.18);
	EMISSION = marker_color.rgb * rank_accent * 0.12;
	ALPHA = alpha;
}
