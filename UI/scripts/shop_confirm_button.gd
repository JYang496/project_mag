extends Button

@onready var shop: VBoxContainer = $"../Shop"
@onready var equipped: GridContainer = $"../Equipped"
@onready var shop_sell_button: Button = $"../ShopSellButton"
@onready var shop_cancel_button: Button = $"../ShopCancelButton"
@onready var shop_confirm_button: Button = $"."



func _on_button_up() -> void:
	InventoryData.clear_on_select()
	for sell_item: Weapon in InventoryData.ready_to_sell_list.duplicate():
		var result := InventoryData.sell_equipped_weapon(sell_item)
		if not result.get("ok", false):
			var ui = GlobalVariables.ui
			if ui and is_instance_valid(ui) and ui.has_method("show_item_message"):
				ui.show_item_message(str(result.get("reason", "")), 1.8)
	if equipped:
		for slot : EquipmentSlotShop in equipped.get_children():
			slot.reset_sell_status()
