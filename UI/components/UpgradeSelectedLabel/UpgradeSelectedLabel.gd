extends Label


func set_selected(selected: bool, selected_text: String = "") -> void:
	visible = selected
	text = selected_text
