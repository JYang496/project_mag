extends RefCounted
class_name BattleContractCombatPort

signal battle_tick(snapshot: Dictionary)
signal enemy_spawned(snapshot: Dictionary)
signal enemy_died(snapshot: Dictionary)
signal spawn_budget_exhausted(snapshot: Dictionary)
signal battle_aborted(snapshot: Dictionary)
signal beacon_presence_changed(snapshot: Dictionary)

func get_level_index() -> int:
	return 0

func is_boss_battle() -> bool:
	return false

func get_allowed_contracts() -> Array[StringName]:
	return []

func get_battlefield_capabilities() -> Dictionary:
	return {}

func request_start_spawning() -> void:
	pass

func request_stop_spawning() -> void:
	pass

func request_external_victory_control(enabled: bool) -> void:
	pass

func request_configure_finite_budget(total_budget: float, batch_count: int) -> void:
	pass

func request_prefer_elite_final_batch(enabled: bool) -> void:
	pass

func request_release_next_batch() -> void:
	pass

func request_configure_continuous_spawning(enabled: bool) -> void:
	pass

func request_configure_duration(duration_sec: float) -> void:
	pass

func request_configure_threat_multiplier(multiplier: float) -> void:
	pass

func get_active_enemy_count() -> int:
	return 0

func get_spawn_budget_snapshot() -> Dictionary:
	return {}

func request_evacuate_enemies(options: Dictionary = {}) -> void:
	pass

func request_relocate_enemies(options: Dictionary = {}) -> void:
	pass

func request_finish_battle(result: Dictionary = {}) -> void:
	pass

func request_player_heal(amount: int) -> void:
	pass

func request_spawn_beacon(beacon_id: int, position: Vector2) -> void:
	pass

func request_update_beacon(beacon_id: int, progress: float) -> void:
	pass

func request_remove_beacons() -> void:
	pass
