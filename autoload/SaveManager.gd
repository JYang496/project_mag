extends Node

signal save_completed(reason: StringName, result: Dictionary)
signal save_restored(result: Dictionary)

const FORMAT_VERSION := 1
const SLOT_DIRECTORY := "user://saves/slot_0"
const RUN_PATH := SLOT_DIRECTORY + "/run.json"
const BACKUP_PATH := SLOT_DIRECTORY + "/run.backup.json"
const CHECKPOINT_PATH := SLOT_DIRECTORY + "/checkpoint.json"
const MANIFEST_PATH := SLOT_DIRECTORY + "/manifest.json"

const STATE_REST_AREA := "rest_area"
const STATE_BATTLE := "battle_in_progress"
const STATE_GAME_OVER_PENDING := "game_over_pending"

var _revision := 0
var _save_in_progress := false
var _save_dirty := false
var _pending_restore: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_DIRECTORY))

func has_run() -> bool:
	return FileAccess.file_exists(RUN_PATH) or FileAccess.file_exists(BACKUP_PATH)

func clear_run() -> void:
	_pending_restore.clear()
	_revision = 0
	_save_dirty = false
	_delete_file(CHECKPOINT_PATH)
	_delete_file(RUN_PATH)
	_delete_file(BACKUP_PATH)
	_delete_file(MANIFEST_PATH)

func create_new_run() -> Dictionary:
	clear_run()
	return save_run(&"new_run", STATE_REST_AREA)

func save_run(reason: StringName = &"autosave", state: String = STATE_REST_AREA) -> Dictionary:
	if _save_in_progress:
		_save_dirty = true
		return _result(true, "queued")
	_save_in_progress = true
	var payload := _build_document(state)
	var result := _write_document_atomic(RUN_PATH, BACKUP_PATH, payload)
	if bool(result.get("ok", false)):
		_write_manifest(payload)
	_save_in_progress = false
	save_completed.emit(reason, result)
	if _save_dirty:
		_save_dirty = false
		call_deferred("save_run", &"coalesced", state)
	return result

func create_battle_checkpoint() -> Dictionary:
	var checkpoint := _build_document(STATE_REST_AREA)
	var result := _write_document_atomic(CHECKPOINT_PATH, "", checkpoint)
	if not bool(result.get("ok", false)):
		return result
	return save_run(&"battle_started", STATE_BATTLE)

func commit_battle_success() -> Dictionary:
	var result := save_run(&"battle_completed", STATE_REST_AREA)
	if bool(result.get("ok", false)):
		_delete_file(CHECKPOINT_PATH)
	return result

func mark_game_over_pending() -> Dictionary:
	return save_run(&"game_over", STATE_GAME_OVER_PENDING)

func prepare_continue() -> Dictionary:
	var run_result := _read_valid_document(RUN_PATH)
	if not bool(run_result.get("ok", false)):
		run_result = _read_valid_document(BACKUP_PATH)
		if bool(run_result.get("ok", false)):
			run_result["recovered_from_backup"] = true
	if not bool(run_result.get("ok", false)):
		return run_result
	var document: Dictionary = run_result.get("data", {})
	var saved_state := str(document.get("state", STATE_REST_AREA))
	if saved_state in [STATE_BATTLE, STATE_GAME_OVER_PENDING]:
		var checkpoint_result := _read_valid_document(CHECKPOINT_PATH)
		if bool(checkpoint_result.get("ok", false)):
			document = checkpoint_result.get("data", {})
			run_result["restored_checkpoint"] = true
	_pending_restore = document.duplicate(true)
	_revision = maxi(int(document.get("revision", 0)), 0)
	return run_result

func restore_before_world() -> Dictionary:
	if _pending_restore.is_empty():
		return _result(false, "no_pending_restore")
	var run: Dictionary = _pending_restore.get("run", {})
	PlayerData.select_mecha_id = int(run.get("selected_mecha_id", PlayerData.select_mecha_id))
	PhaseManager.current_level = maxi(int(run.get("level", 0)), 0)
	CellEffectRuntime.import_save_state(run.get("cell_effects", {}) as Dictionary)
	CellTaskModuleRuntime.import_save_state(run.get("cell_tasks", {}) as Dictionary)
	TaskRewardManager.import_save_state(run.get("task_rewards", {}) as Dictionary)
	RewardDraftRuntime.restore_battle_rollback_snapshot(run.get("reward_draft", {}) as Dictionary)
	BattleContractManager.import_save_state(run.get("battle_contract", {}) as Dictionary)
	return _result(true)

func restore_after_player_spawn() -> Dictionary:
	if _pending_restore.is_empty():
		return _result(false, "no_pending_restore")
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return _result(false, "player_not_ready")
	var run: Dictionary = _pending_restore.get("run", {})
	TaskRewardManager.restore_run_snapshot_after_player_spawn(run.get("core", {}) as Dictionary)
	_pending_restore.clear()
	var result := _result(true)
	save_restored.emit(result)
	return result

func _build_document(state: String) -> Dictionary:
	_revision += 1
	return {
		"format_version": FORMAT_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"slot_id": "slot_0",
		"revision": _revision,
		"saved_at_utc": Time.get_datetime_string_from_system(true),
		"state": state,
		"run": {
			"selected_mecha_id": str(PlayerData.select_mecha_id),
			"level": int(PhaseManager.current_level),
			"core": TaskRewardManager.build_run_snapshot(),
			"cell_effects": CellEffectRuntime.export_save_state(),
			"cell_tasks": CellTaskModuleRuntime.export_save_state(),
			"task_rewards": TaskRewardManager.export_save_state(),
			"reward_draft": RewardDraftRuntime.build_battle_rollback_snapshot(),
			"battle_contract": BattleContractManager.export_save_state(),
		},
	}

func _write_document_atomic(path: String, backup_path: String, payload: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_DIRECTORY))
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _result(false, "open_temp_failed")
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()
	var verify := _read_valid_document(temp_path)
	if not bool(verify.get("ok", false)):
		_delete_file(temp_path)
		return _result(false, "verify_failed")
	if backup_path != "" and FileAccess.file_exists(path):
		_delete_file(backup_path)
		var backup_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_path))
		if backup_error != OK:
			_delete_file(temp_path)
			return _result(false, "backup_failed")
	elif FileAccess.file_exists(path):
		_delete_file(path)
	var replace_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
	if replace_error != OK:
		return _result(false, "replace_failed")
	return _result(true)

func _read_valid_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(false, "not_found")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _result(false, "open_failed")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _result(false, "invalid_json")
	var parsed = parser.data
	if not (parsed is Dictionary):
		return _result(false, "invalid_json")
	var data := parsed as Dictionary
	if int(data.get("format_version", 0)) != FORMAT_VERSION or not (data.get("run", null) is Dictionary):
		return _result(false, "unsupported_format")
	return {"ok": true, "error_code": "", "data": data}

func _write_manifest(document: Dictionary) -> void:
	var manifest := {
		"slot_id": "slot_0",
		"revision": int(document.get("revision", 0)),
		"saved_at_utc": str(document.get("saved_at_utc", "")),
		"state": str(document.get("state", STATE_REST_AREA)),
		"level": int((document.get("run", {}) as Dictionary).get("level", 0)),
	}
	var file := FileAccess.open(MANIFEST_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(manifest))
	file.close()
	_delete_file(MANIFEST_PATH)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(MANIFEST_PATH + ".tmp"), ProjectSettings.globalize_path(MANIFEST_PATH))

func _result(ok: bool, error_code: String = "") -> Dictionary:
	return {
		"ok": ok,
		"error_code": error_code,
		"recovered_from_backup": false,
		"restored_checkpoint": false,
	}

func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
