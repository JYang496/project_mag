extends Button

#@onready var ui : UI = get_tree().get_first_node_in_group("ui")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_button_up() -> void:
	GlobalVariables.ui.inventory_panel_out()
	GlobalVariables.ui.module_panel_in()
