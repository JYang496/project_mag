extends Button

@onready var shop: VBoxContainer = $"../Shop"


func _on_button_up() -> void:
	for slot : ShopWeaponSlot in shop.get_children():
		slot.new_item()
		slot.update()
