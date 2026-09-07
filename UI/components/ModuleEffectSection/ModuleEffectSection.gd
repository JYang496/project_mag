extends VBoxContainer

@onready var heading: Label = %ModuleEffectHeading

func set_heading(value: String) -> void:
	if heading == null:
		heading = get_node("ModuleEffectHeading") as Label
	heading.text = value
