extends Control
## Manual visual tool using real panel/cards and isolated offer data. No combat starts.
const PANEL := preload("res://UI/scenes/battle_contract_selection_panel.tscn")
var panel: Control
var locale := "zh_CN"
var count := 3
var group := 0
var state_index := 0
var prototype := false
var presenter: BattleContractHudPresenter
var motion := false
var groups := [["elimination", "survival", "reward"], ["operation", "containment", "extraction"], ["rest", "finale", "elimination"]]

func _ready() -> void:
	prototype = "--prototype" in OS.get_cmdline_user_args()
	locale = "en" if "--english" in OS.get_cmdline_user_args() else "zh_CN"
	panel = PANEL.instantiate()
	add_child(panel)
	presenter = BattleContractHudPresenter.new()
	presenter.bind(self, self)
	_open()
	if "--capture" in OS.get_cmdline_user_args():
		_capture_matrix()
	elif "--interactions" in OS.get_cmdline_user_args():
		_capture_interactions()

func _open() -> void:
	panel.dismiss()
	BattleContractManager.reset_runtime_state()
	presenter.panel.visible = false
	panel.animations_enabled = motion
	LocalizationManager.set_locale(locale, false)
	var options: Array[BattleContractDefinition] = []
	for index in count:
		options.append(load("res://data/battle_contracts/%s.tres" % ("elimination" if prototype else groups[group][index])))
	BattleContractManager.set_offer(options)
	panel.open(options, _confirm)

func _confirm() -> void:
	print("VISUAL: Space/confirm callback received; showcase does not start combat.")
	panel.set("_locked", false)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_F1:
			locale = "en" if locale == "zh_CN" else "zh_CN"
			_open()
		KEY_F2:
			count = 2 if count == 3 else 3
			_open()
		KEY_F3:
			group = (group + 1) % groups.size()
			_open()
		KEY_F4:
			state_index = (state_index + 1) % 10
			_apply_state(state_index)
		KEY_F5:
			motion = not motion
			_open()
		KEY_F6:
			_long_copy()
		KEY_F7:
			_handoff()
		KEY_F8:
			_capture("manual")

func _apply_state(value: int) -> void:
	var card: Button = panel.cards[0]
	card.disabled = false
	card.release_focus()
	card.set_selected(false, false)
	card.set_enhanced_mode(false)
	card.get_node("RareFrame").visible = false
	card.get_node("StateBadges/Rare").visible = false
	Input.warp_mouse(Vector2(4, 4))
	match value:
		1: card.grab_focus()
		2: panel._select_card_by_index(0)
		3:
			panel._select_card_by_index(0)
			card.set_enhanced_offer(["移动速度提高；最后一批出现精英" if locale == "zh_CN" else "Faster enemies; the final wave includes an elite"], ["额外随机奖励" if locale == "zh_CN" else "Additional random reward"])
			card.set_enhanced_mode(true)
		4:
			card.get_node("RareFrame").visible = true
			card.get_node("StateBadges/Rare").visible = true
		5: card.disabled = true
		6:
			card.set("_presentation", {})
			card._apply_art()
		7:
			card.setup(card.definition)
			_pointer(card.get_global_rect().position + Vector2(120, 65))
		8:
			_apply_state(3)
			card.get_node("RareFrame").visible = true
			card.get_node("StateBadges/Rare").visible = true
			_pointer(card.get_global_rect().position + Vector2(120, 65))
		9:
			var catalog: Resource = card.PRESENTATION
			var saved: Dictionary = catalog.textures
			catalog.textures = {}
			card.set("_presentation", {})
			card._apply_art()
			card._apply_card_styles()
			catalog.textures = saved

func _capture_matrix() -> void:
	if "--sizes" in OS.get_cmdline_user_args():
		for width in [1280, 1600]:
			get_window().size = Vector2i(width, 720)
			await get_tree().process_frame
			await get_tree().process_frame
			await _capture_catalog()
	else:
		await _capture_catalog()
	print("VISUAL: capture matrix complete; review screenshots. Window remains open.")

func _capture_catalog() -> void:
	if "--all-groups" in OS.get_cmdline_user_args():
		for index in groups.size():
			group = index
			await _capture_group()
	else:
		await _capture_group()

func _capture_group() -> void:
	for language in ["zh_CN", "en"]:
		locale = language
		for number in [2, 3]:
			count = number
			_open()
			await get_tree().create_timer(0.9).timeout
			for state in range(10):
				_apply_state(state)
				await get_tree().create_timer(0.2).timeout
				await _capture("g%d_%s_%d_%d" % [group, locale, count, state])

func _capture(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	var root := ProjectSettings.globalize_path("res://tmp/protocol_visual")
	DirAccess.make_dir_recursive_absolute(root)
	var ignore := FileAccess.open(root.path_join(".gdignore"), FileAccess.WRITE)
	ignore.store_string("")
	ignore.close()
	var dimensions := "%dx%d_" % [get_viewport_rect().size.x, get_viewport_rect().size.y]
	get_viewport().get_texture().get_image().save_png(root.path_join(dimensions + suffix + ".png"))
	print("VISUAL: captured ", suffix)
	if suffix.ends_with("_0"):
		for card in panel.cards:
			if card.visible:
				print("GEOMETRY: ", card.definition.contract_id, " card=", card.get_global_rect(), " art=", card.get_node("Margin/Content/ObjectiveGap/Illustration").get_global_rect())

func _pointer(point: Vector2) -> void:
	Input.warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

func _click(point: Vector2) -> void:
	_pointer(point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

func _long_copy() -> void:
	var card: Button = panel.cards[0]
	card.get_node("Margin/Content/Title").text = "持续作战环境下的高风险歼灭协议" if locale == "zh_CN" else "Extended high-risk elimination protocol in contested territory"
	card.set_enhanced_offer([("所有敌人移动速度提升，并且最后一波会部署更多精英敌人。" if locale == "zh_CN" else "All enemies move faster and the final wave deploys additional elite reinforcements. ").repeat(3)], ["额外随机奖励" if locale == "zh_CN" else "Additional random reward"])
	card.set_enhanced_mode(true)

func _handoff() -> void:
	panel._select_card_by_index(0)
	var definition: Resource = panel.cards[0].definition
	var card: Button = panel.detach_selected_card(self)
	if card == null:
		return
	panel.dismiss()
	# Presentation fixture only; no encounter or rule execution.
	BattleContractManager.state = BattleContractManager.ACTIVE
	BattleContractManager.runtime_snapshot = {"contract_id": "elimination", "current_batch": 1, "total_batches": 3, "planned_hp": 100, "active_enemies": 3}
	presenter.layout(get_viewport_rect().size)
	presenter.title.text = LocalizationManager.tr_key(definition.name_key)
	presenter.value.text = "1 / 3"
	presenter.prepare_contract_intro(card, definition)
	await presenter.play_prepared_intro()
	print("VISUAL: real presenter handoff completed; sample HUD data only.")

func _capture_interactions() -> void:
	await get_tree().create_timer(1.0).timeout
	for code in [KEY_1, KEY_2, KEY_3]:
		await _key(code)
		await _capture("key_%d" % code)
		print("VISUAL: key ", code, " selected ", BattleContractManager.selected_contract.contract_id)
	await _key(KEY_SPACE)
	await _click(panel.cards[0].get_global_rect().position + Vector2(100, 70))
	print("VISUAL: pointer selected ", BattleContractManager.selected_contract.contract_id)
	await _click(panel.cards[0].get_node("EnhancementToggle").get_global_rect().get_center())
	print("VISUAL: toggle state ", panel.cards[0].is_enhanced_mode())
	await _capture("pointer_toggle")
	panel.cards[0].get_node("EnhancementToggle").grab_focus()
	await _key(KEY_ENTER)
	print("VISUAL: Enter toggle state ", panel.cards[0].is_enhanced_mode())
	await _key(KEY_ENTER)
	print("VISUAL: second Enter toggle state ", panel.cards[0].is_enhanced_mode())
	await _key(KEY_TAB)
	await _capture("keyboard_focus")
	motion = false
	_open()
	await get_tree().process_frame
	_apply_state(8)
	await _capture("no_motion_combined")
	_long_copy()
	await _capture("long_copy_top")
	panel.cards[0].grab_focus()
	for step in 8:
		await _key(KEY_PAGEDOWN)
	await _capture("long_copy_bottom")
	motion = true
	_open()
	await get_tree().create_timer(0.9).timeout
	_handoff()
	await get_tree().create_timer(0.6).timeout
	await _capture("handoff_intro")
	await get_tree().create_timer(2.6).timeout
	await _capture("handoff_final")
	motion = false
	_open()
	await get_tree().process_frame
	presenter.panel.visible = true
	await _handoff()
	await _capture("handoff_no_motion")
