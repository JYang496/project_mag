extends FriendlyNPC

#@onready var ui : UI = get_tree().get_first_node_in_group("ui")

func panel_move_in() -> void:
	GlobalVariables.ui.smith_menu_in()
	is_interacting = true
	
func panel_move_out() -> void:
	GlobalVariables.ui.smith_menu_out()
	is_interacting = false
