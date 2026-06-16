extends Button

@onready var shop: VBoxContainer = $"../Shop"
@onready var equipped: GridContainer = $"../Equipped"
@onready var shop_sell_button: Button = $"../ShopSellButton"
@onready var shop_cancel_button: Button = $"../ShopCancelButton"
@onready var shop_confirm_button: Button = $"."



func _on_button_up() -> void:
	var sell_items: Array[Weapon] = InventoryData.ready_to_sell_list.duplicate()
	for sell_item: Weapon in sell_items:
		var result := InventoryData.sell_equipped_weapon(sell_item)
		if not result.get("ok", false):
			var ui = GlobalVariables.ui
			if ui and is_instance_valid(ui) and ui.has_method("show_item_message"):
				ui.show_item_message(str(result.get("reason", "")), 1.8)
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("set_shop_sell_mode"):
		ui.set_shop_sell_mode(false)
