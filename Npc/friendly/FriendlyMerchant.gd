extends FriendlyNPC

#@onready var ui = get_tree().get_first_node_in_group("ui")

# This NPC provides weapons
func _ready():
	for slot : ShopWeaponSlot in GlobalVariables.ui.shop.get_children():
		slot.new_item()
		slot.update()


func panel_move_in() -> void:
	is_interacting = true
	GlobalVariables.ui.shopping_panel_in()


func panel_move_out() -> void:
	GlobalVariables.ui.shopping_panel_out()
	is_interacting = false
