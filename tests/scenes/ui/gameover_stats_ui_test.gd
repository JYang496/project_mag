extends Node

signal test_finished(success: bool)

var _failed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_test")

func _run_test() -> void:
	PlayerData.reset_runtime_state()
	PlayerData.run_total_damage_dealt = 12345
	PlayerData.run_completed_levels = 7
	PlayerData.run_enemy_kills = 89
	PlayerData.run_elite_kills = 6
	PlayerData.run_gold_earned = 456

	var ui_scene := load("res://UI/scenes/UI.tscn") as PackedScene
	_assert_true(ui_scene != null, "UI scene should load.")
	if ui_scene == null:
		_finish()
		return
	var ui := ui_scene.instantiate() as UI
	_assert_true(ui != null, "UI instance should be valid.")
	if ui == null:
		_finish()
		return
	add_child(ui)
	await get_tree().process_frame

	ui.call("_show_game_over")
	var stat_texts := ui.debug_get_game_over_stat_texts()
	_assert_true(stat_texts.size() == 5, "Game over panel should render exactly 5 stat lines.")

	var joined := "\n".join(stat_texts)
	_assert_true(joined.find("12345") != -1, "Total damage line should include configured damage value.")
	_assert_true(joined.find("7") != -1, "Completed levels line should include configured level count.")
	_assert_true(joined.find("89") != -1, "Enemy kills line should include configured kill count.")
	_assert_true(joined.find("6") != -1, "Elite kills line should include configured elite kill count.")
	_assert_true(joined.find("456") != -1, "Gold earned line should include configured gold value.")
	_assert_true(joined.find("Status") == -1 and joined.find("HP:") == -1, "Legacy status text should not appear in the game over stats panel.")

	get_tree().paused = false
	ui.queue_free()
	_finish()

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)

func _finish() -> void:
	get_tree().paused = false
	test_finished.emit(not _failed)
