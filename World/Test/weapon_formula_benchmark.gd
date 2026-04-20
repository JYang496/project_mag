extends Node2D
class_name WeaponFormulaBenchmark

@export var config: Resource
@export var player_scene: PackedScene = preload("res://Player/Mechas/scenes/Player.tscn")
@export var dummy_scene: PackedScene = preload("res://World/Test/dps_test_dummy_enemy.tscn")

@onready var spawn_root: Node2D = $SpawnRoot
@onready var player_spawn: Marker2D = $SpawnRoot/PlayerSpawn
@onready var target_spawn: Marker2D = $SpawnRoot/TargetSpawn
@onready var target_root: Node2D = $SpawnRoot/Targets

@onready var status_label: Label = $UI/Panel/VBox/StatusLabel
@onready var weapon_label: Label = $UI/Panel/VBox/WeaponLabel
@onready var progress_label: Label = $UI/Panel/VBox/ProgressLabel
@onready var report_label: Label = $UI/Panel/VBox/ReportLabel
@onready var start_button: Button = $UI/Panel/VBox/Buttons/StartButton
@onready var stop_button: Button = $UI/Panel/VBox/Buttons/StopButton
@onready var reset_button: Button = $UI/Panel/VBox/Buttons/ResetButton

var _player: Player
var _results: Array[Dictionary] = []
var _case_queue: Array[Dictionary] = []
var _current_case_index: int = -1

var _running: bool = false
var _stop_requested: bool = false
var _current_weapon_id: String = ""
var _current_branch_id: String = ""
var _aim_world_pos: Vector2 = Vector2.ZERO

var _elapsed_test_sec: float = 0.0
var _current_total_damage_formula: float = 0.0
var _current_fire_attempts: int = 0
var _current_fire_success: int = 0
var _current_reload_started: int = 0
var _current_reload_finished: int = 0
var _current_manual_reload_calls: int = 0
var _reload_forced_once: bool = false
var _fire_functional_ok: bool = false
var _reload_functional_ok: bool = false
var _formula_notes: String = ""

var _prev_fire_success: int = 0
var _prev_reloading: bool = false
var _prev_dash_state: int = -1
var _pending_damage_streams: Array[Dictionary] = []
var _glacier_state: Dictionary = {"accum_sec": 0.0, "last_proc_sec": -999.0}

var _last_csv_path: String = ""
var _original_time_scale: float = 1.0
var _time_scale_applied: bool = false

func _ready() -> void:
	if config == null:
		config = load("res://data/test/weapon_formula_benchmark_default.tres")
	_ensure_weapon_data_loaded()
	_sync_spawn_markers_from_config()
	_spawn_player()
	_bind_ui_buttons()
	_set_status("Idle")
	weapon_label.text = "Weapon: --"
	progress_label.text = "Progress: --"
	report_label.text = "Report: --"
	if config and bool(config.get("auto_start_on_ready")):
		call_deferred("_on_start_pressed")

func _bind_ui_buttons() -> void:
	start_button.pressed.connect(_on_start_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

func _ensure_weapon_data_loaded() -> void:
	if GlobalVariables.weapon_list.is_empty():
		DataHandler.load_weapon_data()

func _sync_spawn_markers_from_config() -> void:
	if config == null:
		return
	player_spawn.global_position = Vector2(config.get("player_position"))
	target_spawn.global_position = Vector2(config.get("target_position"))
	_aim_world_pos = target_spawn.global_position

func _spawn_player() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()
	PlayerData.reset_runtime_state()
	var player_instance := player_scene.instantiate()
	if not (player_instance is Player):
		push_error("weapon_formula_benchmark: player_scene is not Player")
		return
	_player = player_instance as Player
	spawn_root.add_child(_player)
	_player.global_position = player_spawn.global_position
	PlayerData.player = _player
	PlayerData.set_hp_safety_for_testing(true)

func _on_start_pressed() -> void:
	if _running:
		return
	_stop_requested = false
	_results.clear()
	_case_queue = config.build_case_queue() if config else []
	_current_case_index = -1
	if _case_queue.is_empty():
		_set_status("No test cases in config")
		return
	_run_full_benchmark()

func _on_stop_pressed() -> void:
	if not _running:
		return
	_stop_requested = true
	_set_status("Stopping...")

func _on_reset_pressed() -> void:
	_stop_requested = true
	_running = false
	_cleanup_targets()
	_restore_benchmark_time_scale()
	_results.clear()
	_current_case_index = -1
	_last_csv_path = ""
	_spawn_player()
	_set_status("Idle")
	weapon_label.text = "Weapon: --"
	progress_label.text = "Progress: --"
	report_label.text = "Report: --"

func _run_full_benchmark() -> void:
	if _player == null or not is_instance_valid(_player):
		_spawn_player()
	_apply_benchmark_time_scale()
	_running = true
	_set_status("Running formula benchmark")
	await get_tree().physics_frame
	for i in range(_case_queue.size()):
		if _stop_requested:
			break
		_current_case_index = i
		await _run_case(_case_queue[i], i + 1, _case_queue.size())
		if _stop_requested:
			break
		await get_tree().create_timer(0.12).timeout
	_running = false
	_restore_benchmark_time_scale()
	_write_csv_report()
	if _stop_requested:
		_set_status("Stopped")
	else:
		_set_status("Completed")
	if config and bool(config.get("quit_on_completion")):
		get_tree().quit(0)

func _run_case(case_data: Dictionary, order_idx: int, total_cases: int) -> void:
	_prepare_case(case_data)
	weapon_label.text = "Weapon %s | Branch %s | Round %d" % [
		_current_weapon_id,
		_current_branch_id if _current_branch_id != "" else "none",
		int(case_data.get("round", 1)),
	]

	var warmup_left: float = maxf(float(config.get("warmup_sec")), 0.0)
	while warmup_left > 0.0:
		if _stop_requested:
			return
		_step_once(false)
		await get_tree().physics_frame
		var delta: float = maxf(get_physics_process_delta_time(), 0.001)
		warmup_left -= delta
		progress_label.text = "Progress: Case %d/%d | Warmup %.2fs" % [order_idx, total_cases, maxf(warmup_left, 0.0)]

	_reset_measurement_state()
	var duration: float = maxf(float(config.get("test_duration_sec")), 0.2)
	while _elapsed_test_sec < duration:
		if _stop_requested:
			break
		_step_once(true)
		await get_tree().physics_frame
		var delta_main: float = maxf(get_physics_process_delta_time(), 0.001)
		_elapsed_test_sec += delta_main
		progress_label.text = "Progress: Case %d/%d | Test %.2f/%.2fs" % [order_idx, total_cases, minf(_elapsed_test_sec, duration), duration]

	var measured_duration: float = maxf(_elapsed_test_sec, 0.001)
	_results.append(_build_result(case_data, measured_duration))
	_cleanup_targets()

func _prepare_case(case_data: Dictionary) -> void:
	_cleanup_targets()
	_sync_spawn_markers_from_config()
	_ensure_battle_phase_for_test()
	_current_weapon_id = str(case_data.get("weapon_id", ""))
	_current_branch_id = ""
	if config and config.has_method("get_branch_for_weapon"):
		_current_branch_id = str(config.call("get_branch_for_weapon", _current_weapon_id))
	if _player == null or not is_instance_valid(_player):
		_spawn_player()
	_player.global_position = player_spawn.global_position
	_spawn_target_dummy()
	_equip_weapon(_current_weapon_id, _current_branch_id)
	_apply_benchmark_aim_meta()

func _ensure_battle_phase_for_test() -> void:
	if PhaseManager == null or not PhaseManager.has_method("current_state"):
		return
	if str(PhaseManager.current_state()) == str(PhaseManager.BATTLE):
		return
	if PhaseManager.has_method("enter_battle"):
		PhaseManager.enter_battle()

func _spawn_target_dummy() -> void:
	var dummy_instance := dummy_scene.instantiate()
	var dummy := dummy_instance as Node2D
	if dummy == null:
		return
	var hp_value: int = maxi(int(config.get("target_hp")), 1)
	if dummy.get("max_hp_value") != null:
		dummy.set("max_hp_value", hp_value)
	target_root.add_child(dummy)
	dummy.global_position = target_spawn.global_position
	_aim_world_pos = dummy.global_position

func _equip_weapon(weapon_id: String, branch_id: String) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon_node := weapon_ref as Node
		if weapon_node and is_instance_valid(weapon_node):
			weapon_node.queue_free()
	PlayerData.player_weapon_list.clear()
	PlayerData.main_weapon_index = -1
	PlayerData.on_select_weapon = -1
	_player.create_weapon(weapon_id, int(config.get("weapon_level")))
	PlayerData.set_main_weapon_index(0)
	var main_weapon := _resolve_main_weapon_node()
	if main_weapon == null:
		return
	if branch_id != "" and main_weapon.has_method("set_branch"):
		var branch_ok := bool(main_weapon.call("set_branch", branch_id))
		if not branch_ok:
			push_warning("weapon_formula_benchmark: failed to apply branch %s to weapon %s" % [branch_id, weapon_id])

func _reset_measurement_state() -> void:
	_elapsed_test_sec = 0.0
	_current_total_damage_formula = 0.0
	_current_fire_attempts = 0
	_current_fire_success = 0
	_current_reload_started = 0
	_current_reload_finished = 0
	_current_manual_reload_calls = 0
	_reload_forced_once = false
	_fire_functional_ok = false
	_reload_functional_ok = false
	_formula_notes = ""
	_prev_fire_success = 0
	_prev_reloading = false
	_prev_dash_state = -1
	_pending_damage_streams.clear()
	_glacier_state = {"accum_sec": 0.0, "last_proc_sec": -999.0}
	var w := _resolve_main_weapon_node()
	if w:
		_prev_reloading = bool(w.get("is_reloading")) if w.get("is_reloading") != null else false
		_prev_dash_state = int(w.get("_state")) if w.get("_state") != null else -1

func _step_once(record_damage: bool) -> void:
	_update_mouse_aim()
	var main_weapon := _resolve_main_weapon_node()
	if main_weapon == null:
		return
	_trigger_weapon_fire(main_weapon, record_damage)
	_track_reload_state(main_weapon)
	_track_dash_state(main_weapon, record_damage)
	_update_damage_streams(maxf(get_physics_process_delta_time(), 0.001), record_damage)

func _trigger_weapon_fire(main_weapon: Node, record_damage: bool) -> void:
	if main_weapon.has_method("request_primary_fire"):
		_current_fire_attempts += 1
		var fired := bool(main_weapon.call("request_primary_fire"))
		if fired:
			_current_fire_success += 1
			_fire_functional_ok = true
			if record_damage:
				_on_formula_fire_success(main_weapon)
	if not _reload_forced_once and bool(main_weapon.call("uses_ammo_system") if main_weapon.has_method("uses_ammo_system") else false):
		if _current_fire_success > 0 and main_weapon.has_method("request_reload"):
			var reload_started := bool(main_weapon.call("request_reload"))
			if reload_started:
				_current_manual_reload_calls += 1
				_reload_forced_once = true

func _track_reload_state(main_weapon: Node) -> void:
	var is_reloading_now: bool = bool(main_weapon.get("is_reloading")) if main_weapon.get("is_reloading") != null else false
	if is_reloading_now and not _prev_reloading:
		_current_reload_started += 1
		reload_label_note("reload_started")
	if (not is_reloading_now) and _prev_reloading:
		_current_reload_finished += 1
		_reload_functional_ok = true
	_prev_reloading = is_reloading_now

func _track_dash_state(main_weapon: Node, record_damage: bool) -> void:
	if _current_weapon_id != "11":
		return
	var current_state: int = int(main_weapon.get("_state")) if main_weapon.get("_state") != null else -1
	if current_state == 1 and _prev_dash_state != 1:
		_current_fire_success += 1
		_current_fire_attempts += 1
		_fire_functional_ok = true
		if record_damage:
			var dash_damage: float = _compute_dash_blade_damage(main_weapon)
			_current_total_damage_formula += dash_damage
			_formula_notes = "DashBlade: state-based dash hit formula"
	_prev_dash_state = current_state

func _on_formula_fire_success(main_weapon: Node) -> void:
	var runtime_damage: float = float(_get_runtime_damage(main_weapon))
	var weapon_id: String = _current_weapon_id
	match weapon_id:
		"1":
			var shots: int = _resolve_branch_shot_count(main_weapon, 1)
			_current_total_damage_formula += runtime_damage * float(shots)
			_formula_notes = "MachineGun: damage * shot_count(branch)"
		"5":
			_current_total_damage_formula += runtime_damage
			_formula_notes = "Pistol: damage"
		"4":
			var pellet_count: int = _resolve_shotgun_pellet_count(main_weapon)
			_current_total_damage_formula += runtime_damage * float(pellet_count)
			_formula_notes = "Shotgun: damage * pellet_count(branch aware)"
		"8":
			var rocket_count: int = _resolve_branch_shot_count(main_weapon, 1)
			var rocket_mul: float = float(config.get("rocket_single_target_multiplier"))
			_current_total_damage_formula += runtime_damage * float(rocket_count) * maxf(rocket_mul, 1.0)
			_formula_notes = "Rocket: damage * rockets * single_target_multiplier"
		"9":
			_spawn_periodic_stream(runtime_damage, float(config.get("laser_beam_duration_sec")), 1.0 / maxf(float(config.get("laser_beam_tick_hz")), 1.0))
			_formula_notes = "Laser: beam ticks over beam duration"
		"2":
			_spawn_charged_blaster_streams(main_weapon, runtime_damage)
			_formula_notes = "ChargedBlaster: sum(profile damage ticks over duration/hit_cd)"
		"13":
			var flame_targets: float = maxf(float(config.get("formula_target_count")), 1.0)
			var flame_mul: float = _get_branch_damage_multiplier(main_weapon)
			_current_total_damage_formula += runtime_damage * flame_targets * flame_mul
			_formula_notes = "Flamethrower: damage * expected_targets * branch_damage_multiplier"
		"21":
			_apply_glacier_formula(main_weapon, runtime_damage)
			_formula_notes = "Glacier: burst damage + cold snap proc accumulation"
		"25":
			_current_total_damage_formula += runtime_damage
			_formula_notes = "Cannon: damage (single shell)"
		"26":
			_apply_sniper_formula(main_weapon, runtime_damage)
			_formula_notes = "Sniper: damage * distance_multiplier (+ optional pierce estimate)"
		"17":
			_apply_plasma_lance_formula(main_weapon, runtime_damage)
			_formula_notes = "PlasmaLance: damage + pierce scaling estimate"
		"10":
			_apply_chainsaw_formula(main_weapon, runtime_damage)
			_formula_notes = "Chainsaw: immediate hit + DOT stream over contact duration"
		"3":
			var spear_count: int = _resolve_branch_shot_count(main_weapon, 1)
			_current_total_damage_formula += runtime_damage * float(spear_count)
			_formula_notes = "Spear: damage * shot_count(branch)"
		"7":
			_apply_orbit_formula(main_weapon, runtime_damage)
			_formula_notes = "Orbit: satellites spawn periodic damage streams"
		"11":
			# Dash blade is tracked by state transitions in _track_dash_state.
			_formula_notes = "DashBlade: state-based dash hit formula"
		_:
			_current_total_damage_formula += runtime_damage
			_formula_notes = "Fallback: damage"

func _spawn_periodic_stream(per_tick_damage: float, duration_sec: float, tick_interval_sec: float) -> void:
	var stream: Dictionary = {
		"damage": maxf(per_tick_damage, 0.0),
		"remaining": maxf(duration_sec, 0.0),
		"tick_interval": maxf(tick_interval_sec, 0.005),
		"tick_left": 0.0,
	}
	_pending_damage_streams.append(stream)

func _spawn_charged_blaster_streams(main_weapon: Node, runtime_damage: float) -> void:
	var base_profile := {
		"range_multiplier": 1.0,
		"width_multiplier": 1.0,
		"damage_multiplier": 1.0,
		"duration_multiplier": 1.0,
		"hit_cd_multiplier": 1.0,
	}
	var profiles: Array = [base_profile]
	var branch: Node = main_weapon.get("branch_behavior") as Node
	if branch and is_instance_valid(branch) and branch.has_method("get_charged_beam_profiles"):
		var branch_profiles: Variant = branch.call("get_charged_beam_profiles", base_profile)
		if branch_profiles is Array and not (branch_profiles as Array).is_empty():
			profiles = branch_profiles
	var base_duration: float = float(main_weapon.get("duration")) if main_weapon.get("duration") != null else 1.0
	var base_hit_cd: float = float(main_weapon.get("hit_cd")) if main_weapon.get("hit_cd") != null else 0.2
	for profile_variant in profiles:
		if not (profile_variant is Dictionary):
			continue
		var profile: Dictionary = profile_variant
		var dmg_mul: float = maxf(float(profile.get("damage_multiplier", 1.0)), 0.05)
		var dur_mul: float = maxf(float(profile.get("duration_multiplier", 1.0)), 0.05)
		var hit_mul: float = maxf(float(profile.get("hit_cd_multiplier", 1.0)), 0.05)
		_spawn_periodic_stream(runtime_damage * dmg_mul, base_duration * dur_mul, base_hit_cd * hit_mul)

func _apply_glacier_formula(main_weapon: Node, runtime_damage: float) -> void:
	var expected_targets: float = maxf(float(config.get("formula_target_count")), 1.0)
	_current_total_damage_formula += runtime_damage * expected_targets
	var now_sec: float = _elapsed_test_sec
	var accum_sec: float = float(_glacier_state.get("accum_sec", 0.0)) + maxf(_resolve_weapon_cooldown(main_weapon), 0.01)
	var last_proc_sec: float = float(_glacier_state.get("last_proc_sec", -999.0))
	var threshold_sec: float = float(main_weapon.get("cold_snap_contact_threshold_sec")) if main_weapon.get("cold_snap_contact_threshold_sec") != null else 1.2
	var icd_sec: float = float(main_weapon.get("cold_snap_icd_sec")) if main_weapon.get("cold_snap_icd_sec") != null else 1.2
	if accum_sec >= maxf(threshold_sec, 0.1) and now_sec - last_proc_sec >= maxf(icd_sec, 0.1):
		var ratio: float = float(main_weapon.get("cold_snap_damage_ratio")) if main_weapon.get("cold_snap_damage_ratio") != null else 0.35
		_current_total_damage_formula += runtime_damage * maxf(ratio, 0.0) * expected_targets
		accum_sec = 0.0
		last_proc_sec = now_sec
	_glacier_state["accum_sec"] = accum_sec
	_glacier_state["last_proc_sec"] = last_proc_sec

func _apply_sniper_formula(main_weapon: Node, runtime_damage: float) -> void:
	var distance_mul: float = maxf(float(config.get("sniper_distance_multiplier")), 1.0)
	var total: float = runtime_damage * distance_mul
	var expected_pierce_hits: int = maxi(int(config.get("sniper_expected_pierce_hits")), 0)
	var branch: Node = main_weapon.get("branch_behavior") as Node
	var gain_per_hit: int = 0
	if branch and is_instance_valid(branch) and branch.has_method("get_pierce_damage_gain_per_hit"):
		gain_per_hit = maxi(int(branch.call("get_pierce_damage_gain_per_hit")), 0)
	total += float(gain_per_hit * expected_pierce_hits)
	_current_total_damage_formula += total

func _apply_plasma_lance_formula(main_weapon: Node, runtime_damage: float) -> void:
	var expected_pierce_hits: int = maxi(int(config.get("plasma_expected_pierce_hits")), 0)
	var gain_per_pierce: int = int(main_weapon.get("damage_gain_per_pierce")) if main_weapon.get("damage_gain_per_pierce") != null else 0
	_current_total_damage_formula += runtime_damage + float(gain_per_pierce * expected_pierce_hits)

func _apply_chainsaw_formula(main_weapon: Node, runtime_damage: float) -> void:
	var dot_cd: float = float(main_weapon.get("dot_cd")) if main_weapon.get("dot_cd") != null else 0.1
	var dot_mul: float = _get_branch_projectile_damage_multiplier(main_weapon)
	var base_damage: float = runtime_damage * dot_mul
	_current_total_damage_formula += base_damage
	_spawn_periodic_stream(base_damage, float(config.get("chainsaw_contact_duration_sec")), maxf(dot_cd, 0.02))

func _apply_orbit_formula(main_weapon: Node, runtime_damage: float) -> void:
	var sat_count: int = maxi(int(main_weapon.get("number")) if main_weapon.get("number") != null else 1, 1)
	var lifetime: float = maxf(float(config.get("orbit_satellite_lifetime_sec")), 0.2)
	var hits_per_sec: float = maxf(float(config.get("orbit_hits_per_second_per_satellite")), 0.1)
	var tick_interval: float = 1.0 / hits_per_sec
	var projectile_mul: float = _get_branch_projectile_damage_multiplier(main_weapon)
	for _i in range(sat_count):
		_spawn_periodic_stream(runtime_damage * projectile_mul, lifetime, tick_interval)

func _compute_dash_blade_damage(main_weapon: Node) -> float:
	if main_weapon.get("damage") != null:
		return float(main_weapon.get("damage"))
	if main_weapon.get("base_damage") != null:
		return float(main_weapon.get("base_damage"))
	return 1.0

func _resolve_weapon_cooldown(main_weapon: Node) -> float:
	if main_weapon.has_method("get_effective_cooldown") and main_weapon.get("attack_cooldown") != null:
		return float(main_weapon.call("get_effective_cooldown", float(main_weapon.get("attack_cooldown"))))
	if main_weapon.get("attack_cooldown") != null:
		return float(main_weapon.get("attack_cooldown"))
	return 0.5

func _resolve_branch_shot_count(main_weapon: Node, fallback: int) -> int:
	var result: int = maxi(fallback, 1)
	var branch: Node = main_weapon.get("branch_behavior") as Node
	if branch and is_instance_valid(branch) and branch.has_method("get_shot_directions"):
		var dirs_variant: Variant = branch.call("get_shot_directions", Vector2.RIGHT, result)
		if dirs_variant is Array:
			var dirs: Array = dirs_variant
			if dirs.size() > 1:
				result = dirs.size()
	return result

func _resolve_shotgun_pellet_count(main_weapon: Node) -> int:
	var pellet_count: int = maxi(int(main_weapon.get("bullet_count")) if main_weapon.get("bullet_count") != null else 1, 1)
	var branch: Node = main_weapon.get("branch_behavior") as Node
	if branch and is_instance_valid(branch) and branch.has_method("get_projectile_count_override"):
		pellet_count = maxi(int(branch.call("get_projectile_count_override", pellet_count)), 1)
	if branch and is_instance_valid(branch) and branch.has_method("get_shot_directions"):
		var dirs_variant: Variant = branch.call("get_shot_directions", Vector2.RIGHT, pellet_count)
		if dirs_variant is Array and (dirs_variant as Array).size() > 1:
			pellet_count = (dirs_variant as Array).size()
	return pellet_count

func _get_branch_projectile_damage_multiplier(main_weapon: Node) -> float:
	var branch: Node = main_weapon.get("branch_behavior") as Node
	if branch and is_instance_valid(branch) and branch.has_method("get_projectile_damage_multiplier"):
		return maxf(float(branch.call("get_projectile_damage_multiplier")), 0.05)
	return 1.0

func _get_branch_damage_multiplier(main_weapon: Node) -> float:
	var branch: Node = main_weapon.get("branch_behavior") as Node
	if branch and is_instance_valid(branch) and branch.has_method("get_damage_multiplier"):
		return maxf(float(branch.call("get_damage_multiplier")), 0.05)
	return 1.0

func _update_damage_streams(delta: float, record_damage: bool) -> void:
	if _pending_damage_streams.is_empty():
		return
	var kept: Array[Dictionary] = []
	for stream in _pending_damage_streams:
		var remaining: float = float(stream.get("remaining", 0.0)) - delta
		var tick_left: float = float(stream.get("tick_left", 0.0)) - delta
		var interval: float = maxf(float(stream.get("tick_interval", 0.05)), 0.005)
		while tick_left <= 0.0 and remaining > 0.0:
			if record_damage:
				_current_total_damage_formula += maxf(float(stream.get("damage", 0.0)), 0.0)
			tick_left += interval
		if remaining > 0.0:
			stream["remaining"] = remaining
			stream["tick_left"] = tick_left
			kept.append(stream)
	_pending_damage_streams = kept

func _build_result(case_data: Dictionary, duration_sec: float) -> Dictionary:
	var dps: float = _current_total_damage_formula / maxf(duration_sec, 0.001)
	var main_weapon := _resolve_main_weapon_node()
	var uses_ammo: bool = false
	if main_weapon and main_weapon.has_method("uses_ammo_system"):
		uses_ammo = bool(main_weapon.call("uses_ammo_system"))
	var reload_required: bool = uses_ammo
	var reload_pass: bool = _reload_functional_ok or not reload_required
	return {
		"weapon_id": _current_weapon_id,
		"weapon_name": _resolve_weapon_name(_current_weapon_id),
		"weapon_level": int(config.get("weapon_level")),
		"branch_id": _current_branch_id,
		"round": int(case_data.get("round", 1)),
		"duration_sec": snapped(duration_sec, 0.001),
		"fire_attempts": _current_fire_attempts,
		"fire_success": _current_fire_success,
		"reload_started": _current_reload_started,
		"reload_finished": _current_reload_finished,
		"manual_reload_calls": _current_manual_reload_calls,
		"fire_test_pass": _fire_functional_ok,
		"reload_test_pass": reload_pass,
		"total_damage_formula": snapped(_current_total_damage_formula, 0.001),
		"dps": snapped(dps, 0.001),
		"formula": _formula_notes,
		"timestamp": Time.get_datetime_string_from_system(true, true),
	}

func _write_csv_report() -> void:
	if _results.is_empty() or config == null:
		return
	var report_dir: String = str(config.get("report_dir"))
	_ensure_report_dir(report_dir)
	var stamp: String = _build_file_stamp()
	var csv_path: String = "%s/%s_%s.csv" % [report_dir, str(config.get("report_file_prefix")), stamp]
	var file := FileAccess.open(csv_path, FileAccess.WRITE)
	if file == null:
		push_warning("weapon_formula_benchmark: failed to open csv %s" % csv_path)
		return
	var header := [
		"weapon_id",
		"weapon_name",
		"weapon_level",
		"branch_id",
		"round",
		"duration_sec",
		"fire_attempts",
		"fire_success",
		"reload_started",
		"reload_finished",
		"manual_reload_calls",
		"fire_test_pass",
		"reload_test_pass",
		"total_damage_formula",
		"dps",
		"formula",
		"timestamp",
	]
	file.store_line(",".join(header))
	for row in _results:
		var cols: Array[String] = []
		for key in header:
			cols.append(_csv_escape(str(row.get(key, ""))))
		file.store_line(",".join(cols))
	file.flush()
	file.close()
	_last_csv_path = csv_path
	report_label.text = "Report: %s" % csv_path

func _csv_escape(value: String) -> String:
	if value.find(",") >= 0 or value.find("\"") >= 0 or value.find("\n") >= 0:
		return "\"%s\"" % value.replace("\"", "\"\"")
	return value

func _ensure_report_dir(dir_path: String) -> void:
	var absolute_dir := ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(absolute_dir)

func _build_file_stamp() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]

func _resolve_main_weapon_node() -> Node:
	if _player == null or not is_instance_valid(_player):
		return null
	var main_weapon: Variant = _player.get_main_weapon()
	if main_weapon == null or not is_instance_valid(main_weapon):
		return null
	return main_weapon as Node

func _get_runtime_damage(main_weapon: Node) -> int:
	if main_weapon.has_method("get_runtime_shot_damage"):
		return maxi(int(main_weapon.call("get_runtime_shot_damage")), 1)
	if main_weapon.get("damage") != null:
		return maxi(int(main_weapon.get("damage")), 1)
	return 1

func _resolve_weapon_name(weapon_id: String) -> String:
	var def: Variant = DataHandler.read_weapon_data(weapon_id)
	if def == null:
		return "unknown"
	var localized := LocalizationManager.get_weapon_name_from_definition(def)
	if localized != "":
		return localized
	var display_variant: Variant = def.get("display_name")
	if display_variant != null and str(display_variant) != "":
		return str(display_variant)
	return "weapon_%s" % weapon_id

func _cleanup_targets() -> void:
	for child in target_root.get_children():
		child.queue_free()
	_pending_damage_streams.clear()

func _update_mouse_aim() -> void:
	if config == null or not bool(config.get("force_mouse_to_target")):
		return
	if _aim_world_pos == Vector2.ZERO:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var canvas_pos: Vector2 = viewport.get_canvas_transform() * _aim_world_pos
	Input.warp_mouse(canvas_pos)

func _apply_benchmark_aim_meta() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.set_meta("_benchmark_mouse_target", _aim_world_pos)
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon_node := weapon_ref as Node
		if weapon_node == null or not is_instance_valid(weapon_node):
			continue
		weapon_node.set_meta("_benchmark_mouse_target", _aim_world_pos)

func _apply_benchmark_time_scale() -> void:
	if _time_scale_applied:
		return
	if config == null or not bool(config.get("accelerated_mode")):
		return
	_original_time_scale = Engine.time_scale
	var scale: float = float(config.get("simulation_time_scale"))
	Engine.time_scale = clampf(scale, 0.1, 32.0)
	_time_scale_applied = true

func _restore_benchmark_time_scale() -> void:
	if not _time_scale_applied:
		return
	Engine.time_scale = _original_time_scale
	_time_scale_applied = false

func _set_status(message: String) -> void:
	status_label.text = "Status: %s" % message

func reload_label_note(_tag: String) -> void:
	# Keep a tiny hook for debugging reload transitions without extra logs.
	pass
