extends TextureRect

@onready var equipment_slot: EquipmentSlot = $"../../.."

var hover_over : bool = false
var border_color

func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width
	if hover_over:
		width = equipment_slot.border_width
		border_color = equipment_slot.hover_over_color
	else:
		width = equipment_slot.hover_off_width
		border_color = equipment_slot.hover_off_color
	draw_rect(rect, border_color, false, width)

func update() -> void:
	queue_redraw()

func _on_mouse_entered() -> void:
	hover_over = true
	update()


func _on_mouse_exited() -> void:
	hover_over = false
	update()
