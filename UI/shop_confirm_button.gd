extends Button

@onready var shop: VBoxContainer = $"../Shop"
@onready var inventory: GridContainer = $"../Inventory"
@onready var equipped: GridContainer = $"../Equipped"
@onready var shop_sell_button: Button = $"../ShopSellButton"
@onready var shop_cancel_button: Button = $"../ShopCancelButton"
@onready var shop_confirm_button: Button = $"."



func _on_button_up() -> void:
	InventoryData.clear_on_select()
	print("confirm")
