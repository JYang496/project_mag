extends Button

@onready var shop: VBoxContainer = $"../Shop"
@onready var inventory: GridContainer = $"../Inventory"
@onready var equipped: GridContainer = $"../Equipped"
@onready var shop_sell_button: Button = $"../ShopSellButton"
@onready var shop_cancel_button: Button = $"../ShopCancelButton"
@onready var shop_confirm_button: Button = $"."



func _on_button_up() -> void:
	InventoryData.clear_on_select()
	print("confirm: ",InventoryData.ready_to_sell_list)
	for sell_item : Node2D in InventoryData.ready_to_sell_list:
		if InventoryData.inventory_slots.has(sell_item):
			print("item sold: ", sell_item)
			InventoryData.inventory_slots.erase(sell_item)
			sell_item.queue_free()
		elif PlayerData.player_weapon_list.has(sell_item):
			print("item sold: ", sell_item)
			PlayerData.player_weapon_list.erase(sell_item)
			sell_item.queue_free()
			
	for slot : ShopInvSlot in inventory.get_children():
		slot.reset_sell_status()
	for slot : EquipmentSlotShop in equipped.get_children():
		slot.reset_sell_status()
