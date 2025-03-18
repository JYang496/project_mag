extends MarginContainer
class_name ModuleSlot

# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

var hover_over_color: Color = Color(1,1,0)
var hover_off_color: Color = Color(0,0,0,0)
var hover_over_width : float = 4.0
var hover_off_width : float = 0

var hover_over : bool = false
@onready var image: TextureRect = $Background/Image
@onready var item_name: Label = $Background/Name

func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width
	if hover_over:
		width = border_width
		border_color = hover_over_color
	else:
		width = hover_off_width
		border_color = hover_off_color
	draw_rect(rect, border_color, false, width)

func update() -> void:
	queue_redraw()

func _on_background_mouse_entered() -> void:
	hover_over = true
	update()

func _on_background_mouse_exited() -> void:
	hover_over = false
	update()
