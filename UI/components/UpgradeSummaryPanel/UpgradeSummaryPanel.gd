extends PanelContainer

@onready var content: VBoxContainer = %Content


func set_title(title: String) -> void:
	%Title.text = title


func add_line(line: Control) -> void:
	content.add_child(line)
