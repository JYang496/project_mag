extends Button

func _on_button_up() -> void:
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui):
		if GlobalVariables.ui.has_method("smith_open_weapon_upgrade_panel"):
			GlobalVariables.ui.smith_open_weapon_upgrade_panel()
		else:
			GlobalVariables.ui.smith_open_upgrade_panel()
