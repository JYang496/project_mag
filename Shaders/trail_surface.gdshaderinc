// One capsule union per surface: no segment seams, no overlap brightness buildup.
// Positions and texture sampling share a fixed two-world-pixel grid.
uniform sampler2D surface_noise : filter_nearest, repeat_enable;
uniform int trail_style = 0; // fire, rift, frost
uniform int segment_total = 0;
uniform vec4 segments[64]; // from.xy, to.xy
uniform vec4 lives[64]; // radius, born, expires, unused
uniform vec4 surface_bounds;
uniform float clock_sec = 0.0;

vec4 trail_surface(vec2 world) {
	vec2 p = floor(world / 2.0) * 2.0 + 1.0;
	float coverage = 0.0;
	float activity = 0.0;
	float core = 0.0;
	float n = texture(surface_noise, p / 180.0).r;
	float fine = texture(surface_noise, p / 43.0 + vec2(0.27, 0.63)).r;
	for (int i = 0; i < segment_total; i++) {
		vec2 a = segments[i].xy;
		vec2 ab = segments[i].zw - a;
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
		float dist = length(p - a - t * ab);
		float radius = lives[i].x;
		float lifetime = max(lives[i].z - lives[i].y, 0.05);
		float remaining = lives[i].z - clock_sec;
		float residue = clamp(1.0 + remaining / 0.35, 0.0, 1.0);
		float alive = step(0.0, remaining);
		float age_fade = mix(0.35, 1.0, smoothstep(0.0, lifetime * 0.25, remaining));
		age_fade *= mix(0.35, 1.0, smoothstep(0.0, 0.12, clock_sec - lives[i].y));
		float edge = 1.0 - smoothstep(radius - 5.0, radius + 1.0, dist + (n - 0.5) * 7.0);
		coverage = max(coverage, edge * residue);
		activity = max(activity, edge * alive * age_fade);
		float fissure = 1.0 - smoothstep(0.7, 2.4, dist + (n - 0.5) * 7.0);
		core = max(core, fissure * alive * age_fade);
	}
	if (coverage < 0.01) { return vec4(0.0); }
	float beat = 0.5 + 0.5 * sin(clock_sec * 5.0 + n * 22.0);
	vec3 color;
	float alpha;
	if (trail_style == 0) {
		float ember = smoothstep(0.48, 0.64, fine) * smoothstep(0.30, 0.63, n);
		float heat = ember * activity * (0.6 + beat * 0.4);
		color = mix(vec3(0.085, 0.045, 0.038), vec3(0.82, 0.16, 0.015), heat);
		color = mix(color, vec3(1.0, 0.65, 0.12), smoothstep(0.60, 0.93, heat));
		alpha = coverage * (0.45 + ember * activity * 0.40);
	} else if (trail_style == 1) {
		float vein = (1.0 - smoothstep(0.015, 0.07, abs(fine - 0.51))) * activity;
		color = mix(vec3(0.14, 0.055, 0.24), vec3(0.49, 0.20, 0.80), vein * 0.7);
		color = mix(color, vec3(0.89, 0.65, 1.0), core * (0.75 + 0.25 * beat));
		alpha = coverage * (0.22 + activity * 0.10) + core * 0.48;
	} else {
		vec2 crystal = abs(fract((p + vec2(p.y * 0.55, 0.0)) / 23.0) - 0.5);
		float branch = 1.0 - smoothstep(0.035, 0.095, min(crystal.x, abs(crystal.y - crystal.x)));
		branch *= smoothstep(0.28, 0.60, n) * activity;
		color = mix(vec3(0.12, 0.25, 0.33), vec3(0.46, 0.69, 0.80), fine * activity);
		color = mix(color, vec3(0.78, 0.92, 1.0), branch * 0.85);
		alpha = coverage * (0.12 + activity * 0.18 + branch * 0.38);
	}
	return vec4(color, clamp(alpha, 0.0, 0.95));
}
