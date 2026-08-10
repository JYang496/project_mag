shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

instance uniform vec4 effect_color : source_color = vec4(1.0);
instance uniform int link_style : hint_range(0, 2) = 0;
instance uniform float flow_speed : hint_range(0.0, 6.0) = 0.0;
instance uniform float animation_offset = 0.0;
instance uniform float segment_count : hint_range(1.0, 32.0) = 12.0;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float along = local_position.x + 0.5;
	float alpha_pattern = 1.0;
	if (link_style == 1) {
		float segment = fract(along * segment_count - TIME * flow_speed + animation_offset);
		alpha_pattern = step(0.28, segment) * (1.0 - step(0.78, segment));
	} else if (link_style == 2) {
		float shield_wave = 0.5 + 0.5 * sin((along * segment_count - TIME * flow_speed + animation_offset) * 6.283185);
		alpha_pattern = 0.58 + shield_wave * 0.42;
	}
	ALBEDO = effect_color.rgb;
	EMISSION = effect_color.rgb * (0.12 + alpha_pattern * 0.12);
	ALPHA = effect_color.a * alpha_pattern;
}
