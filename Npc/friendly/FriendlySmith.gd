extends FriendlyNPC

#@onready var ui : UI = get_tree().get_first_node_in_group("ui")

func panel_move_in() -> void:
	#ui.upgrade_panel_in()
	GlobalVariables.ui.upg_panel_in()
	is_interacting = true
	
func panel_move_out() -> void:
	#ui.upgrade_panel_out()
	GlobalVariables.ui.upg_panel_out()
	GlobalVariables.ui.gf_panel_out()
	is_interacting = false
