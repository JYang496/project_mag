shader_type canvas_item;

uniform bool selected = false;
uniform bool ammo_visible = false;
uniform float ammo_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ammo_fill_color : source_color = vec4(0.45, 0.91, 0.94, 1.0);
uniform vec4 ammo_track_color : source_color = vec4(0.12, 0.30, 0.34, 0.72);

float band(float distance_value, float radius, float width) {
	return 1.0 - smoothstep(width, width + 0.75, abs(distance_value - radius));
}

void fragment() {
	vec2 pixel = UV * vec2(100.0, 100.0);
	vec2 point = pixel - vec2(50.0, 48.0);
	float radius = length(point);
	float angle = atan(point.y, point.x);
	if (angle < 0.0) { angle += 6.2831853; }
	float arc_mask = max(step(radians(67.0), angle), step(angle, radians(23.0)));
	vec4 color = vec4(0.0);
	if (selected) {
		float glow = band(radius, 34.0, 4.5) * arc_mask;
		float shadow = band(radius, 34.0, 3.0) * arc_mask;
		float rim = band(radius, 34.0, 1.8) * arc_mask;
		color = mix(color, vec4(0.45, 0.94, 1.0, 0.18), glow);
		color = mix(color, vec4(0.015, 0.03, 0.04, 0.98), shadow);
		color = mix(color, vec4(0.60, 0.96, 1.0, 1.0), rim);
		vec2 marker = point - vec2(0.0, -42.0);
		float triangle = step(abs(marker.x), 10.0 - marker.y * 0.9) * step(-5.0, marker.y) * step(marker.y, 7.0);
		color = mix(color, vec4(0.83, 0.98, 1.0, 1.0), triangle);
		if (ammo_visible) {
			float track = band(radius, 30.0, 1.8) * arc_mask;
			float normalized_angle = angle >= radians(67.0)
				? (angle - radians(67.0)) / radians(316.0)
				: (angle + 6.2831853 - radians(67.0)) / radians(316.0);
			float fill = track * step(normalized_angle, ammo_progress);
			color = mix(color, ammo_track_color, track);
			color = mix(color, ammo_fill_color, fill);
		}
	} else {
		float support_shadow = band(radius, 32.0, 2.5) * arc_mask;
		float support_rim = band(radius, 32.0, 0.9) * arc_mask;
		color = mix(color, vec4(0.015, 0.03, 0.04, 0.92), support_shadow);
		color = mix(color, vec4(0.58, 0.68, 0.70, 0.58), support_rim);
	}
	COLOR = color;
}
