shader_type canvas_item;
uniform vec4 icon_color : source_color = vec4(0.95, 0.97, 0.96, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.015, 0.03, 0.04, 0.9);
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float foreground = sample_color.g;
	float shadow = max(sample_color.r - foreground, 0.0);
	vec4 result = shadow_color * shadow;
	result = mix(result, icon_color, foreground);
	result.a = max(shadow_color.a * shadow, icon_color.a * foreground) * COLOR.a;
	COLOR = result;
}
