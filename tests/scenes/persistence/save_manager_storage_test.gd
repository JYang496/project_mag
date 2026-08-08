extends Node

var _failures := PackedStringArray()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	DataHandler.prepare_world_data(true)
	CellEffectRuntime.load_definitions()
	CellTaskModuleRuntime.load_definitions()
	PlayerData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PlayerData.player_gold = 12
	PhaseManager.current_level = 2
	_expect(bool(SaveManager.create_new_run().get("ok", false)), "new run must be written")
	PlayerData.player_gold = 34
	PhaseManager.current_level = 3
	_expect(bool(SaveManager.save_run(&"test").get("ok", false)), "second run revision must be written")
	_expect(FileAccess.file_exists(SaveManager.RUN_PATH), "run file must exist")
	_expect(FileAccess.file_exists(SaveManager.BACKUP_PATH), "backup file must exist")

	var corrupt := FileAccess.open(SaveManager.RUN_PATH, FileAccess.WRITE)
	_expect(corrupt != null, "run file must be writable for corruption probe")
	if corrupt != null:
		corrupt.store_string("{broken")
		corrupt.close()
	var fallback := SaveManager.prepare_continue()
	_expect(bool(fallback.get("ok", false)), "backup must recover a corrupt primary save")
	_expect(bool(fallback.get("recovered_from_backup", false)), "backup recovery must be reported")

	PlayerData.player_gold = 55
	PhaseManager.current_level = 4
	_expect(bool(SaveManager.create_battle_checkpoint().get("ok", false)), "battle checkpoint must be written")
	var checkpoint_continue := SaveManager.prepare_continue()
	_expect(bool(checkpoint_continue.get("restored_checkpoint", false)), "battle state must continue from checkpoint")
	var pending: Dictionary = SaveManager.get("_pending_restore")
	var run: Dictionary = pending.get("run", {})
	var core: Dictionary = run.get("core", {})
	var player: Dictionary = core.get("player", {})
	_expect(int(run.get("level", -1)) == 4, "checkpoint level must roundtrip")
	_expect(int(player.get("gold", -1)) == 55, "checkpoint player data must roundtrip")
	PlayerData.player = null
	var early_restore := SaveManager.restore_after_player_spawn()
	_expect(not bool(early_restore.get("ok", true)) and str(early_restore.get("error_code", "")) == "player_not_ready", "player-bound restore must reject calls before player spawn")

	# A saved death state must also continue from the battle checkpoint instead
	# of restoring zero-HP battle data as a playable rest-area run.
	_expect(bool(SaveManager.mark_game_over_pending().get("ok", false)), "game-over marker must be written")
	var game_over_continue := SaveManager.prepare_continue()
	_expect(bool(game_over_continue.get("restored_checkpoint", false)), "game-over continue must recover the pre-battle checkpoint")
	_test_progression_state_roundtrips()
	_test_legacy_progression_defaults()
	_cleanup()
	_finish()

func _test_progression_state_roundtrips() -> void:
	_cleanup()
	PhaseManager.reset_runtime_state()
	PhaseManager.current_level = int(PhaseManager.get_progression_profile().final_level_index)
	PhaseManager.phase = PhaseManager.BATTLE
	PhaseManager.enter_settlement()
	_expect(PhaseManager.get_run_state() == PhaseManager.RUN_STATE_COMPLETE, "final victory must set an explicit completed run state before saving")
	_expect(bool(SaveManager.prepare_continue().get("ok", false)), "final victory save must be readable")
	PhaseManager.reset_runtime_state()
	_expect(bool(SaveManager.restore_before_world().get("ok", false)), "completed run state must restore before world creation")
	_expect(PhaseManager.current_state() == PhaseManager.RUN_COMPLETE, "completed run save must restore the run-complete phase")
	_expect(PhaseManager.get_run_state() == PhaseManager.RUN_STATE_COMPLETE and not PhaseManager.endless_mode, "completed run save must not silently enter endless mode")

	PhaseManager.continue_into_endless()
	_expect(PhaseManager.is_endless_entry_rest_pending(), "choosing endless must grant its one-time entry rest")
	_expect(bool(SaveManager.save_run(&"endless_roundtrip").get("ok", false)), "endless entry state must save")
	_expect(bool(SaveManager.prepare_continue().get("ok", false)), "endless entry save must be readable")
	PhaseManager.reset_runtime_state()
	_expect(bool(SaveManager.restore_before_world().get("ok", false)), "endless entry state must restore before world creation")
	_expect(PhaseManager.get_run_state() == PhaseManager.RUN_STATE_ENDLESS and PhaseManager.endless_mode, "endless mode must roundtrip explicitly")
	_expect(PhaseManager.is_endless_entry_rest_pending() and PhaseManager.is_full_shop_open(), "endless entry rest and full shop must survive a save roundtrip")
	PhaseManager.phase = PhaseManager.PROTOCOL_SELECTION
	PhaseManager.enter_battle_starting()
	_expect(not PhaseManager.is_endless_entry_rest_pending(), "starting the next battle must consume the endless entry rest")

func _test_legacy_progression_defaults() -> void:
	_cleanup()
	PhaseManager.reset_runtime_state()
	PhaseManager.current_level = int(PhaseManager.get_progression_profile().final_level_index) + 1
	_expect(bool(SaveManager.save_run(&"legacy_fixture").get("ok", false)), "legacy compatibility fixture must save")
	_expect(_rewrite_primary_as_legacy(false), "legacy completed-run fixture must be writable")
	_expect(bool(SaveManager.prepare_continue().get("ok", false)), "legacy completed-run save must be readable")
	PhaseManager.reset_runtime_state()
	_expect(bool(SaveManager.restore_before_world().get("ok", false)), "legacy completed-run save must restore")
	_expect(PhaseManager.current_state() == PhaseManager.RUN_COMPLETE and PhaseManager.get_run_state() == PhaseManager.RUN_STATE_COMPLETE, "legacy level beyond finale must default to completed run")

	_expect(bool(SaveManager.save_run(&"legacy_endless_fixture").get("ok", false)), "legacy endless fixture must save")
	_expect(_rewrite_primary_as_legacy(true), "legacy endless fixture must be writable")
	_expect(bool(SaveManager.prepare_continue().get("ok", false)), "legacy endless save must be readable")
	PhaseManager.reset_runtime_state()
	_expect(bool(SaveManager.restore_before_world().get("ok", false)), "legacy endless save must restore")
	_expect(PhaseManager.get_run_state() == PhaseManager.RUN_STATE_ENDLESS and PhaseManager.endless_mode, "legacy endless_mode must map to explicit endless state")
	_expect(PhaseManager.is_endless_entry_rest_pending(), "legacy endless save at the first post-finale level must retain entry rest by compatibility default")

func _rewrite_primary_as_legacy(endless: bool) -> bool:
	var file := FileAccess.open(SaveManager.RUN_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return false
	var document := parsed as Dictionary
	var run: Dictionary = document.get("run", {})
	run.erase("progression_state")
	run["level"] = int(PhaseManager.get_progression_profile().final_level_index) + 1
	run["endless_mode"] = endless
	document["run"] = run
	file = FileAccess.open(SaveManager.RUN_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(document))
	file.close()
	return true

func _cleanup() -> void:
	for path in [SaveManager.RUN_PATH, SaveManager.BACKUP_PATH, SaveManager.CHECKPOINT_PATH, SaveManager.MANIFEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if FileAccess.file_exists(path + ".tmp"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PASS save manager storage")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("FAIL save manager storage")
	get_tree().quit(1)
