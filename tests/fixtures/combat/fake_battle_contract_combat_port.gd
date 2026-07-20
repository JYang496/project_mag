extends BattleContractCombatPort

var level_index := 0
var active_enemy_count := 0
var spawn_budget_snapshot := {"planned_total_hp": 900, "planned_enemy_count": 9}
var capabilities := {
	"operation_beacon_points": PackedVector2Array([Vector2(10, 10), Vector2(20, 10)]),
	"containment_points": PackedVector2Array([Vector2(10, 20), Vector2(20, 20), Vector2(30, 20)]),
	"extraction_points": PackedVector2Array([Vector2(40, 20)]),
}

var start_spawning_calls := 0
var stop_spawning_calls := 0
var external_victory_control := false
var continuous_spawning := false
var monitor_enemy_stalls := false
var prefer_elite_final_batch := false
var configured_duration := 0.0
var configured_threat := 1.0
var configured_budget := {}
var released_batches := 0
var reinforcement_multipliers: Array[float] = []
var reward_stage_calls: Array[Dictionary] = []
var pursuit_wave_calls: Array[Vector2i] = []
var evacuations: Array[Dictionary] = []
var heals: Array[int] = []
var spawned_beacons: Array[Dictionary] = []
var spawned_objectives: Array[Dictionary] = []
var beacon_updates: Array[Dictionary] = []
var remove_beacons_calls := 0

func get_level_index() -> int:
	return level_index

func get_battlefield_capabilities() -> Dictionary:
	return capabilities

func request_start_spawning() -> void:
	start_spawning_calls += 1

func request_stop_spawning() -> void:
	stop_spawning_calls += 1

func request_external_victory_control(enabled: bool) -> void:
	external_victory_control = enabled

func request_configure_finite_budget(total_budget: float, batch_count: int) -> void:
	configured_budget = {"total_budget": total_budget, "batch_count": batch_count}

func request_prefer_elite_final_batch(enabled: bool) -> void:
	prefer_elite_final_batch = enabled

func request_release_next_batch() -> void:
	released_batches += 1

func request_configure_continuous_spawning(enabled: bool) -> void:
	continuous_spawning = enabled

func request_configure_duration(duration_sec: float) -> void:
	configured_duration = duration_sec

func request_configure_threat_multiplier(multiplier: float) -> void:
	configured_threat = multiplier

func request_release_reinforcement_budget(multiplier: float = 1.0) -> void:
	reinforcement_multipliers.append(multiplier)

func request_spawn_pursuit_wave(min_count: int, max_count: int) -> int:
	pursuit_wave_calls.append(Vector2i(min_count, max_count))
	return max_count

func request_configure_reward_stage(enabled: bool, hp_budget_multiplier: float = 2.0, reward_multiplier: float = 2.0) -> void:
	reward_stage_calls.append({"enabled": enabled, "hp_budget_multiplier": hp_budget_multiplier, "reward_multiplier": reward_multiplier})

func get_active_enemy_count() -> int:
	return active_enemy_count

func get_spawn_budget_snapshot() -> Dictionary:
	return spawn_budget_snapshot

func request_evacuate_enemies(options: Dictionary = {}) -> void:
	evacuations.append(options.duplicate(true))

func request_monitor_enemy_stalls(enabled: bool) -> void:
	monitor_enemy_stalls = enabled

func request_player_heal(amount: int) -> void:
	heals.append(amount)

func request_spawn_beacon(beacon_id: int, position: Vector2) -> void:
	spawned_beacons.append({"id": beacon_id, "position": position})

func request_spawn_objective(objective_id: int, position: Vector2) -> void:
	spawned_objectives.append({"id": objective_id, "position": position})

func request_update_beacon(beacon_id: int, progress: float) -> void:
	beacon_updates.append({"id": beacon_id, "progress": progress})

func request_remove_beacons() -> void:
	remove_beacons_calls += 1
