extends HBoxContainer

@onready var icon_host: Control = %IconHost
@onready var text_host: Control = %TextHost

func set_content(icon: Control, text_column: Control) -> void:
	if icon_host == null:
		icon_host = get_node("IconHost") as Control
		text_host = get_node("TextHost") as Control
	icon_host.add_child(icon)
	text_host.add_child(text_column)
