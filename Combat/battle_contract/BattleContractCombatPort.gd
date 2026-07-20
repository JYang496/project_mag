extends RefCounted
class_name BattleContractCombatPort

@warning_ignore("unused_signal")
signal battle_tick(snapshot: Dictionary)
@warning_ignore("unused_signal")
signal enemy_spawned(snapshot: Dictionary)
@warning_ignore("unused_signal")
signal enemy_died(snapshot: Dictionary)
@warning_ignore("unused_signal")
signal spawn_budget_exhausted(snapshot: Dictionary)
@warning_ignore("unused_signal")
signal battle_aborted(snapshot: Dictionary)
@warning_ignore("unused_signal")
signal beacon_presence_changed(snapshot: Dictionary)

func get_level_index() -> int:
	return 0

func is_boss_battle() -> bool:
	return false

func get_battle_intro_snapshot() -> Dictionary:
	return {}

func get_allowed_contracts() -> Array[StringName]:
	return []

func get_battlefield_capabilities() -> Dictionary:
	return {}

func request_start_spawning() -> void:
	pass

func request_stop_spawning() -> void:
	pass

func request_external_victory_control(_enabled: bool) -> void:
	pass

func request_configure_finite_budget(_total_budget: float, _batch_count: int) -> void:
	pass

func request_prefer_elite_final_batch(_enabled: bool) -> void:
	pass

func request_release_next_batch() -> void:
	pass

func request_configure_continuous_spawning(_enabled: bool) -> void:
	pass

func request_configure_duration(_duration_sec: float) -> void:
	pass

func request_configure_threat_multiplier(_multiplier: float) -> void:
	pass

func request_release_reinforcement_budget(_multiplier: float = 1.0) -> void:
	pass

func request_spawn_pursuit_wave(_min_count: int, _max_count: int) -> int:
	return 0

func request_configure_contract_economy(_kill_gold_multiplier: float) -> void:
	pass

func request_configure_reward_stage(_enabled: bool, _hp_budget_multiplier: float = 2.0, _reward_multiplier: float = 2.0) -> void:
	pass

func get_active_enemy_count() -> int:
	return 0

func get_spawn_budget_snapshot() -> Dictionary:
	return {}

func request_evacuate_enemies(_options: Dictionary = {}) -> void:
	pass

func request_relocate_enemies(_options: Dictionary = {}) -> void:
	pass

func request_monitor_enemy_stalls(_enabled: bool) -> void:
	pass

func request_finish_battle(_result: Dictionary = {}) -> void:
	pass

func request_player_heal(_amount: int) -> void:
	pass

func request_spawn_beacon(_beacon_id: int, _position: Vector2) -> void:
	pass

func request_spawn_objective(_objective_id: int, _position: Vector2) -> void:
	pass

func request_update_beacon(_beacon_id: int, _progress: float) -> void:
	pass

func request_remove_beacons() -> void:
	pass
