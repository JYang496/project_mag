shader_type canvas_item;

uniform float reload_progress : hint_range(0.0, 1.0) = 0.0;
uniform float skill_progress : hint_range(0.0, 1.0) = 0.0;
uniform float hold_progress : hint_range(0.0, 1.0) = 0.0;
uniform float passive_progress : hint_range(0.0, 1.0) = 0.0;
uniform float heat_progress : hint_range(0.0, 1.0) = 0.0;
uniform bool show_reload = false;
uniform bool show_skill = false;
uniform bool show_hold = false;
uniform bool show_passive = false;
uniform bool overheated = false;
uniform vec4 reload_color : source_color = vec4(0.34, 0.78, 0.88, 1.0);

float rect_mask(vec2 uv, vec2 minimum, vec2 maximum) {
	vec2 lower = step(minimum, uv);
	vec2 upper = step(uv, maximum);
	return lower.x * lower.y * upper.x * upper.y;
}

void fragment() {
	vec4 color = vec4(0.0);
	float reload_track = rect_mask(UV, vec2(0.10, 0.065), vec2(0.90, 0.105));
	float reload_fill = rect_mask(UV, vec2(0.11, 0.072), vec2(0.11 + 0.78 * reload_progress, 0.098));
	if (show_reload) {
		color = mix(color, vec4(0.11, 0.20, 0.25, 0.92), reload_track);
		color = mix(color, reload_color, reload_fill);
	}
	float passive_track = rect_mask(UV, vec2(0.04, 0.47), vec2(0.72, 0.51));
	float passive_fill = rect_mask(UV, vec2(0.04, 0.47), vec2(0.04 + 0.68 * passive_progress, 0.51));
	if (show_passive) {
		color = mix(color, vec4(0.30, 0.24, 0.08, 0.55), passive_track);
		color = mix(color, vec4(0.98, 0.78, 0.28, 0.95), passive_fill);
	}
	float skill_track = rect_mask(UV, vec2(0.09, 0.88), vec2(0.91, 0.92));
	float skill_fill = rect_mask(UV, vec2(0.10, 0.887), vec2(0.10 + 0.80 * skill_progress, 0.913));
	if (show_skill) {
		color = mix(color, vec4(0.05, 0.12, 0.17, 0.92), skill_track);
		color = mix(color, vec4(0.20, 0.62, 0.90, 0.92), skill_fill);
	}
	float hold_track = rect_mask(UV, vec2(0.03, 0.94), vec2(0.97, 0.97));
	float hold_fill = rect_mask(UV, vec2(0.03, 0.94), vec2(0.03 + 0.94 * hold_progress, 0.97));
	if (show_hold) {
		color = mix(color, vec4(0.22, 0.14, 0.03, 0.94), hold_track);
		color = mix(color, vec4(1.0, 0.76, 0.18, 1.0), hold_fill);
	}
	if (overheated) {
		float warning = rect_mask(UV, vec2(0.02), vec2(0.98)) - rect_mask(UV, vec2(0.04), vec2(0.96));
		color = mix(color, vec4(1.0, 0.28, 0.18, 0.88), warning);
	}
	COLOR = color;
}
