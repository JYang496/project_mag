shader_type canvas_item;

uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
	vec4 sprite_color = texture(TEXTURE, UV);
	float outline = 0.0;
	for (float x = -outline_width; x <= outline_width; x += 1.0) {
		for (float y = -outline_width; y <= outline_width; y += 1.0) {
			if (x == 0.0 && y == 0.0) {
				continue;
			}
			vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;
			outline += texture(TEXTURE, UV + offset).a;
		}
	}
	outline = min(outline, 1.0);
	if (sprite_color.a == 0.0 && outline > 0.0) {
		COLOR = outline_color;
	} else {
		COLOR = sprite_color;
	}
}
