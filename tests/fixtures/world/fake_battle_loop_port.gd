extends BattleContractCombatPort

var start_spawning_calls := 0
var finish_battle_calls := 0
var external_victory_enabled := false
var planned_total_hp := 100
var planned_enemy_count := 1
var last_finish_result: Dictionary = {}

func get_allowed_contracts() -> Array[StringName]:
	return [&"elimination", &"survival"]

func get_spawn_budget_snapshot() -> Dictionary:
	return {
		"planned_total_hp": planned_total_hp,
		"planned_enemy_count": planned_enemy_count,
	}

func request_start_spawning() -> void:
	start_spawning_calls += 1

func request_external_victory_control(enabled: bool) -> void:
	external_victory_enabled = enabled

func request_finish_battle(result: Dictionary = {}) -> void:
	finish_battle_calls += 1
	last_finish_result = result.duplicate(true)
	PhaseManager.enter_prepare()

