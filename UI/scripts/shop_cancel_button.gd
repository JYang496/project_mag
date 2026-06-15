extends Button

@onready var shop: VBoxContainer = $"../Shop"
@onready var equipped: GridContainer = $"../Equipped"
@onready var shop_cancel_button: Button = $"."
@onready var shop_sell_button: Button = $"../ShopSellButton"
@onready var shop_confirm_button: Button = $"../ShopConfirmButton"
@onready var shop_refresh_button: Button = $"../ShopRefreshButton"


func _on_button_up() -> void:
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("set_shop_sell_mode"):
		ui.set_shop_sell_mode(false)
	
