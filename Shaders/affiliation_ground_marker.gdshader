shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

instance uniform vec4 marker_color : source_color = vec4(1.0, 0.3, 0.37, 0.78);
instance uniform float line_width_ratio : hint_range(0.005, 0.125) = 0.04;
instance uniform float half_arc_radians : hint_range(0.05, 0.8) = 0.23;
instance uniform int marker_shape = 1;

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
	float alpha = ring * pattern * marker_color.a;
	if (alpha <= 0.005) {
		discard;
	}
	ALBEDO = marker_color.rgb;
	ALPHA = alpha;
}
