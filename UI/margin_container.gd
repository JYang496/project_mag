extends MarginContainer

# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

var mo : bool = false

var display : bool = false
func _draw():
	# Get the size of the control
	print("draw")
	var rect = Rect2(Vector2.ZERO, size)
	var width = 0
	if mo:
		width = border_width
	draw_rect(rect, border_color, false, width)

func update() -> void:
	queue_redraw()


func _on_color_rect_mouse_entered() -> void:
	mo = true
	update()


func _on_color_rect_mouse_exited() -> void:
	mo = false
	update()
