extends Button


func set_data(label_text: String, unavailable: bool = false) -> void:
	text = label_text
	disabled = unavailable
