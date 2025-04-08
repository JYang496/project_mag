extends Button

@onready var ui : UI = get_tree().get_first_node_in_group("ui")

func _on_button_up() -> void:
	ui.upg_panel_out()
	ui.gf_panel_in()
