extends Button


func _ready() -> void:
	_update_text()
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)


func _pressed() -> void:
	PlayerData.set_hp_safety_for_testing(not PlayerData.testing_keep_hp_above_zero)
	_update_text()


func _update_text() -> void:
	var state_key := "ui.common.state.on" if PlayerData.testing_keep_hp_above_zero else "ui.common.state.off"
	var state_text := LocalizationManager.tr_key(state_key, "ON" if PlayerData.testing_keep_hp_above_zero else "OFF")
	text = LocalizationManager.tr_format("ui.start.hp_safety", {"state": state_text}, "Keep HP > 1: %s" % state_text)

func _on_language_changed(_locale: String) -> void:
	_update_text()
