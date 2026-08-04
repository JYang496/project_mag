extends Node

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
const BATTLE_RUNTIME_TRANSIENT_GROUP := &"battle_runtime_transient"
var time_out = 30

var phase_list := [REST, SETTLEMENT, PROTOCOL_SELECTION, BATTLE_STARTING, BATTLE, GAMEOVER]
var phase := REST:
	get:
		return phase
	set(value):
		if value in phase_list:
			phase = value

signal phase_changed(new_phase: String)
signal pre_enter_prepare_loot
signal post_battle_collect_gate_changed(blocking: bool)

var post_battle_collect_gate_timeout_sec: float = 2.0
var _post_battle_collect_gate_active := false
var _post_battle_collect_gate_token: int = 0
var _settlement_check_scheduled := false
var _rest_protocol_consumed_level := -1
var _protocol_selection_origin := ""

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
	current_level += 1
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

func enter_battle_starting() -> void:
	if phase != PROTOCOL_SELECTION:
		return
	complete_post_battle_collect_gate()
	phase = BATTLE_STARTING
	phase_changed.emit(phase)

func is_full_shop_open() -> bool:
	return PlayerData.run_completed_levels > 0 and PlayerData.run_completed_levels % 3 == 0

func is_rest_protocol_available() -> bool:
	return is_full_shop_open() and _rest_protocol_consumed_level != current_level

func is_rest_phase() -> bool:
	return phase == REST

func is_settlement_phase() -> bool:
	return phase == SETTLEMENT

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
	complete_post_battle_collect_gate()
