extends Node

var battle_time := 0
var current_level : int = 0 :
	set(value):
		current_level = clampi(value,0,len(SpawnData.level_list) - 1)

const PREPARE := "prepare"
const BATTLE = "battle"
const REWARD = "reward"
const GAMEOVER = "gameover"
const TIME_OUT = 30

var phase_list := [PREPARE,BATTLE,REWARD,GAMEOVER]
var phase := PREPARE:
	get:
		return phase
	set(value):
		if value in phase_list:
			phase = value

signal enter_reward_signal

func current_state() -> String:
	return phase

func enter_prepare() -> void:
	current_level += 1
	phase = PREPARE

func enter_battle() -> void:
	phase = BATTLE

func enter_reward() -> void:
	var teleporter = get_tree().get_first_node_in_group("teleporter")
	phase = REWARD
	enter_reward_signal.emit()
	teleporter.move_teleporter()

func enter_gameover() -> void:
	phase = GAMEOVER
