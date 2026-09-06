shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D surface_noise : filter_nearest, repeat_enable;
uniform int trail_style = 0;
uniform float clock_sec = 0.0;
varying vec4 life;

void vertex() {
	life = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 uv = (floor(UV * vec2(12.0, 20.0)) + 0.5) / vec2(12.0, 20.0);
	float remaining = life.y - clock_sec;
	float strength = smoothstep(0.0, 0.45, remaining);
	float phase = clock_sec * 1.8 + life.z;
	float n = texture(surface_noise, vec2(uv.x * 0.65 + life.z, uv.y * 0.6 + phase * 0.4)).r;
	float alpha = 0.0;
	vec3 color = vec3(1.0);
	if (trail_style == 0) {
		float height = 1.0 - uv.y;
		float center = 0.5 + sin(height * 5.0 + phase * 3.0) * height * 0.13;
		float width = (1.0 - height) * (0.22 + n * 0.23);
		alpha = step(abs(uv.x - center), width) * step(height, 0.40 + n * 0.65);
		color = mix(vec3(1.0, 0.18, 0.02), vec3(1.0, 0.76, 0.23), uv.y * uv.y);
		alpha *= 0.82;
	} else if (trail_style == 1) {
		vec2 center = vec2(0.5 + sin(life.z) * 0.20, 0.45 + sin(phase) * 0.15);
		vec2 delta = abs(uv - center);
		alpha = step(delta.x * 2.0 + delta.y, 0.15);
		color = vec3(0.70, 0.39, 1.0);
	} else {
		float cloud = (1.0 - smoothstep(0.12, 0.5, length((uv - vec2(0.5, 0.70)) * vec2(0.85, 1.2))));
		alpha = cloud * smoothstep(0.35, 0.66, n) * 0.24;
		color = vec3(0.63, 0.83, 0.91);
	}
	ALBEDO = color;
	EMISSION = color * 0.15;
	ALPHA = alpha * strength;
}
