shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "trail_surface.gdshaderinc"
void fragment() {
	vec4 surface = trail_surface(surface_bounds.xy + UV * surface_bounds.zw);
	ALBEDO = surface.rgb;
	EMISSION = surface.rgb * 0.12;
	ALPHA = surface.a;
}
