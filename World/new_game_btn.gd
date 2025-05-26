extends Control

func _on_pressed() -> void:
	var save_data : SaveData = SaveData.new()
	DataHandler.save_game(save_data)
	DataHandler.load_game()
