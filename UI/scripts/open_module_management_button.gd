extends Button

func _on_button_up() -> void:
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui):
		GlobalVariables.ui.module_open_management_panel()
