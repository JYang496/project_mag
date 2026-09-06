extends Node2D

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const DUMMY_SCENE := preload("res://Npc/enemy/scenes/dummy.tscn")
const SKILL_CATALOG := preload("res://Player/Weapons/Core/weapon_active_skill_catalog.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

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
const DUMMY_POSITIONS: Array[Vector2] = [
	Vector2(-250, -130), Vector2(-70, -150), Vector2(120, -145), Vector2(300, -125), Vector2(455, -95),
	Vector2(-270, 30), Vector2(270, 30), Vector2(455, 45),
	Vector2(-250, 210), Vector2(-70, 235), Vector2(130, 230), Vector2(330, 205),
]
const DUMMY_HP := 1000000

var _player: Player
var _current_weapon: Weapon
var _current_index := 0
var _title_label: Label
var _description_label: Label
var _status_label: Label
var _weapon_buttons: Array[Button] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#071019"))
	PhaseManager.phase = PhaseManager.BATTLE
	_build_interface()
	_spawn_dummies()
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	_player.global_position = Vector2.ZERO
	await get_tree().process_frame
	_select_weapon(0)
	if OS.get_cmdline_user_args().has("--validate-weapon-skill-lab"):
		await _run_headless_contract()
	elif OS.get_cmdline_user_args().has("--capture-weapon-skill-lab"):
		await _capture_showcase()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_Q:
			_select_weapon(posmod(_current_index - 1, WEAPONS.size()))
			get_viewport().set_input_as_handled()
		KEY_E:
			_select_weapon((_current_index + 1) % WEAPONS.size())
			get_viewport().set_input_as_handled()
		KEY_C:
			call_deferred("_activate_current_skill")
			get_viewport().set_input_as_handled()
		KEY_R:
			_reset_dummies()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _current_weapon == null or not is_instance_valid(_current_weapon):
		return
	var status := _current_weapon.get_weapon_skill_status()
	var state := "技能就绪"
	if bool(status.get("active", false)):
		state = "技能生效中 %.1fs" % float(status.get("active_remaining", 0.0))
	elif float(status.get("cooldown_remaining", 0.0)) > 0.0:
		state = "冷却 %.1fs（按 C 可在演练场强制重置）" % float(status.get("cooldown_remaining", 0.0))
	_status_label.text = "%s  |  靶机 %d/%d  |  鼠标左键普通攻击" % [state, get_tree().get_nodes_in_group(&"skill_lab_dummy").size(), DUMMY_POSITIONS.size()]


func _select_weapon(index: int) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_current_index = clampi(index, 0, WEAPONS.size() - 1)
	# The production Player creates its default machine gun during custom_ready().
	# Clear the authoritative holder as well as PlayerData so that default or stale
	# weapon nodes cannot survive as visible, untracked equipment in the lab.
	for child in _player.equppied_weapons.get_children():
		var equipped_weapon := child as Weapon
		if equipped_weapon == null:
			continue
		equipped_weapon.clear_timed_effects_for_prepare()
		equipped_weapon.visible = false
		equipped_weapon.queue_free()
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
	_refresh_selection_ui()


func _activate_current_skill() -> void:
	if _current_weapon == null or not is_instance_valid(_current_weapon):
		return
	_current_weapon.skill_runtime.force_ready()
	_player.add_energy(_player.player_max_energy)
	var activated := _current_weapon.request_weapon_skill()
	_status_label.text = "已触发技能；若技能强化下一次攻击，请按鼠标左键射击。" if activated else "触发失败：请将鼠标指向靶机后再次按 C。"


func _refresh_selection_ui() -> void:
	for index in range(_weapon_buttons.size()):
		var button := _weapon_buttons[index]
		button.disabled = index == _current_index
		button.modulate = Color("#86e7ff") if index == _current_index else Color.WHITE
	var effect_id := _current_weapon.active_skill_effect_id
	_title_label.text = "%s  ·  %s" % [WEAPONS[_current_index]["label"], SKILL_CATALOG.get_skill_name(effect_id)]
	_description_label.text = "%s\n触发：C（演练场会自动补能量、解除冷却及解锁条件）" % SKILL_CATALOG.get_skill_description(effect_id)


func _spawn_dummies() -> void:
	for index in range(DUMMY_POSITIONS.size()):
		var dummy := DUMMY_SCENE.instantiate() as BaseEnemy
		dummy.name = "SkillTarget%02d" % (index + 1)
		dummy.hp = DUMMY_HP
		dummy.damage = 0
		dummy.movement_speed = 0.0
		dummy.global_position = DUMMY_POSITIONS[index]
		dummy.add_to_group(&"skill_lab_dummy")
		add_child(dummy)


func _reset_dummies() -> void:
	for dummy in get_tree().get_nodes_in_group(&"skill_lab_dummy"):
		if dummy != null and is_instance_valid(dummy):
			dummy.queue_free()
	_spawn_dummies()
	_status_label.text = "全部高血量靶机已重置。"


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(254, 688)
	root.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	panel.add_child(list)
	var heading := Label.new()
	heading.text = "武器主动技能演练场"
	heading.add_theme_font_size_override("font_size", 20)
	list.add_child(heading)
	var help := Label.new()
	help.text = "Q/E 顺序切换  ·  C 技能  ·  R 重置"
	help.modulate = Color("#93afba")
	list.add_child(help)
	var separator := HSeparator.new()
	list.add_child(separator)
	for index in range(WEAPONS.size()):
		var button := Button.new()
		button.text = WEAPONS[index]["label"]
		button.custom_minimum_size = Vector2(224, 32)
		button.pressed.connect(_select_weapon.bind(index))
		list.add_child(button)
		_weapon_buttons.append(button)

	var info := PanelContainer.new()
	info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info.position = Vector2(-620, 16)
	info.size = Vector2(600, 126)
	root.add_child(info)
	var info_box := VBoxContainer.new()
	info.add_child(info_box)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.modulate = Color("#86e7ff")
	info_box.add_child(_title_label)
	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(560, 54)
	info_box.add_child(_description_label)
	_status_label = Label.new()
	_status_label.modulate = Color("#ffd27b")
	info_box.add_child(_status_label)

	var reset_button := Button.new()
	reset_button.text = "重置靶机 [R]"
	reset_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	reset_button.position = Vector2(-174, -60)
	reset_button.size = Vector2(154, 40)
	reset_button.pressed.connect(_reset_dummies)
	root.add_child(reset_button)


func _draw() -> void:
	for x in range(-700, 701, 80):
		draw_line(Vector2(x, -400), Vector2(x, 400), Color("#102735"), 1.0)
	for y in range(-400, 401, 80):
		draw_line(Vector2(-700, y), Vector2(700, y), Color("#102735"), 1.0)
	draw_circle(Vector2.ZERO, 88.0, Color("#0d3442"), false, 2.0)
	for position in DUMMY_POSITIONS:
		draw_circle(position, 30.0, Color("#7fd7e2"), false, 1.0)


func _run_headless_contract() -> void:
	var failures: Array[String] = []
	if WEAPONS.size() != 15:
		failures.append("expected 15 selectable weapons")
	if _weapon_buttons.size() != WEAPONS.size():
		failures.append("weapon button count mismatch")
	if get_tree().get_nodes_in_group(&"skill_lab_dummy").size() != DUMMY_POSITIONS.size():
		failures.append("dummy target count mismatch")
	var effect_ids: Dictionary = {}
	for index in range(WEAPONS.size()):
		_select_weapon(index)
		await get_tree().process_frame
		var equipped_count := 0
		for child in _player.equppied_weapons.get_children():
			if child is Weapon:
				equipped_count += 1
		if equipped_count != 1:
			failures.append("weapon %d selection left %d equipped weapon nodes" % [index + 1, equipped_count])
		if _current_weapon == null or _current_weapon.active_skill_effect_id == StringName():
			failures.append("weapon %d has no active skill effect" % (index + 1))
			continue
		effect_ids[_current_weapon.active_skill_effect_id] = true
		_current_weapon.skill_runtime.force_ready()
		_player.add_energy(_player.player_max_energy)
		if not _current_weapon.request_weapon_skill():
			failures.append("weapon %d active skill request failed" % (index + 1))
	if effect_ids.size() != WEAPONS.size():
		failures.append("active skill effect ids are not unique")
	if failures.is_empty():
		print("WEAPON_ACTIVE_SKILL_LAB: PASS")
		await TEST_TEARDOWN.finish(self, 0, _reset_validation_state)
	else:
		for failure in failures:
			push_error("WEAPON_ACTIVE_SKILL_LAB: %s" % failure)
		print("WEAPON_ACTIVE_SKILL_LAB: FAIL")
		await TEST_TEARDOWN.finish(self, 1, _reset_validation_state)
	_current_weapon = null
	_player = null
	_weapon_buttons.clear()


func _reset_validation_state() -> void:
	PlayerData.reset_runtime_state()
	PhaseManager.phase = PhaseManager.REST


func _capture_showcase() -> void:
	_select_weapon(1)
	await get_tree().process_frame
	var targets := get_tree().get_nodes_in_group(&"skill_lab_dummy")
	if targets.size() > 2:
		var damage_data := DamageManager.build_damage_data(
			_current_weapon, 99, Attack.TYPE_ENERGY,
			{"amount": 0, "angle": Vector2.ZERO},
			DamageData.SOURCE_PLAYER_WEAPON, DamageDeliveryType.PROJECTILE
		)
		DamageManager.apply_to_target(targets[2], damage_data)
	for _frame in range(5):
		await get_tree().process_frame
	var directory := ProjectSettings.globalize_path("res://output/showcases/weapon")
	DirAccess.make_dir_recursive_absolute(directory)
	var capture_path := directory.path_join("weapon_active_skill_lab.png")
	var error := get_viewport().get_texture().get_image().save_png(capture_path)
	print("SHOWCASE_CAPTURE=%s" % capture_path)
	print("SHOWCASE_CAPTURE_STATUS=%s" % error_string(error))
	await TEST_TEARDOWN.finish(self, 0 if error == OK else 1, _reset_validation_state)
	_current_weapon = null
	_player = null
	_weapon_buttons.clear()
