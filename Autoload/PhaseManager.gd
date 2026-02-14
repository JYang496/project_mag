extends Node

var battle_time := 0
var current_level : int = 0 :
	set(value):
		current_level = clampi(value,0,len(SpawnData.level_list) - 1)

const PREPARE := "prepare"
const BATTLE = "battle"
const REWARD = "reward"
const GAMEOVER = "gameover"
var time_out = 30

var phase_list := [PREPARE,BATTLE,REWARD,GAMEOVER]
var phase := PREPARE:
	get:
		return phase
	set(value):
		if value in phase_list:
			phase = value

signal phase_changed(new_phase: String)
signal enter_reward_signal

func current_state() -> String:
	return phase

func enter_prepare() -> void:
	current_level += 1
	phase = PREPARE
	phase_changed.emit(phase)
	DataHandler.save_game(DataHandler.save_data)
	GlobalVariables.ui.reset_shopping_refresh_cost()

func enter_battle() -> void:
	phase = BATTLE
	phase_changed.emit(phase)

func enter_reward() -> void:
	phase = REWARD
	phase_changed.emit(phase)
	enter_reward_signal.emit()

func enter_gameover() -> void:
	phase = GAMEOVER
	phase_changed.emit(phase)
