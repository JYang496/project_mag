shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;
instance uniform vec2 billboard_size_world = vec2(0.32, 0.32);
instance uniform float bottom_padding_ratio : hint_range(0.0, 0.49) = 0.0;
instance uniform bool flip_h = false;
instance uniform bool flip_v = false;
instance uniform vec4 visual_color : source_color = vec4(1.0);
instance uniform vec4 flash_color : source_color = vec4(1.0);
instance uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 warning_color : source_color = vec4(1.0, 0.05, 0.03, 1.0);
instance uniform float warning_amount : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 outline_color : source_color = vec4(0.0);
instance uniform float outline_width_px : hint_range(0.0, 3.0) = 0.0;
instance uniform float source_id = 0.0;

void vertex() {
	VERTEX.y += 0.5;
	VERTEX.y -= bottom_padding_ratio;
	VERTEX.xy *= billboard_size_world;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz, 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 sprite_uv = UV;
	if (flip_h) {
		sprite_uv.x = 1.0 - sprite_uv.x;
	}
	if (flip_v) {
		sprite_uv.y = 1.0 - sprite_uv.y;
	}
	vec4 texel = texture(sprite_texture, sprite_uv);
	vec2 texel_size = 1.0 / vec2(textureSize(sprite_texture, 0));
	float outline_alpha = 0.0;
	if (outline_width_px > 0.0) {
		vec2 step_uv = texel_size * max(outline_width_px, 1.0);
		outline_alpha = max(outline_alpha, texture(sprite_texture, sprite_uv + vec2(step_uv.x, 0.0)).a);
		outline_alpha = max(outline_alpha, texture(sprite_texture, sprite_uv - vec2(step_uv.x, 0.0)).a);
		outline_alpha = max(outline_alpha, texture(sprite_texture, sprite_uv + vec2(0.0, step_uv.y)).a);
		outline_alpha = max(outline_alpha, texture(sprite_texture, sprite_uv - vec2(0.0, step_uv.y)).a);
		outline_alpha = max(outline_alpha, texture(sprite_texture, sprite_uv + step_uv).a);
		outline_alpha = max(outline_alpha, texture(sprite_texture, sprite_uv - step_uv).a);
		outline_alpha = max(outline_alpha, texture(sprite_texture, sprite_uv + vec2(step_uv.x, -step_uv.y)).a);
		outline_alpha = max(outline_alpha, texture(sprite_texture, sprite_uv + vec2(-step_uv.x, step_uv.y)).a);
	}
	vec4 shaded = texel * visual_color;
	shaded.rgb = mix(shaded.rgb, flash_color.rgb, clamp(flash_amount, 0.0, 1.0));
	shaded.rgb = mix(shaded.rgb, warning_color.rgb, clamp(warning_amount, 0.0, 1.0));
	if (texel.a <= 0.01 && outline_alpha > 0.01 && outline_color.a > 0.0) {
		shaded = vec4(outline_color.rgb, outline_alpha * outline_color.a);
	}
	ALBEDO = shaded.rgb;
	ALPHA = shaded.a;
	ALPHA_SCISSOR_THRESHOLD = 0.01;
}
