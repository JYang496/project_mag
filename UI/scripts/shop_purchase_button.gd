extends Button

func _on_button_up() -> void:
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.purchase_management_controller:
		ui.purchase_management_controller.purchase_selected_item()
		ui.purchase_management_controller.mark_purchase_action_dirty()
