extends Button

#@onready var ui : UI = get_tree().get_first_node_in_group("ui")
@export_enum("gf","upg") var panel = "gf"

func _on_button_up() -> void:
	match panel:
		"gf":
			GlobalVariables.ui.inventory_gf.visible = not GlobalVariables.ui.inventory_gf.visible
			GlobalVariables.ui.equipped_gf.visible = not GlobalVariables.ui.equipped_gf.visible
		"upg":
			GlobalVariables.ui.inventory_upg.visible = not GlobalVariables.ui.inventory_upg.visible
			GlobalVariables.ui.equipped_upg.visible = not GlobalVariables.ui.equipped_upg.visible
