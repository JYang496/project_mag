extends FriendlyNPC
class_name Inventory

#@onready var ui : UI = get_tree().get_first_node_in_group("ui")

# This NPC provides weapons
func _ready():
	pass

func panel_move_in() -> void:
	is_interacting = true
	GlobalVariables.ui.inventory_panel_in()


func panel_move_out() -> void:
	GlobalVariables.ui.inv_mod_panel_out()
	is_interacting = false
