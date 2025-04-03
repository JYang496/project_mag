extends Button

@onready var ui : UI = get_tree().get_first_node_in_group("ui")

func _on_button_up() -> void:
	ui.inventory_gf.visible = not ui.inventory_gf.visible
	ui.equipped_gf.visible = not ui.equipped_gf.visible
