extends PanelContainer

@onready var card_list: VBoxContainer = %CardList


func set_panel_size(target_size: Vector2) -> void:
	custom_minimum_size = target_size
	size = target_size
