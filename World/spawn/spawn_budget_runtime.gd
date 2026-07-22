extends RefCounted
class_name SpawnBudgetRuntime

const RUNTIME_DIAGNOSTICS_SCRIPT := preload("res://autoload/RuntimeDiagnostics.gd")

var combat_budget_active: bool = true
var planned_target_total_hp: int = 0
var spawned_total_hp: int = 0
var killed_total_hp: int = 0
var available_hp_budget: float = 0.0
var pressure_budget_total: float = 1.0
var budget_release_duration_sec: int = 1
var budget_release_finished: bool = false
var spawn_budget_stopped: bool = false
var budget_summary_printed: bool = false

var _profile_provider := Callable()
var _candidate_hp_resolver := Callable()
var _kill_gold_summary_printer := Callable()

func bind(profile_provider: Callable, candidate_hp_resolver: Callable, kill_gold_summary_printer: Callable) -> void:
	_profile_provider = profile_provider
	_candidate_hp_resolver = candidate_hp_resolver
	_kill_gold_summary_printer = kill_gold_summary_printer

func is_runtime_spawn_budget_spent() -> bool:
	return is_combat_budget_ready() and spawned_total_hp >= planned_target_total_hp

func should_end_after_spawn_budget_stopped(alive_count: int) -> bool:
	return spawn_budget_stopped and alive_count <= 0

func prepare_level_combat_budget(level_index: int, effective_time_out: int) -> void:
	combat_budget_active = true
	planned_target_total_hp = 0
	spawned_total_hp = 0
	killed_total_hp = 0
	available_hp_budget = 0.0
	pressure_budget_total = 1.0
	budget_release_duration_sec = 1
	budget_release_finished = false
	spawn_budget_stopped = false
	budget_summary_printed = false
	var budget_profile := _get_spawn_combat_profile()
	if budget_profile == null:
		return
	var target_total_hp := int(budget_profile.call("get_target_total_hp", level_index))
	if target_total_hp <= 0:
		return
	planned_target_total_hp = target_total_hp
	var release_ratio := clampf(float(budget_profile.get("budget_release_completion_ratio")), 0.05, 1.0)
	budget_release_duration_sec = clampi(int(round(float(maxi(effective_time_out, 1)) * release_ratio)), 1, maxi(effective_time_out, 1))
	pressure_budget_total = calculate_pressure_budget_total(budget_release_duration_sec)
	combat_budget_active = true
	if bool(budget_profile.get("enable_hp_per_sec_report")) and RUNTIME_DIAGNOSTICS_SCRIPT.verbose_logs_enabled():
		var target_hps := float(target_total_hp) / float(maxi(budget_release_duration_sec, 1))
		print("[SpawnBudget] level=%d target_hp=%d target_hps=%.2f release_sec=%d timeout=%d pressure_sum=%.2f" % [
			level_index,
			target_total_hp,
			target_hps,
			budget_release_duration_sec,
			effective_time_out,
			pressure_budget_total,
		])

func resolve_batch_hp_budget(level_index: int, _effective_time_out: int) -> float:
	var profile := _get_spawn_combat_profile()
	var target_hp := float(maxi(int(profile.call("get_target_total_hp", level_index)), 1))
	var release_duration: int = maxi(budget_release_duration_sec, 1)
	var progress := clampf(float(PhaseManager.battle_time) / float(release_duration), 0.0, 1.0)
	var pressure_multiplier: float = float(profile.call("get_pressure_multiplier", progress))
	return target_hp * pressure_multiplier / maxf(pressure_budget_total, 0.001)

func release_hp_budget_for_current_tick(level_index: int, effective_time_out: int) -> void:
	if spawn_budget_stopped:
		return
	if budget_release_finished:
		return
	if PhaseManager.battle_time >= budget_release_duration_sec:
		release_remaining_spawn_budget()
		budget_release_finished = true
		update_spawn_budget_stop_state()
		return
	var current_budget := resolve_batch_hp_budget(level_index, effective_time_out)
	available_hp_budget += current_budget
	var max_carryover_seconds := maxi(int(_get_spawn_combat_profile().get("max_hp_budget_carryover_seconds")), 1)
	var max_available := current_budget * float(max_carryover_seconds)
	available_hp_budget = minf(available_hp_budget, max_available)
	update_spawn_budget_stop_state()

func consume_spawned_hp(spawned_hp: int) -> void:
	available_hp_budget -= float(spawned_hp)
	spawned_total_hp += spawned_hp
	update_spawn_budget_stop_state()

func record_enemy_death_for_budget_summary(enemy_instance: Node, was_killed: bool) -> void:
	if not was_killed:
		return
	if enemy_instance == null:
		return
	var scaled_hp := 1
	if enemy_instance.has_meta("_spawn_budget_scaled_hp"):
		scaled_hp = maxi(int(enemy_instance.get_meta("_spawn_budget_scaled_hp")), 1)
	elif enemy_instance.get("hp") != null:
		scaled_hp = maxi(int(enemy_instance.get("hp")), 1)
	killed_total_hp += scaled_hp

func print_spawn_budget_battle_summary(level_index: int, effective_time_out: int) -> void:
	if not RUNTIME_DIAGNOSTICS_SCRIPT.verbose_logs_enabled():
		return
	if not is_combat_budget_ready():
		return
	if budget_summary_printed:
		return
	budget_summary_printed = true
	print("[SpawnBudgetSummary] level=%d killed_hp=%d target_hp=%d spawned_hp=%d battle_time=%d timeout=%d release_sec=%d stopped=%s" % [
		level_index,
		killed_total_hp,
		planned_target_total_hp,
		spawned_total_hp,
		PhaseManager.battle_time,
		effective_time_out,
		budget_release_duration_sec,
		str(spawn_budget_stopped),
	])
	if _kill_gold_summary_printer.is_valid():
		_kill_gold_summary_printer.call("battle_end", level_index)

func release_remaining_spawn_budget() -> void:
	var remaining_hp := maxi(planned_target_total_hp - spawned_total_hp, 0)
	if remaining_hp <= 0:
		return
	available_hp_budget += float(remaining_hp)

func update_spawn_budget_stop_state() -> void:
	if not is_combat_budget_ready():
		return
	if spawned_total_hp >= planned_target_total_hp:
		spawn_budget_stopped = true
		available_hp_budget = 0.0

func calculate_pressure_budget_total(release_duration_sec: int) -> float:
	var profile := _get_spawn_combat_profile()
	var timeout := maxi(release_duration_sec, 1)
	var total := 0.0
	for tick in range(1, timeout):
		var progress := clampf(float(tick) / float(timeout), 0.0, 1.0)
		total += maxf(float(profile.call("get_pressure_multiplier", progress)), 0.001)
	return maxf(total, 0.001)

func resolve_budget_candidate_hp(state: Dictionary, level_index: int) -> int:
	if _candidate_hp_resolver.is_valid():
		return maxi(int(_candidate_hp_resolver.call(state, level_index)), 1)
	return 1

func is_combat_budget_ready() -> bool:
	return combat_budget_active and planned_target_total_hp > 0

func _get_spawn_combat_profile() -> SpawnCombatProfile:
	if not _profile_provider.is_valid():
		return null
	return _profile_provider.call() as SpawnCombatProfile
