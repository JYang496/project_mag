shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

instance uniform vec4 effect_color : source_color = vec4(1.0);

void fragment() {
	ALBEDO = effect_color.rgb;
	EMISSION = effect_color.rgb * 0.18;
	ALPHA = effect_color.a;
}
