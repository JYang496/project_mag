extends InvSlot

var ready_to_sell : bool = false

func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		if not ready_to_sell:
			print("shop inv: ",inventory_index)
			border_color = Color(0,1,1)
			default_border_width = border_width
			queue_redraw()
			ready_to_sell = true
		else:
			border_color = default_border_color
			default_border_width = 0.0
			queue_redraw()
			ready_to_sell = false
			
