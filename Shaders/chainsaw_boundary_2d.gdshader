shader_type canvas_item;
#include "res://Shaders/chainsaw_boundary.gdshaderinc"
uniform float boundary_length = 512.0;
uniform float boundary_width = 104.0;
void fragment() {
	COLOR = chainsaw_boundary(vec2(UV.x * boundary_length, (UV.y - 0.5) * boundary_width), TIME, boundary_width) * COLOR;
}
