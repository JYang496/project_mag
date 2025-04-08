extends Button

@onready var ui : UI = get_tree().get_first_node_in_group("ui")
@export_enum("gf","upg") var panel = "gf"

func _on_button_up() -> void:
	match panel:
		"gf":
			ui.inventory_gf.visible = not ui.inventory_gf.visible
			ui.equipped_gf.visible = not ui.equipped_gf.visible
		"upg":
			ui.inventory_upg.visible = not ui.inventory_upg.visible
			ui.equipped_upg.visible = not ui.equipped_upg.visible
