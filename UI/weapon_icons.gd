extends Control

# Border properties
@export var border_color: Color = Color(1, 0, 0) # Red
@export var border_width: float = 4.0
func _draw():
	# Get all weapon icons
	var on_select_weapon_icon = self.get_child(PlayerData.on_select_weapon)
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	
	# Draw the border
	on_select_weapon_icon.draw_rect(rect, border_color, false, border_width)

func update() -> void:
	_draw()
