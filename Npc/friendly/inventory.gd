extends FriendlyNPC
class_name Inventory

@onready var ui = get_tree().get_first_node_in_group("ui")

# This NPC provides weapons
func _ready():
	pass


func panel_move_in() -> void:
	is_interacting = true
	#ui.shopping_panel_in()


func panel_move_out() -> void:
	#ui.shopping_panel_out()
	is_interacting = false
