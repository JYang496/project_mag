extends EquipmentSlot

func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		print("module")
