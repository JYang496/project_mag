extends Node

var battle_time := 0
var battle_time_remaining := 30
var current_level : int = 0 :
	set(value):
		current_level = maxi(value, 0)

const PREPARE := "prepare"
const BATTLE = "battle"
const GAMEOVER = "gameover"
var time_out = 30

var phase_list := [PREPARE,BATTLE,GAMEOVER]
var phase := PREPARE:
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

func current_state() -> String:
	return phase

func enter_prepare() -> void:
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
	phase = PREPARE
	phase_changed.emit(phase)
	SaveManager.commit_battle_success()
	if is_full_shop_open():
		GlobalVariables.ui.reset_purchase_refresh_cost()

func is_full_shop_open() -> bool:
	return PlayerData.run_completed_levels > 0 and PlayerData.run_completed_levels % 3 == 0

func enter_battle() -> void:
	complete_post_battle_collect_gate()
	PlayerData.weapon_progress_this_battle = false
	phase = BATTLE
	phase_changed.emit(phase)

func enter_gameover() -> void:
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
	battle_time = 0
	battle_time_remaining = 30
	current_level = 0
	time_out = 30
	phase = PREPARE
	complete_post_battle_collect_gate()
