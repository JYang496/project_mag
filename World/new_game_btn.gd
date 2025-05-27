extends Control

func _on_pressed() -> void:
	var save_data : SaveData = SaveData.new()
	DataHandler.save_game(save_data,"res://Data/savedata/autosave.tres")
	DataHandler.load_game()
