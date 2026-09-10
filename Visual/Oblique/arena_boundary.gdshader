shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D groove_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D junction_texture : source_color, filter_nearest, repeat_disable;
uniform float animation_time = 0.0;
instance uniform float boundary_state = 1.0; // 0 off, 1 ordinary, 2 activated
instance uniform float segment_length = 64.0;
instance uniform float flow_offset = 0.0;
instance uniform bool junction = false;
// Each connected arm retains its own state at a mixed-state intersection.
instance uniform vec4 arm_states = vec4(-1.0); // left, right, top, bottom; -1 absent

vec3 energy(float state, float core, float pulse) {
	vec3 idle = vec3(0.015, 0.19, 0.23);
	vec3 active = mix(vec3(0.025, 0.34, 0.43), vec3(0.15, 0.68, 0.78), pulse);
	return mix(idle, active, step(1.5, state)) * core * step(0.5, state);
}

void fragment() {
	vec3 metal;
	vec3 light = vec3(0.0);
	if (junction) {
		vec2 p = floor(UV * 12.0) + vec2(0.5);
		metal = texture(junction_texture, UV).rgb;
		float horizontal = 1.0 - step(1.0, abs(p.y - 6.0));
		float vertical = 1.0 - step(1.0, abs(p.x - 6.0));
		float hstate = p.x < 6.0 ? arm_states.x : arm_states.y;
		float vstate = p.y < 6.0 ? arm_states.z : arm_states.w;
		float h = horizontal * step(0.0, hstate);
		float v = vertical * step(0.0, vstate);
		metal = mix(metal, vec3(0.005, 0.01, 0.016), max(h, v));
		light = max(energy(hstate, h, 0.12), energy(vstate, v, 0.12));
	} else {
		float along = UV.x * segment_length;
		metal = texture(groove_texture, vec2(along / 64.0, UV.y)).rgb;
		float core = 1.0 - step(1.0, abs(floor(UV.y * 8.0) + 0.5 - 4.0));
		// A sharp leading edge and longer dim tail travel 24 logical px/second.
		float phase = mod(along + flow_offset - animation_time * 24.0, 128.0);
		float pulse = pow(clamp(phase / 24.0, 0.0, 1.0), 2.0) * (1.0 - step(24.0, phase));
		light = energy(boundary_state, core, pulse);
	}
	ALBEDO = max(metal, light);
}
