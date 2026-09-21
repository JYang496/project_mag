extends Control

const REWARD_PANEL_SCRIPT := preload("res://UI/components/RewardSelectionPanel/RewardSelectionPanel.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const SHOWCASE_TAGS := [&"ammo", &"heat", &"physical", &"projectile"]

var _card_builder: Node
var _card: Button
var _tag_chips := {}


func _ready() -> void:
	call_deferred("_build_showcase")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_0:
		_restore_default_state()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
		_focus_tag(SHOWCASE_TAGS[event.keycode - KEY_1])


func _build_showcase() -> void:
	LocalizationManager.set_locale("zh_CN", false)
	var prepare_result := DataHandler.prepare_world_data(true)
	if not bool(prepare_result.get("ok", false)):
		push_error("WeaponCoreCardShowcase: failed to prepare world data: %s" % str(prepare_result.get("errors", [])))
		return
	_card_builder = REWARD_PANEL_SCRIPT.new()
	var reward := RewardInfo.new()
	reward.reward_kind = RewardInfo.KIND_WEAPON_CORE
	reward.item_id = "1"
	reward.core_amount = 1
	reward.core_tags = [&"physical", &"projectile", &"heat", &"ammo"]
	_card = _card_builder.call("_build_reward_card_button", reward, 0) as Button
	_card.custom_minimum_size = Vector2(330.0, 510.0)
	%CardStage.add_child(_card)
	_collect_tag_chips()
	_build_state_buttons()
	_update_state_label("默认：不显示支持武器；聚焦标签后展开")
	print("WEAPON_CORE_CARD_SHOWCASE_READY tags=%d" % _tag_chips.size())
	if DisplayServer.get_name() == "headless":
		await _validate_showcase()


func _collect_tag_chips() -> void:
	_tag_chips.clear()
	var grid := _card.find_child("BuildChipRow", true, false) as GridContainer
	if grid == null:
		return
	for child in grid.get_children():
		var chip := child as Control
		var tag_key := StringName(chip.get_meta(&"core_tag_key", ""))
		if tag_key != StringName():
			_tag_chips[tag_key] = chip


func _build_state_buttons() -> void:
	var default_button := Button.new()
	default_button.text = "0  取消标签聚焦"
	default_button.pressed.connect(_restore_default_state)
	%StateButtons.add_child(default_button)
	for index in range(SHOWCASE_TAGS.size()):
		var tag: StringName = SHOWCASE_TAGS[index]
		var chip := _tag_chips.get(tag) as Control
		var label := chip.find_child("Label", true, false) as Label if chip != null else null
		var button := Button.new()
		button.text = "%d  %s" % [index + 1, label.text if label != null else str(tag)]
		button.pressed.connect(_focus_tag.bind(tag))
		%StateButtons.add_child(button)


func _focus_tag(tag: StringName) -> void:
	var chip := _tag_chips.get(tag) as Control
	if chip == null:
		return
	chip.grab_focus()
	var label := chip.find_child("Label", true, false) as Label
	_update_state_label("当前聚焦：%s；卡片下方仅显示该标签支持的武器" % (label.text if label != null else str(tag)))


func _restore_default_state() -> void:
	if _card == null:
		return
	_card.grab_focus()
	var content := _card.find_child("WeaponCoreContent", true, false) as VBoxContainer
	if content != null:
		content.call("_restore_default_usage")
	_update_state_label("默认：不显示支持武器；聚焦标签后展开")


func _update_state_label(text: String) -> void:
	%CurrentState.text = text


func _exit_tree() -> void:
	if _card_builder != null and is_instance_valid(_card_builder):
		_card_builder.free()
	_card_builder = null


func _validate_showcase() -> void:
	await get_tree().process_frame
	if _card == null or _tag_chips.size() != SHOWCASE_TAGS.size():
		push_error("WeaponCoreCardShowcase: missing core card or interactive Tags")
		await TEST_TEARDOWN.finish(self, 1, Callable(), [_card_builder])
		return
	for tag_variant in SHOWCASE_TAGS:
		var tag: StringName = tag_variant
		_focus_tag(tag)
		await get_tree().process_frame
		var heading := _card.find_child("WeaponCoreUsageHeading", true, false) as Label
		var tiles := _card.find_children("WeaponCoreWeaponTile*", "PanelContainer", true, false)
		var empty := _card.find_child("WeaponCoreUsageEmpty", true, false) as Label
		if heading == null or not heading.text.contains("→") or (tiles.is_empty() and (empty == null or not empty.visible)):
			push_error("WeaponCoreCardShowcase: Tag focus did not update supported weapons for %s" % tag)
			await TEST_TEARDOWN.finish(self, 1, Callable(), [_card_builder])
			return
	_restore_default_state()
	print("PASS: weapon core card showcase covers default and four Tag-focused states")
	await TEST_TEARDOWN.finish(self, 0, Callable(), [_card_builder])
