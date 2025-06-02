extends Control

signal erase_button_pressed

func _on_pressed() -> void:
	DataHandler.new_save()
	erase_button_pressed.emit()
