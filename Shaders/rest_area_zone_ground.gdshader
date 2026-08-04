shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

instance uniform vec4 zone_color : source_color = vec4(0.42, 1.0, 0.48, 1.0);
instance uniform float hovered = 0.0;
instance uniform float selected = 0.0;
instance uniform float visibility_alpha : hint_range(0.0, 1.0) = 1.0;
instance uniform float arrival_progress : hint_range(0.0, 1.0) = 1.0;
instance uniform float arrival_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed = 1.8;
uniform float animation_time = 0.0;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius = length(centered);
	float angle = atan(centered.y, centered.x);
	float pulse = 0.5 + 0.5 * sin(animation_time * pulse_speed * 6.2831853);
	float active = max(hovered, selected);
	vec2 arrival_block = floor(UV * 32.0) / 32.0 * 2.0 - 1.0;
	float arrival_radius = length(arrival_block);
	float arrival_threshold = mix(-0.12, 1.52, arrival_progress);
	float arrival_mask = 1.0 - smoothstep(arrival_threshold, arrival_threshold + 0.07, arrival_radius);

	float disc = 1.0 - smoothstep(0.72, 0.82, radius);
	float scan = 0.5 + 0.5 * sin(radius * 30.0 - animation_time * 5.0);
	float inner_ring = 1.0 - smoothstep(0.018, 0.055, abs(radius - (0.61 + pulse * 0.025)));
	float border = 1.0 - smoothstep(0.018, 0.060, abs(radius - 0.82));
	float glow = (1.0 - smoothstep(0.72, 1.0, radius)) * smoothstep(0.66, 0.82, radius);
	// Three outward chevrons replace the legacy 2D RestArea arrows. They only
	// appear on the active zone and stay on the same perspective ground plane.
	float arrow_band = 1.0 - smoothstep(0.025, 0.065, abs(radius - (0.34 + pulse * 0.035)));
	float arrow_spokes = pow(max(0.0, cos(angle * 3.0)), 18.0);
	float arrows = arrow_band * arrow_spokes * active;

	float base_alpha = disc * (0.11 + selected * 0.07 + hovered * (0.09 + pulse * 0.05));
	float ring_alpha = inner_ring * (0.16 + active * 0.34 + pulse * active * 0.12);
	float border_alpha = border * (0.25 + selected * 0.30 + hovered * 0.32);
	float glow_alpha = glow * active * (0.12 + pulse * 0.14);
	float arrival_front = 1.0 - smoothstep(0.0, 0.08, abs(arrival_radius - arrival_threshold));
	float alpha = (base_alpha * (0.82 + scan * 0.18) + ring_alpha + border_alpha + glow_alpha + arrows * 0.72) * visibility_alpha * arrival_mask;

	vec3 color = zone_color.rgb * (0.72 + scan * 0.12 + active * 0.28);
	ALBEDO = color;
	EMISSION = color * (0.18 + border * active * 0.48 + arrows * 0.75 + arrival_front * 0.70 + arrival_pulse * 0.10);
	ALPHA = alpha * zone_color.a * (1.0 - smoothstep(0.96, 1.0, radius));
}
