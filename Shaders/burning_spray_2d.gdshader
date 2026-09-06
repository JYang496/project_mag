shader_type canvas_item;
render_mode unshaded;
#include "burning_spray.gdshaderinc"
void fragment() {
	vec4 tint = COLOR;
	COLOR = burning_spray(UV, texture(TEXTURE, UV), TIME);
	COLOR.a *= tint.a;
}
