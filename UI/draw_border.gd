extends TextureRect

# Border properties
@export var border_color: Color = Color(1, 0, 0) # Red
@export var border_width: float = 4.0
var display : bool = false
func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width : float = 0.0
	if display and self.texture != null:
		width = border_width
	draw_rect(rect, border_color, false, width)

func update() -> void:
	queue_redraw()
