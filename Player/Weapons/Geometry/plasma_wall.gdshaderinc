uniform sampler2D plasma_noise : filter_nearest, repeat_enable;
uniform vec2 visual_size = vec2(64.0, 158.0);
uniform float wall_width = 150.0;
uniform float wall_thickness = 20.0;
uniform float animation_age = 0.0;
uniform float dissolve = 0.0;
uniform float charged = 0.0;

// All layers share one logical-pixel grid in both renderers.
vec4 plasma_wall(vec2 uv) {
	vec2 p = floor(uv * visual_size) + vec2(0.5);
	p -= visual_size * 0.5;
	p.x -= wall_thickness;
	float t = floor(animation_age * 20.0) / 20.0;
	float n = texture(plasma_noise, vec2(p.x * 0.025 + t * 1.7, p.y * 0.018 - t * 0.6)).r;
	float row = texture(plasma_noise, vec2(t * 0.8, floor(p.y / 2.0) * 0.07)).r;
	float taper = clamp((wall_width * 0.5 - abs(p.y)) / 5.0, 0.0, 1.0);
	float edge_x = wall_thickness * 0.5 - floor((1.0 - taper) * 3.0);
	float behind = edge_x - p.x;
	float form = clamp(animation_age / 0.085, 0.0, 1.0);
	float width = wall_thickness * (0.15 + form * 0.85);
	float body = step(0.0, behind) * (1.0 - step(width, behind)) * taper;
	float core = step(0.0, behind) * (1.0 - step(2.0 + charged, behind)) * taper;
	float rim = step(-2.0, behind) * (1.0 - step(5.0 + charged, behind)) * taper;
	float wake_length = width + floor(row * (24.0 + charged * 12.0));
	float wake = step(width * 0.6, behind) * (1.0 - step(wake_length, behind));
	wake *= step(0.53, row) * step(0.42, n) * taper * form;
	float arc_x = width * (0.32 + 0.24 * sin(floor(p.y / 3.0) * 0.68 + t * 13.0));
	float arc = (1.0 - step(1.2 + charged * 0.5, abs(behind - arc_x))) * body;
	float bands = step(0.55, n) * body;
	float pulse = 0.5 + 0.5 * sin(t * 17.0);
	vec3 color = vec3(0.025, 0.27, 0.63);
	color = mix(color, vec3(0.03, 0.59, 0.96), bands);
	color = mix(color, vec3(0.12, 0.71, 1.0), wake * 0.7);
	color = mix(color, vec3(0.29, 0.87, 1.0), rim * 0.6);
	color = mix(color, vec3(0.58, 0.95, 1.0), arc);
	color = mix(color, vec3(0.85, 1.0, 1.0), core);
	float alpha = max(max(body * (0.50 + bands * 0.23), wake * 0.55), max(rim * 0.38, max(arc * 0.90, core)));
	color *= 0.91 + pulse * 0.09 + charged * 0.12;
	// Break the wall into sparse drifting fragments before fading out.
	float breakup = texture(plasma_noise, floor(p / 2.0) * 0.13 + vec2(dissolve * 0.6, 0.0)).r;
	alpha *= step(dissolve * 1.15, breakup) * (1.0 - dissolve);
	return vec4(color, alpha);
}
