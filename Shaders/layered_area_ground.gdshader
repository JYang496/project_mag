shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D base_texture : source_color, filter_nearest_mipmap;
uniform sampler2D detail_texture : source_color, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0, 0.45, 0.2, 0.55);
uniform vec4 detail_color : source_color = vec4(1.0, 1.0, 1.0, 0.35);
uniform vec2 detail_scale = vec2(2.0);
uniform vec2 flow_speed = vec2(0.12, -0.08);
uniform float distortion : hint_range(0.0, 0.25) = 0.025;

void fragment() {
	vec2 noise_uv = UV * detail_scale + TIME * flow_speed;
	vec4 noise_sample = texture(detail_texture, noise_uv);
	vec2 warped_uv = UV + (noise_sample.rg * 2.0 - 1.0) * distortion;
	vec4 base_sample = texture(base_texture, warped_uv);
	// Missing base textures behave like a colored ground patch.
	float base_presence = step(0.0001, dot(base_sample, base_sample));
	base_sample = mix(vec4(1.0), base_sample, base_presence);
	vec3 detail_rgb = noise_sample.rgb * detail_color.rgb;
	float detail_mix = noise_sample.a * detail_color.a;
	vec3 color = mix(base_sample.rgb * base_color.rgb, detail_rgb, detail_mix);
	float alpha = base_sample.a * base_color.a + detail_mix * (1.0 - base_color.a);
	ALBEDO = color;
	EMISSION = color * (0.12 + detail_mix * 0.35);
	ALPHA = alpha;
}
