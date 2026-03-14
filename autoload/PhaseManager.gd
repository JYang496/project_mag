extends Node

var battle_time := 0
var current_level : int = 0 :
	set(value):
		var max_level_index: int = maxi(SpawnData.level_list.size() - 1, 0)
		current_level = clampi(value, 0, max_level_index)

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

func current_state() -> String:
	return phase

func enter_prepare() -> void:
	pre_enter_prepare_loot.emit()
	current_level += 1
	phase = PREPARE
	phase_changed.emit(phase)
	DataHandler.save_game(DataHandler.save_data)
	GlobalVariables.ui.reset_shopping_refresh_cost()

func enter_battle() -> void:
	phase = BATTLE
	phase_changed.emit(phase)

func enter_gameover() -> void:
	phase = GAMEOVER
	phase_changed.emit(phase)


func reset_runtime_state() -> void:
	battle_time = 0
	current_level = 0
	time_out = 30
	phase = PREPARE
