extends InvSlot
class_name InvSlotUpg

func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		InventoryData.on_select_upg = item
