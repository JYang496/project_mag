extends PanelContainer

@onready var title_label: Label = %Title


func set_data(title: String, accent: Color) -> void:
	if title_label == null:
		title_label = get_node("Margin/Title") as Label
	title_label.text = title
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = accent
	add_theme_stylebox_override("panel", style)
