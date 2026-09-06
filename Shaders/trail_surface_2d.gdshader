shader_type canvas_item;
render_mode unshaded;
#include "trail_surface.gdshaderinc"
void fragment() {
	// QuadMesh UVs run upward; CanvasItem world Y runs downward.
	COLOR = trail_surface(surface_bounds.xy + vec2(UV.x, 1.0 - UV.y) * surface_bounds.zw);
}
