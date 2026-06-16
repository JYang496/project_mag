extends Button

func _on_button_up() -> void:
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui):
		if GlobalVariables.ui.has_method("merchant_open_module_buy_panel"):
			GlobalVariables.ui.merchant_open_module_buy_panel()
		else:
			GlobalVariables.ui.merchant_open_sell_panel()
