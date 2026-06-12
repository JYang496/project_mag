extends EquipmentSlot
class_name EquipmentSlotModule

func _on_background_gui_input(event: InputEvent) -> void:
	pass

func _on_color_rect_mouse_entered() -> void:
	hover_over = true
	update()

func _on_color_rect_mouse_exited() -> void:
	hover_over = false
	update()
