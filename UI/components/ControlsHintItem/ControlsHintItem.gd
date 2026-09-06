extends HBoxContainer

@onready var key_prompt: HBoxContainer = %Key
@onready var action_label: Label = %Action


func set_data(action_text: String) -> void:
	var target := action_label if action_label != null else get_node("Action") as Label
	target.text = action_text
