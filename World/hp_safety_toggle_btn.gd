extends Button


func _ready() -> void:
	_update_text()


func _pressed() -> void:
	PlayerData.set_hp_safety_for_testing(not PlayerData.testing_keep_hp_above_zero)
	_update_text()


func _update_text() -> void:
	var state = "ON" if PlayerData.testing_keep_hp_above_zero else "OFF"
	text = "Keep HP > 1: %s" % state
