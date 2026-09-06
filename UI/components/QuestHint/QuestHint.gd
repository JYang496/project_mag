extends Label


func set_hint_text(value: String) -> void:
	text = value
	visible = not value.strip_edges().is_empty()
