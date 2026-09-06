extends VBoxContainer

@onready var title_label: Label = %Title
@onready var value_label: Label = %Value


func set_data(title: String, value: String) -> void:
	title_label.text = title
	value_label.text = value
