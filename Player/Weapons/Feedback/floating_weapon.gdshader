shader_type canvas_item;
render_mode unshaded;
uniform vec2 module_feedback = vec2(0.0);
uniform float skill_ready_pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tint = COLOR;
	vec4 texel = texture(TEXTURE, UV);
	float cyan = step(texel.r + 0.10, texel.g) * step(texel.r + 0.10, texel.b);
	vec3 energy = mix(texel.rgb, vec3(0.94, 0.30, 0.07), module_feedback.x);
	energy *= 0.88 + 0.12 * sin(TIME * 3.0) + module_feedback.y * 0.16;
	COLOR = vec4(mix(texel.rgb, energy, cyan), texel.a) * tint;
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), skill_ready_pulse);
}
