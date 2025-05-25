extends Button


func _on_pressed() -> void:
	print("continue function in progress")
	print(DataHandler.load_game())
