extends Node

var battle_time := 0

var PREPARE := "prepare"
var BATTLE = "battle"
var BONUS = "bonus"
var GAMEOVER = "gameover"

var phase_list := [PREPARE,BATTLE,BONUS,GAMEOVER]
var phase := PREPARE:
	get:
		return phase
	set(value):
		if value in phase_list:
			phase = value


func current_state() -> String:
	return phase

func enter_prepare() -> void:
	phase = PREPARE

func enter_battle() -> void:
	phase = BATTLE

func enter_bonus() -> void:
	var teleporter = get_tree().get_first_node_in_group("teleporter")
	phase = BONUS
	teleporter.move_teleporter()

func enter_gameover() -> void:
	phase = GAMEOVER
