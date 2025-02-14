extends MarginContainer

# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

var hover_over : bool = false
@onready var image: TextureRect = $Background/Image
@onready var item_name: Label = $Background/Name

func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width
	if hover_over:
		width = border_width
	else:
		width = 0
	draw_rect(rect, border_color, false, width)

func update() -> void:
	queue_redraw()
	print(InventoryData.moddule_slots)

func _on_background_mouse_entered() -> void:
	hover_over = true
	update()

func _on_background_mouse_exited() -> void:
	hover_over = false
	update()
