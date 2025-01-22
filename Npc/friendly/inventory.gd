extends FriendlyNPC
class_name Inventory

@onready var ui = get_tree().get_first_node_in_group("ui")

# This NPC provides weapons
func _ready():
	pass


func panel_move_in() -> void:
	print(InventoryData.inventory_slots)
	is_interacting = true
	ui.inventory_panel_in()


func panel_move_out() -> void:
	ui.inventory_panel_out()
	is_interacting = false
