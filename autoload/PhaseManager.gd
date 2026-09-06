extends Node

const RUN_PROGRESSION_PROFILE := preload("res://data/progression/run_progression_profile.tres")

var battle_time := 0
var battle_time_remaining := 30
var current_level : int = 0 :
	set(value):
		current_level = maxi(value, 0)

const REST := "rest"
const PREPARE := REST # Compatibility name for rest-only management code.
const SETTLEMENT := "settlement"
const PROTOCOL_SELECTION := "protocol_selection"
const BATTLE_STARTING := "battle_starting"
const BATTLE := "battle"
const GAMEOVER := "gameover"
const RUN_COMPLETE := "run_complete"
const RUN_STATE_ACTIVE := &"active"
const RUN_STATE_COMPLETE := &"run_complete"
const RUN_STATE_ENDLESS := &"endless"
const BATTLE_RUNTIME_TRANSIENT_GROUP := &"battle_runtime_transient"
const MAX_PACING_EVENTS := 256
var time_out = 30

var phase_list := [REST, SETTLEMENT, PROTOCOL_SELECTION, BATTLE_STARTING, BATTLE, GAMEOVER, RUN_COMPLETE]
var phase := REST:
	get:
		return phase
	set(value):
		if value in phase_list:
			phase = value

signal phase_changed(new_phase: String)
signal pre_enter_prepare_loot
signal post_battle_collect_gate_changed(blocking: bool)
signal pacing_event_recorded(event: Dictionary)

var post_battle_collect_gate_timeout_sec: float = 2.0
var _post_battle_collect_gate_active := false
var _post_battle_collect_gate_token: int = 0
var _settlement_check_scheduled := false
var _rest_protocol_consumed_level := -1
var _protocol_selection_origin := ""
var _last_completed_level_index := -1
var _settlement_type: StringName = &"quick"
var endless_mode := false
var _pacing_events: Array[Dictionary] = []
var _run_started_msec := 0
var _endless_entry_rest_available := false
var _run_state: StringName = RUN_STATE_ACTIVE

func _ready() -> void:
	RUN_PROGRESSION_PROFILE.sanitize()
	phase_changed.connect(_record_phase_pacing_event)
	reset_pacing_telemetry()


func record_pacing_event(event_name: StringName, payload: Dictionary = {}) -> void:
	var event := {
		"name": event_name,
		"elapsed_msec": Time.get_ticks_msec() - _run_started_msec,
		"level_index": current_level,
		"phase": current_state(),
		"payload": payload.duplicate(true),
	}
	_pacing_events.append(event)
	if _pacing_events.size() > MAX_PACING_EVENTS:
		_pacing_events.pop_front()
	pacing_event_recorded.emit(event.duplicate(true))


func get_pacing_events() -> Array[Dictionary]:
	return _pacing_events.duplicate(true)


func reset_pacing_telemetry() -> void:
	_pacing_events.clear()
	_run_started_msec = Time.get_ticks_msec()


func _record_phase_pacing_event(new_phase: String) -> void:
	match new_phase:
		BATTLE_STARTING: record_pacing_event(&"battle_deployment_started")
		BATTLE: record_pacing_event(&"battle_started")
		SETTLEMENT: record_pacing_event(&"battle_completed", {"settlement_type": get_settlement_type()})
		REST: record_pacing_event(&"chapter_rest_entered", {"settlement_type": get_settlement_type()})
		RUN_COMPLETE: record_pacing_event(&"run_completed")
		GAMEOVER: record_pacing_event(&"run_failed")

func current_state() -> String:
	return phase

func enter_settlement() -> void:
	if phase != BATTLE:
		return
	cleanup_battle_runtime_transients()
	var previous_phase := phase
	pre_enter_prepare_loot.emit()
	if previous_phase == BATTLE:
		begin_post_battle_collect_gate(post_battle_collect_gate_timeout_sec)
	if previous_phase == BATTLE:
		PlayerData.run_completed_levels += 1
		if PlayerData.weapon_progress_this_battle:
			PlayerData.rounds_without_weapon_progress = 0
		else:
			PlayerData.record_battle_without_weapon_progress()
		PlayerData.weapon_progress_this_battle = false
	_last_completed_level_index = current_level
	_settlement_type = RUN_PROGRESSION_PROFILE.get_settlement_type_for_completed_level(_last_completed_level_index)
	current_level += 1
	if not endless_mode and current_level > RUN_PROGRESSION_PROFILE.final_level_index:
		_run_state = RUN_STATE_COMPLETE
	phase = SETTLEMENT
	phase_changed.emit(phase)
	SaveManager.commit_battle_success()
	request_settlement_completion_check()

func cleanup_battle_runtime_transients() -> void:
	if not is_inside_tree():
		return
	for transient in get_tree().get_nodes_in_group(BATTLE_RUNTIME_TRANSIENT_GROUP):
		if transient == null or not is_instance_valid(transient):
			continue
		if transient.has_method("cleanup_for_battle_end"):
			transient.call("cleanup_for_battle_end")
		else:
			transient.queue_free()

func enter_prepare() -> void:
	## Legacy entry point retained for older combat callers.
	enter_settlement()

func enter_protocol_selection() -> void:
	if phase not in [SETTLEMENT, REST]:
		return
	_protocol_selection_origin = phase
	phase = PROTOCOL_SELECTION
	phase_changed.emit(phase)

func can_cancel_protocol_selection_to_rest() -> bool:
	return phase == PROTOCOL_SELECTION and _protocol_selection_origin == REST

func return_to_rest_from_protocol_selection() -> void:
	if not can_cancel_protocol_selection_to_rest():
		return
	phase = REST
	phase_changed.emit(phase)

func enter_rest() -> void:
	if phase != PROTOCOL_SELECTION:
		return
	_rest_protocol_consumed_level = current_level
	BattleContractManager.cancel_offer()
	phase = REST
	phase_changed.emit(phase)
	if is_full_shop_open() and GlobalVariables.ui != null and is_instance_valid(GlobalVariables.ui):
		GlobalVariables.ui.reset_purchase_refresh_cost()

func enter_chapter_rest() -> void:
	if phase != SETTLEMENT or _settlement_type != &"chapter":
		return
	_rest_protocol_consumed_level = current_level
	BattleContractManager.cancel_offer()
	phase = REST
	phase_changed.emit(phase)
	if GlobalVariables.ui != null and is_instance_valid(GlobalVariables.ui):
		GlobalVariables.ui.reset_purchase_refresh_cost()

func enter_battle_starting() -> void:
	if phase != PROTOCOL_SELECTION:
		return
	complete_post_battle_collect_gate()
	_endless_entry_rest_available = false
	phase = BATTLE_STARTING
	phase_changed.emit(phase)

func is_full_shop_open() -> bool:
	return _endless_entry_rest_available \
		or (PlayerData.run_completed_levels > 0 and PlayerData.run_completed_levels % 3 == 0)

func is_rest_protocol_available() -> bool:
	return is_full_shop_open() and _rest_protocol_consumed_level != current_level

func is_rest_phase() -> bool:
	return phase == REST

func is_settlement_phase() -> bool:
	return phase == SETTLEMENT

func get_settlement_type() -> StringName:
	return _settlement_type

func get_last_completed_level_index() -> int:
	return _last_completed_level_index

func get_progression_profile() -> Resource:
	return RUN_PROGRESSION_PROFILE

func get_current_chapter() -> Resource:
	return RUN_PROGRESSION_PROFILE.get_chapter_for_level(current_level)

func is_main_run_complete() -> bool:
	return _run_state == RUN_STATE_COMPLETE

func get_run_state() -> StringName:
	return _run_state

func is_endless_entry_rest_pending() -> bool:
	return _run_state == RUN_STATE_ENDLESS and _endless_entry_rest_available

func export_progression_save_state() -> Dictionary:
	return {
		"schema_version": 1,
		"run_state": str(_run_state),
		"endless_entry_rest_pending": is_endless_entry_rest_pending(),
	}

func import_progression_save_state(saved_state: Dictionary, legacy_endless_mode: bool = false) -> void:
	var has_explicit_state := saved_state.has("run_state")
	var restored_state := StringName(str(saved_state.get("run_state", "")))
	if restored_state not in [RUN_STATE_ACTIVE, RUN_STATE_COMPLETE, RUN_STATE_ENDLESS]:
		if legacy_endless_mode:
			restored_state = RUN_STATE_ENDLESS
		elif current_level > RUN_PROGRESSION_PROFILE.final_level_index:
			restored_state = RUN_STATE_COMPLETE
		else:
			restored_state = RUN_STATE_ACTIVE
	_run_state = restored_state
	endless_mode = _run_state == RUN_STATE_ENDLESS
	if has_explicit_state:
		_endless_entry_rest_available = endless_mode and bool(saved_state.get("endless_entry_rest_pending", false))
	else:
		# Legacy saves only persisted endless_mode. At the first post-finale level,
		# preserve the one-time full rest that choosing endless mode grants.
		_endless_entry_rest_available = endless_mode \
			and current_level == RUN_PROGRESSION_PROFILE.final_level_index + 1
	phase = RUN_COMPLETE if _run_state == RUN_STATE_COMPLETE else REST

func is_protocol_selection_phase() -> bool:
	return phase == PROTOCOL_SELECTION

func can_configure_loadout() -> bool:
	return phase == REST

func can_accept_reward_loadout_change() -> bool:
	return phase == SETTLEMENT

func enter_battle() -> void:
	if phase != BATTLE_STARTING:
		return
	complete_post_battle_collect_gate()
	PlayerData.weapon_progress_this_battle = false
	phase = BATTLE
	phase_changed.emit(phase)

func enter_gameover() -> void:
	cleanup_battle_runtime_transients()
	complete_post_battle_collect_gate()
	phase = GAMEOVER
	phase_changed.emit(phase)

func enter_run_complete() -> void:
	if phase != SETTLEMENT:
		return
	if _run_state != RUN_STATE_COMPLETE:
		# Keep the transition API robust for callers/tests that restore the legacy
		# level boundary directly before explicit run-state persistence existed.
		if endless_mode or current_level <= RUN_PROGRESSION_PROFILE.final_level_index:
			return
		_run_state = RUN_STATE_COMPLETE
	cleanup_battle_runtime_transients()
	complete_post_battle_collect_gate()
	phase = RUN_COMPLETE
	phase_changed.emit(phase)

func continue_into_endless() -> void:
	if phase != RUN_COMPLETE:
		return
	endless_mode = true
	_run_state = RUN_STATE_ENDLESS
	_endless_entry_rest_available = true
	BattleContractManager.reset_runtime_state()
	phase = REST
	phase_changed.emit(phase)

func begin_post_battle_collect_gate(timeout_sec: float) -> void:
	_post_battle_collect_gate_token += 1
	_post_battle_collect_gate_active = true
	post_battle_collect_gate_changed.emit(true)
	var token := _post_battle_collect_gate_token
	_complete_post_battle_collect_gate_after_timeout(token, maxf(timeout_sec, 0.0))

func complete_post_battle_collect_gate() -> void:
	if not _post_battle_collect_gate_active:
		return
	_post_battle_collect_gate_active = false
	_post_battle_collect_gate_token += 1
	post_battle_collect_gate_changed.emit(false)
	request_settlement_completion_check()

func is_post_battle_collect_gate_active() -> bool:
	return _post_battle_collect_gate_active

func _complete_post_battle_collect_gate_after_timeout(token: int, timeout_sec: float) -> void:
	if timeout_sec > 0.0:
		await get_tree().create_timer(timeout_sec).timeout
	else:
		await get_tree().process_frame
	if token != _post_battle_collect_gate_token:
		return
	complete_post_battle_collect_gate()

func request_settlement_completion_check() -> void:
	if phase != SETTLEMENT or _settlement_check_scheduled:
		return
	_settlement_check_scheduled = true
	call_deferred("_try_complete_settlement")

func _try_complete_settlement() -> void:
	_settlement_check_scheduled = false
	if phase != SETTLEMENT or is_post_battle_collect_gate_active():
		return
	if RewardDraftRuntime != null and RewardDraftRuntime.is_standard_draft_blocking_interactions():
		return
	if TaskRewardManager != null and TaskRewardManager.is_task_reward_blocking_interactions():
		return
	if InventoryData != null and not InventoryData.pending_transactions.is_empty():
		return
	var ui = GlobalVariables.ui
	if ui != null and is_instance_valid(ui) \
			and ui.has_method("has_pending_blocking_transaction") \
			and bool(ui.call("has_pending_blocking_transaction")):
		return
	if is_main_run_complete():
		enter_run_complete()
		return
	if _settlement_type == &"chapter":
		enter_chapter_rest()
		return
	enter_protocol_selection()

func start_battle_timer(duration_sec: int) -> void:
	time_out = maxi(duration_sec, 1)
	battle_time = 0
	battle_time_remaining = time_out

func advance_battle_time(delta_sec: int = 1) -> void:
	var safe_delta := maxi(delta_sec, 0)
	battle_time += safe_delta
	battle_time_remaining = maxi(time_out - battle_time, 0)

func get_battle_time_remaining() -> int:
	return maxi(battle_time_remaining, 0)

func reset_runtime_state() -> void:
	cleanup_battle_runtime_transients()
	battle_time = 0
	battle_time_remaining = 30
	current_level = 0
	time_out = 30
	phase = REST
	_settlement_check_scheduled = false
	_rest_protocol_consumed_level = -1
	_protocol_selection_origin = ""
	_last_completed_level_index = -1
	_settlement_type = &"quick"
	endless_mode = false
	_endless_entry_rest_available = false
	_run_state = RUN_STATE_ACTIVE
	complete_post_battle_collect_gate()
	reset_pacing_telemetry()
