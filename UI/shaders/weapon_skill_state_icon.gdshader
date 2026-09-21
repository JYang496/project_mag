shader_type canvas_item;
uniform float unlock_progress : hint_range(0.0, 1.0) = 0.0;
uniform float cooldown_progress : hint_range(0.0, 1.0) = 1.0;
uniform int state = 0;
uniform bool cooling = false;
uniform bool energy_blocked = false;
uniform bool active = false;
uniform bool overheated = false;
float ring(float radius, float target, float width) { return 1.0 - smoothstep(width, width + 0.018, abs(radius - target)); }
void fragment() {
	vec2 point = (UV - vec2(0.5)) * 2.0;
	float radius = length(point);
	float inside = 1.0 - smoothstep(0.96, 0.99, radius);
	float inner = 1.0 - smoothstep(0.86, 0.89, radius);
	vec4 color = vec4(0.005, 0.015, 0.02, 0.45) * inside;
	color = mix(color, vec4(0.015, 0.035, 0.045, 0.96), inner);
	if (state != 0 && unlock_progress > 0.001 && radius < 0.79) {
		float angle = atan(point.y, point.x) + 1.5707963;
		if (angle < 0.0) { angle += 6.2831853; }
		float filled = step(angle / 6.2831853, unlock_progress);
		vec3 fill_color = state == 2 ? vec3(0.20, 0.41, 0.35) : vec3(0.40, 0.33, 0.20);
		color.rgb = mix(color.rgb, fill_color, filled * 0.9);
	}
	float rim = ring(radius, 0.84, 0.025);
	vec3 rim_color = (active || state == 2) ? vec3(0.73, 0.91, 0.86) : vec3(0.44, 0.53, 0.55);
	color.rgb = mix(color.rgb, rim_color, rim);
	color.a = max(color.a, rim);
	if (cooling) {
		float angle = atan(point.y, point.x) + 1.5707963;
		if (angle < 0.0) { angle += 6.2831853; }
		float cooldown_arc = ring(radius, 0.94, 0.028) * step(angle / 6.2831853, cooldown_progress);
		color.rgb = mix(color.rgb, vec3(0.45, 0.79, 0.96), cooldown_arc);
		color.a = max(color.a, cooldown_arc);
	}
	if (overheated) {
		float hot_rim = ring(radius, 0.94, 0.035);
		float slash = (1.0 - smoothstep(0.055, 0.085, abs(point.x + point.y))) * step(radius, 0.78);
		color.rgb = mix(color.rgb, vec3(1.0, 0.30, 0.20), hot_rim);
		color.rgb = mix(color.rgb, vec3(1.0, 0.94, 0.84), slash);
		color.a = max(color.a, max(hot_rim, slash));
	}
	if (state == 0) {
		float disabled_slash = (1.0 - smoothstep(0.045, 0.075, abs(point.x + point.y))) * step(radius, 0.76);
		color.rgb = mix(color.rgb, vec3(0.58, 0.64, 0.67), disabled_slash);
		color.a = max(color.a, disabled_slash);
	}
	if (energy_blocked) {
		vec2 badge_point = point - vec2(0.72, -0.66);
		float badge = 1.0 - smoothstep(0.25, 0.29, length(badge_point));
		color.rgb = mix(color.rgb, vec3(0.96, 0.74, 0.33), badge);
		color.a = max(color.a, badge);
		float bolt = (1.0 - smoothstep(0.035, 0.055, abs(badge_point.x + badge_point.y * 0.38)))
			* step(abs(badge_point.y), 0.17);
		color.rgb = mix(color.rgb, vec3(0.08, 0.13, 0.15), bolt);
		color.a = max(color.a, bolt);
	}
	COLOR = color;
}
