extends Button

func _on_button_up() -> void:
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui) and GlobalVariables.ui.rest_area_ui_controller:
		GlobalVariables.ui.rest_area_ui_controller.back_to_upgrade_primary_menu()
