extends Node2D

# Real UI shell and controller, sample economy/health; no battle or reward saves.
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
var _ui: UI
var _state := 0
var _capture_dir := ""
var _caption: Label

func _ready() -> void:
	LocalizationManager.set_locale("zh_CN", false)
	DataHandler.prepare_world_data(true)
	PhaseManager.phase = PhaseManager.BATTLE
	PlayerData.gold_supply_enabled = true
	PlayerData.set("_gold_supply_rules", {"thresholds": [30, 40, 50]})
	_ui = UI_SCENE.instantiate()
	add_child(_ui)
	# Freeze gameplay-data refresh; keep the actual HUD/controller animations live.
	_ui.set_process(false)
	_ui.set_physics_process(false)
	_ui.hud_presenter.health_meter.call("set_health", 72, 100, 20, 100)
	_ui.hud_presenter.health_meter.call("set_energy", 100.0, 150.0)
	_ui.hud_presenter._sync_primary_resource_slot({"type": "heat", "ratio": 0.6, "short_text": "60/100", "state": "normal"})
	_ui.gold_supply_controller.button.pressed.disconnect(_ui.gold_supply_controller.open_supply)
	_ui.gold_supply_controller.button.pressed.connect(func(): _set_state(3))
	_caption = Label.new()
	_caption.position = Vector2(360, 160)
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.text = "金币补给 HUD · 运行时 UI / 示例数据\n1 积累中  2 首次就绪  3 多份就绪\n4 选择中  5 菜单阻挡  6 应用反馈\nL 中英文切换 · G 查看选择状态"
	add_child(_caption)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	_set_state(0)
	if not _capture_dir.is_empty():
		_capture_sequence()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("15282d"))
	for x in range(0, int(get_viewport_rect().size.x), 48):
		draw_line(Vector2(x, 0), Vector2(x, get_viewport_rect().size.y), Color("223b40"))
	for y in range(0, int(get_viewport_rect().size.y), 48):
		draw_line(Vector2(0, y), Vector2(get_viewport_rect().size.x, y), Color("223b40"))

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		_set_state(event.keycode - KEY_1)
	elif event.keycode == KEY_L:
		LocalizationManager.set_locale("en" if LocalizationManager.get_locale() == "zh_CN" else "zh_CN", false)
		_set_state(_state)
	elif event.is_action_pressed("CLAIM_SUPPLY"):
		_set_state(3)
	else:
		return
	get_viewport().set_input_as_handled()

func _set_state(value: int) -> void:
	_state = value
	get_tree().paused = false
	if value == 0:
		_ui.gold_supply_controller._reset_feedback()
	var count := 0 if value == 0 or value == 5 else (2 if value == 2 else 1)
	var pending: Array[Dictionary] = []
	for index in count:
		pending.append({"sequence": index + 1, "quality": "common", "status": "ready"})
	PlayerData.set("_pending_gold_supplies", pending)
	PlayerData.gold_supply_progress = 18 if value == 0 else 4
	PlayerData.gold_supply_level = count
	_ui.gold_supply_controller.refresh()
	if value == 3 or value == 4:
		get_tree().paused = true
		_ui.gold_supply_controller.refresh()
		if value == 3:
			_ui.gold_supply_controller.ready_label.text = LocalizationManager.tr_key("ui.supply.choosing", "Choosing upgrade")
	if value == 5:
		var weapon_name := LocalizationManager.get_weapon_name_by_id("1", "Machine gun")
		_ui.gold_supply_controller.button.call("show_feedback", LocalizationManager.tr_format("ui.supply.applied", {"reward": weapon_name + " · Lv.1 → Lv.2"}, "Supply applied: {reward}"), 2.0)
	queue_redraw()

func _capture_sequence() -> void:
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for locale in ["zh_CN", "en"]:
		LocalizationManager.set_locale(locale, false)
		for value in 6:
			_set_state(value)
			await get_tree().create_timer(0.4, true).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_capture_dir.path_join("supply_%s_%d.png" % [locale, value]))
	get_tree().paused = false
	LocalizationManager.set_locale("zh_CN", false)
	_set_state(2)
	print("GOLD_SUPPLY_HUD_SHOWCASE_CAPTURES_READY: ", _capture_dir)
