extends Button

@onready var shop: VBoxContainer = $"../Shop"
var starting_cost = 2
var cost = 2

func _on_button_up() -> void:
	if PlayerData.player_gold >= cost:
		PlayerData.player_gold -= cost
		cost += 2
		for slot : ShopWeaponSlot in shop.get_children():
			slot.new_item()
			slot.update()


func _on_ui_reset_cost() -> void:
	cost = starting_cost
