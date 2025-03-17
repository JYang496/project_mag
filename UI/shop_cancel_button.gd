extends Button

@onready var shop: VBoxContainer = $"../Shop"
@onready var inventory: GridContainer = $"../Inventory"
@onready var equipped: GridContainer = $"../Equipped"
@onready var shop_cancel_button: Button = $"."
@onready var shop_sell_button: Button = $"../ShopSellButton"
@onready var shop_confirm_button: Button = $"../ShopConfirmButton"


func _on_button_up() -> void:
	InventoryData.clear_on_select()
	shop_sell_button.visible = true
	shop_confirm_button.visible = false
	shop_cancel_button.visible = false
	shop.visible = true
	inventory.visible = false
	
