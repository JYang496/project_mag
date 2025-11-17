extends Button

@onready var shop: VBoxContainer = $"../Shop"
@onready var inventory: GridContainer = $"../Inventory"
@onready var equipped: GridContainer = $"../Equipped"
@onready var shop_confirm_button: Button = $"../ShopConfirmButton"
@onready var shop_cancel_button: Button = $"../ShopCancelButton"
@onready var shop_sell_button: Button = $"."
@onready var shop_refresh_button: Button = $"../ShopRefreshButton"


func _on_button_up() -> void:
	InventoryData.clear_on_select()
	for slot : ShopInvSlot in inventory.get_children():
		slot.reset_sell_status()
	for slot : EquipmentSlotShop in equipped.get_children():
		slot.sell_mode = true
		slot.reset_sell_status()
	shop_sell_button.visible = false
	shop_confirm_button.visible = true
	shop_cancel_button.visible = true
	shop_refresh_button.visible = false
	shop.visible = false
	inventory.visible = true
	
	
