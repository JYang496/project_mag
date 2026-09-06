extends Node

const DUMMY_SCENE := preload("res://Npc/enemy/scenes/dummy.tscn")
const SKILL_CATALOG := preload("res://Player/Weapons/Core/weapon_active_skill_catalog.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const MAIN_MENU_SCENE := "res://World/Start.tscn"
const DUMMY_HP := 1000000
const WEAPONS: Array[Dictionary] = [
	{"label": "01 机枪", "scene": preload("res://Player/Weapons/Instances/machine_gun.tscn")},
	{"label": "02 蓄力炮", "scene": preload("res://Player/Weapons/Instances/charged_blaster.tscn")},
	{"label": "03 长矛", "scene": preload("res://Player/Weapons/Instances/spear_launcher.tscn")},
	{"label": "04 霰弹枪", "scene": preload("res://Player/Weapons/Instances/shotgun.tscn")},
	{"label": "06 轨道卫星", "scene": preload("res://Player/Weapons/Instances/orbit.tscn")},
	{"label": "07 火箭筒", "scene": preload("res://Player/Weapons/Instances/rocket_launcher.tscn")},
	{"label": "08 激光器", "scene": preload("res://Player/Weapons/Instances/laser.tscn")},
	{"label": "09 电锯", "scene": preload("res://Player/Weapons/Instances/chainsaw_launcher.tscn")},
	{"label": "10 冲刺刀", "scene": preload("res://Player/Weapons/Instances/dash_blade.tscn")},
	{"label": "11 喷火器", "scene": preload("res://Player/Weapons/Instances/flamethrower.tscn")},
	{"label": "12 等离子矛", "scene": preload("res://Player/Weapons/Instances/plasma_lance.tscn")},
	{"label": "13 冰川投射器", "scene": preload("res://Player/Weapons/Instances/glacier_projector.tscn")},
	{"label": "14 加农炮", "scene": preload("res://Player/Weapons/Instances/cannon.tscn")},
	{"label": "15 狙击枪", "scene": preload("res://Player/Weapons/Instances/sniper.tscn")},
]
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
	_initialized = true
	if OS.get_cmdline_user_args().has("--validate-weapon-gameplay-lab"):
		await _run_contract_validation()


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


func _process(_delta: float) -> void:
	if not _initialized or _current_weapon == null or not is_instance_valid(_current_weapon):
		return
	# Keep the production input path authoritative: C is still handled by Player.
	# The lab only maintains the prerequisites so every press can be inspected.
	_current_weapon.skill_runtime.force_ready()
	_player.add_energy(_player.player_max_energy)
	var status := _current_weapon.get_weapon_skill_status()
	var active_text := "技能就绪"
	if bool(status.get("active", false)):
		active_text = "生效中 %.1fs" % float(status.get("active_remaining", 0.0))
	_status_label.text = "%s  |  靶机 %d/%d  |  F2 隐藏面板" % [
		active_text,
		get_tree().get_nodes_in_group(&"skill_gameplay_lab_dummy").size(),
		TARGET_OFFSETS.size(),
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
		_world.add_child(dummy)


func _reset_targets() -> void:
	for target in get_tree().get_nodes_in_group(&"skill_gameplay_lab_dummy"):
		if target != null and is_instance_valid(target):
			target.queue_free()
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
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	var heading := Label.new()
	heading.text = "实际战场 · 主动技能测试"
	heading.add_theme_font_size_override("font_size", 18)
	heading.modulate = Color("#86e7ff")
	content.add_child(heading)
	var help := Label.new()
	help.text = "Q/E 切换  C 技能  左键攻击  R 重置"
	help.modulate = Color("#a8bac2")
	content.add_child(help)
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


func _refresh_panel() -> void:
	if _title_label == null:
		return
	for index in range(_weapon_buttons.size()):
		_weapon_buttons[index].disabled = index == _current_index
		_weapon_buttons[index].modulate = Color("#86e7ff") if index == _current_index else Color.WHITE
	var effect_id := _current_weapon.active_skill_effect_id
	_title_label.text = "%s · %s" % [WEAPONS[_current_index]["label"], SKILL_CATALOG.get_skill_name(effect_id)]
	_description_label.text = "%s\n技能条件在测试场中始终就绪。" % SKILL_CATALOG.get_skill_description(effect_id)


func _return_to_main_menu() -> void:
	_initialized = false
	PhaseManager.reset_runtime_state()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


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
	for index in range(WEAPONS.size()):
		_select_weapon(index)
		await get_tree().process_frame
		var equipped_count := 0
		for child in _player.equppied_weapons.get_children():
			if child is Weapon:
				equipped_count += 1
		if equipped_count != 1:
			failures.append("selection %d left %d weapon nodes" % [index + 1, equipped_count])
		if _current_weapon == null or _current_weapon.active_skill_effect_id == StringName():
			failures.append("selection %d has no active skill" % (index + 1))
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
	if _enemy_spawner != null and is_instance_valid(_enemy_spawner):
		_enemy_spawner.stop_spawning()
	PhaseManager.cleanup_battle_runtime_transients()
