extends Button

func _on_button_up() -> void:
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui):
		GlobalVariables.ui.smith_open_fuse_panel()
