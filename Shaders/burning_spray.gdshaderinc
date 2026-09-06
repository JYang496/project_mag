uniform sampler2D combustion_noise : filter_nearest, repeat_enable;

vec4 burning_spray(vec2 uv, vec4 frame, float time) {
	vec2 p = (floor(uv * vec2(128.0, 40.0)) + 0.5) / vec2(128.0, 40.0);
	float n = texture(combustion_noise, vec2(p.x * 1.4 - time * 0.9, p.y * 1.6)).r;
	float wisps = texture(combustion_noise, vec2(p.x * 2.0 - time * 1.3, p.y * 3.0 + 0.4)).r;
	float side = abs(p.y * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(0.65 + n * 0.25, 0.85 + n * 0.15, side);
	float tip = 1.0 - smoothstep(0.65 + n * 0.2, 0.88 + n * 0.12, p.x);
	float heat = clamp((1.0 - p.x) * 0.35 + wisps * 0.8 + (1.0 - side) * 0.18, 0.0, 1.0);
	vec3 color = mix(vec3(0.85, 0.10, 0.012), vec3(1.0, 0.42, 0.055), smoothstep(0.3, 0.65, heat));
	color = mix(color, vec3(1.0, 0.88, 0.43), smoothstep(0.65, 0.95, heat));
	float alpha = frame.a * edge * tip * (0.50 + wisps * 0.5);
	return vec4(color, alpha);
}
