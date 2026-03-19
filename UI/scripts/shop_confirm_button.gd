extends Button

@onready var shop: VBoxContainer = $"../Shop"
@onready var inventory: GridContainer = $"../Inventory"
@onready var equipped: GridContainer = $"../Equipped"
@onready var shop_sell_button: Button = $"../ShopSellButton"
@onready var shop_cancel_button: Button = $"../ShopCancelButton"
@onready var shop_confirm_button: Button = $"."



func _on_button_up() -> void:
	InventoryData.clear_on_select()
	for sell_item : Weapon in InventoryData.ready_to_sell_list:
		var salvaged_modules: Array[Module] = []
		for child in sell_item.modules.get_children():
			var module_instance := child as Module
			if module_instance == null:
				continue
			module_instance.reparent(InventoryData)
			salvaged_modules.append(module_instance)
		for salvaged_module in salvaged_modules:
			InventoryData.obtain_module(salvaged_module, sell_item)
		if InventoryData.inventory_slots.has(sell_item):
			InventoryData.inventory_slots.erase(sell_item)
			sell_item.queue_free()
		elif PlayerData.player_weapon_list.has(sell_item):
			PlayerData.player_weapon_list.erase(sell_item)
			sell_item.queue_free()
	if inventory:
		for slot : ShopInvSlot in inventory.get_children():
			slot.reset_sell_status()
	if equipped:
		for slot : EquipmentSlotShop in equipped.get_children():
			slot.reset_sell_status()
