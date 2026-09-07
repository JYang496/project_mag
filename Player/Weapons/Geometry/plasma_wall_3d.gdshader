shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "plasma_wall.gdshaderinc"
void fragment() {
	vec4 plasma = plasma_wall(UV);
	ALBEDO = plasma.rgb;
	ALPHA = plasma.a;
}
