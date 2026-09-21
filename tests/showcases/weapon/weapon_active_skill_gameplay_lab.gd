extends Node

const DUMMY_SCENE := preload("res://Npc/enemy/scenes/dummy.tscn")
const REAL_ENEMY_SCENE := preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn")
const SKILL_CATALOG := preload("res://Player/Weapons/Core/weapon_active_skill_catalog.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PERFORMANCE_SCENARIO := preload("res://tests/showcases/weapon/weapon_performance_scenario.gd")
const PERFORMANCE_RUNNER := preload("res://tests/showcases/weapon/weapon_performance_runner.gd")
const PERFORMANCE_REPORT := preload("res://tests/showcases/weapon/weapon_performance_report.gd")
const WEAPON_CATALOG := preload("res://tests/showcases/weapon/weapon_lab_catalog.gd")
const MAIN_MENU_SCENE := "res://World/Start.tscn"
const DUMMY_HP := 1000000
const WEAPONS: Array[Dictionary] = WEAPON_CATALOG.WEAPONS
const TARGET_OFFSETS: Array[Vector2] = [
	Vector2(-300, -190), Vector2(-100, -220), Vector2(110, -220), Vector2(310, -185),
	Vector2(-390, 0), Vector2(-230, 20), Vector2(230, 20), Vector2(390, 0),
	Vector2(-300, 190), Vector2(-100, 220), Vector2(110, 220), Vector2(310, 185),
]

var _world: WorldShell
var _player: Player
var _enemy_spawner: EnemySpawner
var _current_weapon: Weapon
var _current_index := 0
var _weapon_buttons: Array[Button] = []
var _title_label: Label
var _description_label: Label
var _status_label: Label
var _panel: PanelContainer
var _initialized := false
var _target_count := 0
var _status_refresh_elapsed := 0.0
var _performance_runner: WeaponPerformanceRunner
var _performance_status_label: Label
var _autorun_performance := false
var _lifecycle_spawn_elapsed := 0.0


func _ready() -> void:
	_world = get_parent() as WorldShell
	if _world == null:
		push_error("Weapon gameplay lab must be a child of WorldShell.")
		return
	_world.build_completed.connect(_on_world_build_completed, CONNECT_ONE_SHOT)


func _on_world_build_completed() -> void:
	await get_tree().process_frame
	_player = PlayerData.player as Player
	_enemy_spawner = _world.get_node_or_null("EnemySpawner") as EnemySpawner
	if _player == null or not is_instance_valid(_player) or _enemy_spawner == null:
		push_error("Weapon gameplay lab could not acquire production player/world services.")
		return
	_enemy_spawner.stop_spawning()
	_enemy_spawner.erase_all_enemies()
	LoadingPerformance.hide_world_build_overlay()
	PhaseManager.phase = PhaseManager.BATTLE_STARTING
	PhaseManager.enter_battle()
	_build_lab_panel()
	_select_weapon(0)
	_spawn_targets()
	_setup_performance_runner()
	_initialized = true
	if OS.get_cmdline_user_args().has("--validate-weapon-gameplay-lab"):
		await _run_contract_validation()
	else:
		var autorun_suite := _get_performance_suite_argument()
		if not autorun_suite.is_empty():
			_autorun_performance = true
			await get_tree().process_frame
			_run_performance_suite(autorun_suite)


func _input(event: InputEvent) -> void:
	if not _initialized or not event is InputEventKey or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_Q:
			_select_weapon(posmod(_current_index - 1, WEAPONS.size()))
			get_viewport().set_input_as_handled()
		KEY_E:
			_select_weapon((_current_index + 1) % WEAPONS.size())
			get_viewport().set_input_as_handled()
		KEY_R:
			_reset_targets()
			get_viewport().set_input_as_handled()
		KEY_F2:
			_panel.visible = not _panel.visible
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _initialized or _current_weapon == null or not is_instance_valid(_current_weapon):
		return
	_status_refresh_elapsed += maxf(delta, 0.0)
	if _status_refresh_elapsed < 0.25:
		return
	_status_refresh_elapsed = 0.0
	var status := _current_weapon.get_weapon_skill_status()
	var active_text := "无主动技能（左键测试追踪齐射）" if _is_current_weapon_basic_only() else "技能就绪"
	if not _is_current_weapon_basic_only() and bool(status.get("active", false)):
		active_text = "生效中 %.1fs" % float(status.get("active_remaining", 0.0))
	var target_capacity := TARGET_OFFSETS.size()
	if _performance_runner != null and _performance_runner.running and _performance_runner.active_scenario != null:
		target_capacity = _performance_runner.active_scenario.target_count
	_status_label.text = "%s  |  靶机 %d/%d  |  F2 隐藏面板" % [
		active_text,
		_target_count,
		target_capacity,
	]


func _select_weapon(index: int) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_current_index = clampi(index, 0, WEAPONS.size() - 1)
	for child in _player.equppied_weapons.get_children():
		var weapon := child as Weapon
		if weapon == null:
			continue
		weapon.clear_timed_effects_for_prepare()
		weapon.visible = false
		weapon.queue_free()
	PlayerData.player_weapon_list.clear()
	_current_weapon = (WEAPONS[_current_index]["scene"] as PackedScene).instantiate() as Weapon
	_player.equppied_weapons.add_child(_current_weapon)
	_current_weapon.position = Vector2.ZERO
	PlayerData.player_weapon_list.append(_current_weapon)
	PlayerData.main_weapon_index = 0
	PlayerData.on_select_weapon = 0
	PlayerData.notify_weapon_list_changed()
	_player.mark_weapon_roles_dirty_for_assist()
	_player.refresh_weapon_structure_for_assist()
	_current_weapon.skill_runtime.force_ready()
	_player.add_energy(_player.player_max_energy)
	_refresh_panel()


func _spawn_targets() -> void:
	var center := _player.global_position
	for index in range(TARGET_OFFSETS.size()):
		var dummy := DUMMY_SCENE.instantiate() as BaseEnemy
		dummy.name = "GameplaySkillTarget%02d" % (index + 1)
		dummy.hp = DUMMY_HP
		dummy.damage = 0
		dummy.movement_speed = 0.0
		dummy.global_position = center + TARGET_OFFSETS[index]
		dummy.add_to_group(&"skill_gameplay_lab_dummy")
		dummy.add_to_group(&"weapon_performance_lab_target")
		_world.add_child(dummy)
		_target_count += 1


func _reset_targets() -> void:
	for target in get_tree().get_nodes_in_group(&"skill_gameplay_lab_dummy"):
		if target != null and is_instance_valid(target):
			target.queue_free()
	_target_count = 0
	_spawn_targets()
	_status_label.text = "全部靶机已重置。"


func _build_lab_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WeaponSkillLabLayer"
	layer.layer = 90
	_world.add_child(layer)
	_panel = PanelContainer.new()
	_panel.name = "WeaponSkillLabPanel"
	_panel.position = Vector2(930, 108)
	_panel.size = Vector2(334, 590)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.075, 0.96)
	panel_style.border_color = Color(0.28, 0.78, 0.90, 0.82)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	var heading := Label.new()
	heading.text = "实际战场 · 主动技能测试"
	heading.add_theme_font_size_override("font_size", 18)
	heading.modulate = Color("#86e7ff")
	content.add_child(heading)
	var help := Label.new()
	help.text = "Q/E 切换  C 技能  左键攻击  R 重置"
	help.modulate = Color("#a8bac2")
	content.add_child(help)
	var extreme_button := Button.new()
	extreme_button.text = "性能测试 · 全武器极限敌群"
	extreme_button.tooltip_text = "120 个真实敌人，依次自动测试全部武器；结束后保存报告到 docs/performance/weapon_lab。"
	extreme_button.custom_minimum_size = Vector2(280, 28)
	extreme_button.pressed.connect(_run_performance_suite.bind("extreme_performance"))
	content.add_child(extreme_button)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	content.add_child(grid)
	for index in range(WEAPONS.size()):
		var button := Button.new()
		button.text = WEAPONS[index]["label"]
		button.custom_minimum_size = Vector2(146, 30)
		button.pressed.connect(_select_weapon.bind(index))
		grid.add_child(button)
		_weapon_buttons.append(button)
	content.add_child(HSeparator.new())
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.modulate = Color("#7fe8ff")
	content.add_child(_title_label)
	_description_label = Label.new()
	_description_label.custom_minimum_size = Vector2(300, 72)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_description_label)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = Color("#ffd27b")
	content.add_child(_status_label)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	var reset_button := Button.new()
	reset_button.text = "重置靶机 [R]"
	reset_button.pressed.connect(_reset_targets)
	actions.add_child(reset_button)
	var menu_button := Button.new()
	menu_button.text = "返回主菜单"
	menu_button.pressed.connect(_return_to_main_menu)
	actions.add_child(menu_button)
	var performance_separator := HSeparator.new()
	content.add_child(performance_separator)
	var performance_heading := Label.new()
	performance_heading.text = "性能模拟"
	performance_heading.modulate = Color("#86e7ff")
	content.add_child(performance_heading)
	var performance_actions := HBoxContainer.new()
	content.add_child(performance_actions)
	for label_and_suite in [["快速", "quick"], ["压力", "stress"], ["全武器", "all_weapons"]]:
		var performance_button := Button.new()
		performance_button.text = str(label_and_suite[0])
		performance_button.custom_minimum_size = Vector2(74, 28)
		performance_button.pressed.connect(_run_performance_suite.bind(str(label_and_suite[1])))
		performance_actions.add_child(performance_button)
	var baseline_button := Button.new()
	baseline_button.text = "保存基线"
	baseline_button.pressed.connect(_save_latest_baseline)
	performance_actions.add_child(baseline_button)
	_performance_status_label = Label.new()
	_performance_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_performance_status_label.text = "性能测试：120 个真实敌人，全部武器自动测试；报告保存至 docs/performance/weapon_lab。"
	_performance_status_label.modulate = Color("#9fd6b8")
	content.add_child(_performance_status_label)


func _refresh_panel() -> void:
	if _title_label == null:
		return
	for index in range(_weapon_buttons.size()):
		_weapon_buttons[index].disabled = index == _current_index
		_weapon_buttons[index].modulate = Color("#86e7ff") if index == _current_index else Color.WHITE
	var effect_id := _current_weapon.active_skill_effect_id
	if _is_current_weapon_basic_only():
		_title_label.text = "%s · 普通攻击测试" % WEAPONS[_current_index]["label"]
		_description_label.text = "扇形发射随等级增加的多枚能量弹，并自动追踪飞行路线附近的敌人。\n该武器没有主动技能，请用鼠标左键测试。"
	else:
		_title_label.text = "%s · %s" % [WEAPONS[_current_index]["label"], SKILL_CATALOG.get_skill_name(effect_id)]
		var review_hint := str(WEAPONS[_current_index].get("review_hint", ""))
		var hint_line := "\n检查：%s" % review_hint if not review_hint.is_empty() else ""
		_description_label.text = "%s%s\n技能条件在测试场中始终就绪。" % [
			SKILL_CATALOG.get_skill_description(effect_id), hint_line,
		]


func _is_current_weapon_basic_only() -> bool:
	return bool(WEAPONS[_current_index].get("basic_only", false))


func _return_to_main_menu() -> void:
	if _performance_runner != null and _performance_runner.running:
		_performance_runner.cancel()
	_initialized = false
	PhaseManager.reset_runtime_state()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _setup_performance_runner() -> void:
	_performance_runner = PERFORMANCE_RUNNER.new()
	_performance_runner.name = "WeaponPerformanceRunner"
	add_child(_performance_runner)
	_performance_runner.setup(self)
	_performance_runner.suite_started.connect(_on_performance_suite_started)
	_performance_runner.scenario_started.connect(_on_performance_scenario_started)
	_performance_runner.progress_changed.connect(_on_performance_progress_changed)
	_performance_runner.suite_finished.connect(_on_performance_suite_finished)


func _run_performance_suite(suite_id: String) -> void:
	if _performance_runner == null or _performance_runner.running:
		return
	var scenarios: Array[WeaponPerformanceScenario]
	match suite_id:
		"extreme_performance":
			scenarios = PERFORMANCE_SCENARIO.extreme_performance_suite(WEAPONS.size())
		"extreme_flamethrower":
			var extreme_scenarios := PERFORMANCE_SCENARIO.extreme_performance_suite(WEAPONS.size())
			# Weapon catalog index 9 is the production flamethrower. Keep this
			# focused entry identical to the all-weapon workload so optimization
			# attempts can be compared without running the entire matrix.
			scenarios = [extreme_scenarios[9]]
		"extreme_flamethrower_no_skill":
			var attack_only := PERFORMANCE_SCENARIO.extreme_performance_suite(WEAPONS.size())[9]
			attack_only.scenario_id = "extreme_flamethrower_no_skill"
			attack_only.skill_pattern = &"none"
			scenarios = [attack_only]
		"extreme_flamethrower_skill_only":
			var skill_only := PERFORMANCE_SCENARIO.extreme_performance_suite(WEAPONS.size())[9]
			skill_only.scenario_id = "extreme_flamethrower_skill_only"
			skill_only.fire_pattern = &"none"
			scenarios = [skill_only]
		"extreme_enemy_idle":
			var enemy_idle := PERFORMANCE_SCENARIO.extreme_performance_suite(WEAPONS.size())[0]
			enemy_idle.scenario_id = "extreme_enemy_idle"
			enemy_idle.display_name = "极限敌群 · 玩家不开火"
			enemy_idle.fire_pattern = &"none"
			enemy_idle.skill_pattern = &"none"
			enemy_idle.hud_enabled = false
			scenarios = [enemy_idle]
		"stress":
			scenarios = PERFORMANCE_SCENARIO.stress_suite(_current_index)
		"all_weapons":
			scenarios = PERFORMANCE_SCENARIO.all_weapon_suite(WEAPONS.size())
		_:
			scenarios = PERFORMANCE_SCENARIO.quick_suite(_current_index)
	_performance_runner.run_suite(suite_id, scenarios)


func performance_prepare_scenario(scenario: WeaponPerformanceScenario) -> Dictionary:
	_initialized = false
	_panel.visible = scenario.hud_enabled
	await performance_cleanup_scenario()
	_place_player_at_board_center()
	_set_player_damage_targeting_enabled(false)
	_select_weapon(scenario.weapon_index)
	var targets := _spawn_performance_targets(scenario)
	_lifecycle_spawn_elapsed = 0.0
	_initialized = true
	return {
		"player": _player,
		"weapon": _current_weapon,
		"targets": targets,
		"weapon_label": str(WEAPONS[_current_index].get("label", "")),
	}


func performance_tick_scenario(scenario: WeaponPerformanceScenario, delta: float) -> void:
	if scenario == null or not (&"lifecycle" in scenario.tags):
		return
	_lifecycle_spawn_elapsed += maxf(delta, 0.0)
	if _lifecycle_spawn_elapsed < 1.0:
		return
	_lifecycle_spawn_elapsed = 0.0
	var living := get_tree().get_node_count_in_group(&"weapon_performance_lab_target")
	if living >= scenario.target_count:
		return
	var refill := PERFORMANCE_SCENARIO.from_dictionary(scenario.to_dictionary())
	refill.target_count = mini(12, scenario.target_count - living)
	refill.random_seed += int(Time.get_ticks_msec())
	_spawn_performance_targets(refill)


func performance_cleanup_scenario() -> void:
	Input.action_release("ATTACK")
	for action in ["UP", "DOWN", "LEFT", "RIGHT"]:
		Input.action_release(action)
	for target in get_tree().get_nodes_in_group(&"weapon_performance_lab_target"):
		if target != null and is_instance_valid(target):
			var enemy := target as BaseEnemy
			if enemy != null:
				enemy.erase()
			else:
				target.queue_free()
	_target_count = 0
	for group_name in [&"runtime_projectiles", &"runtime_area_effects"]:
		for transient in get_tree().get_nodes_in_group(group_name):
			if transient != null and is_instance_valid(transient):
				if transient.has_method("despawn"):
					transient.call("despawn")
				else:
					transient.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	if _player != null and is_instance_valid(_player):
		_place_player_at_board_center()
		_set_player_damage_targeting_enabled(true)
	_panel.visible = true


func _place_player_at_board_center() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var board := _world.get_node_or_null("Board") as BoardCellGenerator
	if board == null:
		return
	_player.global_position = board.get_center_cell_global_position()
	_player.velocity = Vector2.ZERO


func _set_player_damage_targeting_enabled(enabled: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var player_hurt_box := _player.hurt_box as HurtBox
	if player_hurt_box != null and is_instance_valid(player_hurt_box):
		player_hurt_box.set_collision_layer_value(1, enabled)


func _spawn_performance_targets(scenario: WeaponPerformanceScenario) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var lifecycle_storm := &"lifecycle" in scenario.tags
	var count := maxi(scenario.target_count, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = scenario.random_seed
	for index in count:
		var use_real_enemy := index < scenario.real_enemy_count
		var scene := REAL_ENEMY_SCENE if use_real_enemy else DUMMY_SCENE
		var enemy := scene.instantiate() as BaseEnemy
		if enemy == null:
			continue
		enemy.name = "PerformanceTarget%03d" % index
		enemy.damage = 0
		enemy.hp = 80 if lifecycle_storm else DUMMY_HP
		if not use_real_enemy:
			enemy.movement_speed = 0.0
		var angle := TAU * float(index) / float(maxi(count, 1))
		var ring := 260.0 + float(index % 5) * 54.0
		if scenario.target_layout == &"dense_grid":
			enemy.global_position = _player.global_position + Vector2((index % 12 - 6) * 58, (index / 12 - 5) * 58)
		else:
			enemy.global_position = _player.global_position + Vector2.from_angle(angle) * ring + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0))
		enemy.add_to_group(&"weapon_performance_lab_target")
		enemy.add_to_group(&"skill_gameplay_lab_dummy")
		_world.add_child(enemy)
		targets.append(enemy)
	_target_count = targets.size()
	return targets


func _save_latest_baseline() -> void:
	if _performance_runner == null or _performance_runner.latest_report.is_empty():
		_performance_status_label.text = "尚无可保存的性能报告。"
		return
	var saved := PERFORMANCE_REPORT.save_baseline(_performance_runner.latest_report)
	_performance_status_label.text = "性能基线已保存。" if saved else "性能基线保存失败。"


func _on_performance_suite_started(suite_id: String, scenario_count: int) -> void:
	_performance_status_label.text = "开始 %s：共 %d 项" % [suite_id, scenario_count]


func _on_performance_scenario_started(display_name: String, index: int, total: int) -> void:
	_performance_status_label.text = "[%d/%d] %s" % [index, total, display_name]


func _on_performance_progress_changed(message: String) -> void:
	if _performance_status_label != null:
		_performance_status_label.text = message


func _on_performance_suite_finished(report: Dictionary, report_path: String) -> void:
	_panel.visible = true
	if report_path.is_empty():
		_performance_status_label.text = "性能测试完成，但报告保存失败；请检查项目 docs 目录写入权限。"
	else:
		var aggregates := report.get("aggregates", []) as Array
		var summary_line := ""
		if not aggregates.is_empty():
			var last := aggregates.back() as Dictionary
			summary_line = "\n末项中位 P99 %.2f ms" % float(last.get("median_p99_frame_ms", 0.0))
		_performance_status_label.text = "完成 %d 次采样%s\n%s" % [int(report.get("scenario_count", 0)), summary_line, report_path]
	print("WEAPON_PERFORMANCE_REPORT=%s" % report_path)
	print("WEAPON_PERFORMANCE_SUMMARY=%s" % JSON.stringify({
		"suite_id": report.get("suite_id", ""),
		"scenario_count": report.get("scenario_count", 0),
		"report_saved": not report_path.is_empty(),
	}))
	if _autorun_performance:
		# The production cursor presenter owns a runtime ImageTexture. Release both
		# the DisplayServer cursor reference and the presenter reference before the
		# rendering server shuts down, otherwise graphical benchmark exits report a
		# leaked texture RID even though the world tree was cleaned correctly.
		var production_ui := _world.get_node_or_null("UI")
		if production_ui != null and production_ui.has_method("_clear_battle_hardware_cursor"):
			production_ui.call("_clear_battle_hardware_cursor")
			var presenter: Variant = production_ui.get("battle_cursor_presenter")
			if presenter != null:
				presenter.set("_battle_hardware_cursor_tex", null)
		await get_tree().process_frame
		await TEST_TEARDOWN.finish(_world, 0 if not report_path.is_empty() else 1, _reset_validation_state)


func _get_performance_suite_argument() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--run-weapon-performance="):
			return argument.trim_prefix("--run-weapon-performance=")
	return ""


func _run_contract_validation() -> void:
	var failures: Array[String] = []
	if not _world.world_build_complete:
		failures.append("production WorldShell did not complete")
	if _world.get_node_or_null("Board") == null or _world.get_node_or_null("UI") == null \
			or _world.get_node_or_null("HybridGroundView3D") == null:
		failures.append("production world components are missing")
	if _world.get_node_or_null("WorldReadyCoordinator") != null:
		failures.append("default ready coordinator was not suppressed")
	if get_tree().get_nodes_in_group(&"skill_gameplay_lab_dummy").size() != TARGET_OFFSETS.size():
		failures.append("fixed target count mismatch")
	var basic_only_count := 0
	for index in range(WEAPONS.size()):
		_select_weapon(index)
		await get_tree().process_frame
		var equipped_count := 0
		for child in _player.equppied_weapons.get_children():
			if child is Weapon:
				equipped_count += 1
		if equipped_count != 1:
			failures.append("selection %d left %d weapon nodes" % [index + 1, equipped_count])
		var basic_only := bool(WEAPONS[index].get("basic_only", false))
		if basic_only:
			basic_only_count += 1
			if _current_weapon == null or _current_weapon.active_skill_effect_id != StringName():
				failures.append("selection %d basic-only contract is invalid" % (index + 1))
			continue
		if _current_weapon == null or _current_weapon.active_skill_effect_id == StringName():
			failures.append("selection %d has no active skill" % (index + 1))
	if basic_only_count != 1:
		failures.append("expected one explicitly basic-only weapon")
	if failures.is_empty():
		print("WEAPON_ACTIVE_SKILL_GAMEPLAY_LAB: PASS")
		await TEST_TEARDOWN.finish(_world, 0, _reset_validation_state)
	else:
		for failure in failures:
			push_error("WEAPON_ACTIVE_SKILL_GAMEPLAY_LAB: %s" % failure)
		print("WEAPON_ACTIVE_SKILL_GAMEPLAY_LAB: FAIL")
		await TEST_TEARDOWN.finish(_world, 1, _reset_validation_state)
	_current_weapon = null
	_player = null
	_enemy_spawner = null
	_world = null
	_weapon_buttons.clear()


func _reset_validation_state() -> void:
	PlayerData.reset_runtime_state()
	PhaseManager.reset_runtime_state()


func _exit_tree() -> void:
	_initialized = false
	if _performance_runner != null:
		_performance_runner.cancel()
	if _enemy_spawner != null and is_instance_valid(_enemy_spawner):
		_enemy_spawner.stop_spawning()
	PhaseManager.cleanup_battle_runtime_transients()
