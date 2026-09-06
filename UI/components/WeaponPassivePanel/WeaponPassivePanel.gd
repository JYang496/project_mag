extends PanelContainer

@onready var row_list: VBoxContainer = %RowList


func set_has_content(has_content: bool, requested_visible: bool) -> void:
	visible = has_content and requested_visible
