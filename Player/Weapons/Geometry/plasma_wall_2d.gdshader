shader_type canvas_item;
render_mode unshaded;
#include "plasma_wall.gdshaderinc"
void fragment() {
	COLOR = plasma_wall(UV);
}
