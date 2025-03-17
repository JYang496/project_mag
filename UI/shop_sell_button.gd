extends Button

@onready var shop: VBoxContainer = $"../Shop"
@onready var inventory: GridContainer = $"../Inventory"
@onready var equipped: GridContainer = $"../Equipped"
@onready var shop_confirm_button: Button = $"../ShopConfirmButton"
@onready var shop_cancel_button: Button = $"../ShopCancelButton"
@onready var shop_sell_button: Button = $"."


func _on_button_up() -> void:
	InventoryData.clear_on_select()
	shop_sell_button.visible = false
	shop_confirm_button.visible = true
	shop_cancel_button.visible = true
	shop.visible = false
	inventory.visible = true
	
	
