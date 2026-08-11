extends Control

const REWARD_PANEL_SCENE := preload("res://UI/scenes/reward_selection_panel.tscn")
const MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_crit_calibrator.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _panel: RewardSelectionPanel
var _showcase_weapons: Array[Weapon] = []
var _previous_weapon_list: Array = []
var _previous_locale := "en"
var _focus_index := 0


func _ready() -> void:
	call_deferred("_build_showcase")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or _panel == null:
		return
	match event.keycode:
		KEY_L:
			LocalizationManager.set_locale("zh_CN" if LocalizationManager.get_locale() == "en" else "en", false)
			_open_current_locale()
		KEY_F:
			_focus_index = (_focus_index + 1) % _panel.options_box.get_child_count()
			(_panel.options_box.get_child(_focus_index) as Button).grab_focus()
		KEY_H:
			_panel.call("_begin_quick_select_hold", _focus_index)
			_panel.call("_process", RewardSelectionPanel.QUICK_SELECT_HOLD_SECONDS * 0.65)
		KEY_R:
			_panel.call("_cancel_quick_select_hold")
			(_panel.options_box.get_child(0) as Button).grab_focus()
			_focus_index = 0


func _build_showcase() -> void:
	_previous_weapon_list = PlayerData.player_weapon_list.duplicate()
	_previous_locale = LocalizationManager.get_locale()
	LocalizationManager.set_locale("en", false)
	var prepare_result := DataHandler.prepare_world_data(true)
	if not bool(prepare_result.get("ok", false)):
		push_error("RewardDraftUnificationShowcase: failed to prepare world data: %s" % str(prepare_result.get("errors", [])))
		return
	CellEffectRuntime.prepare_definitions(true)
	_create_showcase_weapons(["1", "3"])
	_panel = REWARD_PANEL_SCENE.instantiate() as RewardSelectionPanel
	%Stage.add_child(_panel)
	await get_tree().process_frame
	_open_current_locale()
	print("REWARD_DRAFT_UNIFICATION_READY locale=%s cards=%d" % [LocalizationManager.get_locale(), _panel.options_box.get_child_count()])
	if DisplayServer.get_name() == "headless":
		await _validate_showcase()


func _open_current_locale() -> void:
	if _panel.visible:
		_panel.close_panel()
	var rewards: Array[RewardInfo] = [_make_weapon_reward(), _make_module_reward(), _make_economy_reward()]
	var subtitle := "Compare the primary effect, exact outcome, and build fit before confirming. Hold 1–3 for a quick choice."
	if LocalizationManager.get_locale() == "zh_CN":
		subtitle = "确认前请比较核心效果、精确结果与构筑适配度；也可长按数字键 1–3 快速选择。"
	_panel.open_for_rewards("Showcase", rewards, Callable(), Callable(), false, "", subtitle, 1, 3, false)


func _validate_showcase() -> void:
	await get_tree().process_frame
	assert(_panel.options_box.get_child_count() == 3)
	assert(_panel.options_box.columns == 3)
	assert(int(_panel.get("_selected_index")) == 0)
	assert(_panel.get_node_or_null("Panel/VBox/SelectedDetail") == null)
	for index in range(3):
		var card := _panel.options_box.get_child(index) as Button
		assert(card.tooltip_text == "")
		assert(card.find_child("RewardIcon", true, false) != null or card.find_child("WeaponHeroImage", true, false) != null)
		if card.find_child("WeaponHeroImage", true, false) != null:
			var weapon_name := card.find_child("WeaponRewardName", true, false) as Label
			assert(weapon_name != null and weapon_name.text.strip_edges() != "")
		assert(card.focus_neighbor_left != NodePath("") and card.focus_neighbor_right != NodePath(""))
	(_panel.options_box.get_child(1) as Button).grab_focus()
	await get_tree().process_frame
	assert(int(_panel.get("_selected_index")) == 1)
	assert(get_viewport().gui_get_focus_owner() == _panel.options_box.get_child(1))
	var space_event := InputEventKey.new()
	space_event.keycode = KEY_SPACE
	space_event.pressed = true
	_panel.call("_input", space_event)
	assert(int(_panel.get("_selected_index")) == 1)
	assert(get_viewport().gui_get_focus_owner() == _panel.options_box.get_child(1))
	_panel.call("_begin_quick_select_hold", 2)
	_panel.call("_process", RewardSelectionPanel.QUICK_SELECT_HOLD_SECONDS * 0.65)
	var hold_progress := (_panel.options_box.get_child(2) as Button).find_child("HoldProgress", true, false) as ProgressBar
	assert(hold_progress.visible and hold_progress.value > 0.6 and hold_progress.value < 0.7)
	_panel.call("_cancel_quick_select_hold")
	LocalizationManager.set_locale("zh_CN", false)
	_open_current_locale()
	await get_tree().process_frame
	assert(_panel.options_box.get_child_count() == 3)
	assert(_panel.subtitle_label.text.contains("确认前"))
	print("PASS: reward draft showcase covers three self-contained cards, long bilingual copy, focus, and hold states")
	await TEST_TEARDOWN.finish(self, 0, _reset_runtime_state, [_panel])


func _create_showcase_weapons(weapon_ids: PackedStringArray) -> void:
	for weapon_id in weapon_ids:
		var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if definition == null or definition.scene == null:
			continue
		var weapon := definition.scene.instantiate() as Weapon
		if weapon == null:
			continue
		weapon.visible = false
		%RuntimeFixtures.add_child(weapon)
		_showcase_weapons.append(weapon)
	PlayerData.player_weapon_list = _showcase_weapons.duplicate()


func _make_weapon_reward() -> RewardInfo:
	var reward := RewardInfo.new()
	reward.item_id = "2"
	reward.item_level = 1
	reward.rarity = "rare"
	return reward


func _make_module_reward() -> RewardInfo:
	var reward := RewardInfo.new()
	reward.module_scene = MODULE_SCENE
	reward.module_level = 1
	reward.rarity = "rare"
	return reward


func _make_economy_reward() -> RewardInfo:
	var reward := RewardInfo.new()
	reward.reward_kind = RewardInfo.KIND_ECONOMY
	reward.gold_value = 120
	reward.total_chip_value = 40
	reward.rarity = "common"
	return reward


func _exit_tree() -> void:
	_reset_runtime_state()


func _reset_runtime_state() -> void:
	PlayerData.player_weapon_list = _previous_weapon_list
	if _panel != null and is_instance_valid(_panel):
		var language_callback := Callable(_panel, "_on_language_changed")
		if LocalizationManager.language_changed.is_connected(language_callback):
			LocalizationManager.language_changed.disconnect(language_callback)
	LocalizationManager.set_locale(_previous_locale, false)
	_showcase_weapons.clear()
	_panel = null
