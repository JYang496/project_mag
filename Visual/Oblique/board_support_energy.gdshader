shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

varying vec3 contour_position;

void vertex() {
	contour_position = VERTEX;
}

void fragment() {
	float depth = clamp(UV.y, 0.0, 1.0);
	float fade = pow(1.0 - depth, 2.2);
	// Position-based scans retain their phase across a reentrant corner.
	float along = contour_position.x + contour_position.z;
	float scan = pow(0.5 + 0.5 * cos(along * 78.5398), 18.0);
	float pulse = 0.94 + 0.06 * sin(TIME * 1.8);
	float band = pow(0.5 + 0.5 * cos(depth * 24.0 - TIME * 1.2), 14.0);
	ALBEDO = mix(vec3(0.015, 0.45, 0.65), vec3(0.08, 0.80, 1.0), scan * 0.45 + band * 0.12);
	ALPHA = fade * (0.24 + scan * 0.20 + band * 0.035) * pulse;
}
