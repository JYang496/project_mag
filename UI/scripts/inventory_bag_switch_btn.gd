extends Button

func _on_button_up() -> void:
	if GlobalVariables.ui == null or not is_instance_valid(GlobalVariables.ui):
		return
	GlobalVariables.ui.inventory_upg.visible = not GlobalVariables.ui.inventory_upg.visible
	GlobalVariables.ui.equipped_upg.visible = not GlobalVariables.ui.equipped_upg.visible
