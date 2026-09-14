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
var rest_area_service_intro_seen := false
var _reward_transaction_active := false
var _reward_write_thread: Thread
var _save_epoch := 0
var _queued_reward_save: Dictionary = {}

# Capture scene state on the main thread; only detached data and file operations
# cross the worker boundary. The transaction lock remains held until completion.
func commit_prepared_reward_async(reason: StringName) -> Dictionary:
	if not _reward_transaction_active or _save_in_progress:
		return _result(false, "no_reward_transaction")
	_save_in_progress = true
	var epoch := _save_epoch
	var payload := _build_document(STATE_BATTLE if PhaseManager.current_state() == PhaseManager.BATTLE else STATE_REST_AREA).duplicate(true)
	var worker := Thread.new()
	_reward_write_thread = worker
	var error := worker.start(_write_prepared_document.bind(payload))
	if error != OK:
		_reward_write_thread = null
		_save_in_progress = false
		return _result(false, "worker_start_failed")
	while worker.is_alive():
		await get_tree().process_frame
	if epoch != _save_epoch:
		return _result(false, "cleared")
	var result: Dictionary = worker.wait_to_finish()
	_reward_write_thread = null
	_save_in_progress = false
	save_completed.emit(reason, result)
	return result

static func _write_prepared_document(payload: Dictionary) -> Dictionary:
	var result := _write_document_atomic(RUN_PATH, BACKUP_PATH, payload)
	if bool(result.get("ok", false)):
		_write_manifest(payload)
	return result

func _exit_tree() -> void:
	if _reward_write_thread != null and _reward_write_thread.is_started():
		_reward_write_thread.wait_to_finish()

func begin_reward_transaction() -> bool:
	if _save_in_progress or _reward_transaction_active:
		return false
	_reward_transaction_active = true
	return true

func commit_reward_transaction(reason: StringName) -> Dictionary:
	if not _reward_transaction_active:
		return _result(false, "no_reward_transaction")
	# Keep the lock through callbacks; the caller releases it after rollback/commit.
	_save_in_progress = true
	var payload := _build_document(STATE_BATTLE if PhaseManager.current_state() == PhaseManager.BATTLE else STATE_REST_AREA)
	var result := _write_document_atomic(RUN_PATH, BACKUP_PATH, payload)
	if bool(result.get("ok", false)):
		_write_manifest(payload)
	_save_in_progress = false
	save_completed.emit(reason, result)
	return result

func abort_reward_transaction() -> void:
	_reward_transaction_active = false
	if _save_dirty and not _save_in_progress:
		_save_dirty = false
		if not _queued_reward_save.is_empty():
			var queued := _queued_reward_save
			_queued_reward_save = {}
			_flush_queued_reward_save.call_deferred(queued, _save_epoch)
		else:
			call_deferred("save_run", &"coalesced", STATE_BATTLE if PhaseManager.current_state() == PhaseManager.BATTLE else STATE_REST_AREA)

func _flush_queued_reward_save(queued: Dictionary, epoch: int) -> void:
	if epoch != _save_epoch:
		return
	var result := save_run(queued.reason, queued.state)
	if bool(queued.get("clear_checkpoint", false)) and bool(result.get("ok", false)) and not bool(result.get("queued", false)):
		_delete_file(CHECKPOINT_PATH)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_DIRECTORY))

func has_run() -> bool:
	return FileAccess.file_exists(RUN_PATH) or FileAccess.file_exists(BACKUP_PATH)

func clear_run() -> void:
	# Prevent an outgoing preparation worker from recreating a cleared slot.
	if _reward_write_thread != null and _reward_write_thread.is_started():
		_reward_write_thread.wait_to_finish()
	_reward_write_thread = null
	_save_epoch += 1
	_save_in_progress = false
	_reward_transaction_active = false
	_pending_restore.clear()
	_revision = 0
	_save_dirty = false
	_queued_reward_save.clear()
	rest_area_service_intro_seen = false
	_delete_file(CHECKPOINT_PATH)
	_delete_file(RUN_PATH)
	_delete_file(BACKUP_PATH)
	_delete_file(MANIFEST_PATH)

func create_new_run() -> Dictionary:
	clear_run()
	return save_run(&"new_run", STATE_REST_AREA)

func save_run(reason: StringName = &"autosave", state: String = STATE_REST_AREA) -> Dictionary:
	if _reward_transaction_active:
		if _reward_write_thread != null:
			_save_dirty = true
			_queued_reward_save = {"reason": reason, "state": state, "clear_checkpoint": reason == &"battle_completed" or bool(_queued_reward_save.get("clear_checkpoint", false))}
			return _result(true).merged({"queued": true})
		return _result(false, "reward_transaction_in_progress")
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
	if bool(result.get("ok", false)) and not bool(result.get("queued", false)):
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
	var saved_mecha_id := str(run.get("selected_mecha_id", PlayerData.select_mecha_id))
	if DataHandler.read_mecha_data(saved_mecha_id) == null:
		push_warning("Saved mecha id=%s is unavailable; falling back to mecha id=1." % saved_mecha_id)
		saved_mecha_id = "1"
	PlayerData.select_mecha_id = int(saved_mecha_id)
	PhaseManager.current_level = maxi(int(run.get("level", 0)), 0)
	PhaseManager.import_progression_save_state(
		run.get("progression_state", {}) as Dictionary,
		bool(run.get("endless_mode", false))
	)
	CellEffectRuntime.import_save_state(run.get("cell_effects", {}) as Dictionary)
	CellTaskModuleRuntime.import_save_state(run.get("cell_tasks", {}) as Dictionary)
	TaskRewardManager.import_save_state(run.get("task_rewards", {}) as Dictionary)
	RewardDraftRuntime.restore_battle_rollback_snapshot(run.get("reward_draft", {}) as Dictionary)
	BattleContractManager.import_save_state(run.get("battle_contract", {}) as Dictionary)
	rest_area_service_intro_seen = bool(run.get("rest_area_service_intro_seen", false))
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
			"progression_state": PhaseManager.export_progression_save_state(),
			# Retained during the schema transition for older readers.
			"endless_mode": bool(PhaseManager.endless_mode),
			"core": TaskRewardManager.build_run_snapshot(),
			"cell_effects": CellEffectRuntime.export_save_state(),
			"cell_tasks": CellTaskModuleRuntime.export_save_state(),
			"task_rewards": TaskRewardManager.export_save_state(),
			"reward_draft": RewardDraftRuntime.build_battle_rollback_snapshot(),
			"battle_contract": BattleContractManager.export_save_state(),
			"rest_area_service_intro_seen": rest_area_service_intro_seen,
		},
	}

func mark_rest_area_service_intro_seen() -> void:
	if rest_area_service_intro_seen:
		return
	rest_area_service_intro_seen = true
	call_deferred("save_run", &"rest_area_service_intro", STATE_REST_AREA)

static func _write_document_atomic(path: String, backup_path: String, payload: Dictionary) -> Dictionary:
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

static func _read_valid_document(path: String) -> Dictionary:
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

static func _write_manifest(document: Dictionary) -> void:
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

static func _result(ok: bool, error_code: String = "") -> Dictionary:
	return {
		"ok": ok,
		"error_code": error_code,
		"recovered_from_backup": false,
		"restored_checkpoint": false,
	}

static func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
