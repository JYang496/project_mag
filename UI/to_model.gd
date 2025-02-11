extends Button

@onready var ui : UI = get_tree().get_first_node_in_group("ui")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_up() -> void:
	ui.inventory_panel_out()
	ui.module_panel_in()
