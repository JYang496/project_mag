extends Control

const REWARD_PANEL_SCRIPT := preload("res://UI/scripts/reward_selection_panel.gd")
const MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_crit_calibrator.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _card_builder: RewardSelectionPanel
var _showcase_weapons: Array[Weapon] = []
var _previous_weapon_list: Array = []


func _ready() -> void:
	call_deferred("_build_gallery")


func _build_gallery() -> void:
	_previous_weapon_list = PlayerData.player_weapon_list.duplicate()
	var prepare_result := DataHandler.prepare_world_data(true)
	if not bool(prepare_result.get("ok", false)):
		push_error("RewardCardGallery: failed to prepare world data: %s" % str(prepare_result.get("errors", [])))
		return
	CellEffectRuntime.prepare_definitions(true)
	CellTaskModuleRuntime.prepare_definitions(true)
	_create_showcase_weapons(["1", "2", "3", "4"])
	await get_tree().process_frame
	_card_builder = REWARD_PANEL_SCRIPT.new()
	var grid := %CardGrid as GridContainer
	var entries: Array[Dictionary] = [
		{"label": "WEAPON · BUILD PREVIEW", "reward": _make_weapon_reward("2", 1, "rare")},
		{"label": "WEAPON · DETAILS OPEN", "reward": _make_weapon_reward("5", 1, "rare"), "details_open": true},
		{"label": "WEAPON UPGRADE", "reward": _make_upgrade_reward("1", 1, 2)},
		{"label": "WEAPON MODULE", "reward": _make_module_reward()},
		{"label": "CELL EFFECT", "reward": _make_cell_effect_reward()},
		{"label": "TASK MODULE", "reward": _make_task_module_reward()},
		{"label": "ECONOMY", "reward": _make_economy_reward()},
	]
	var preview_count := 0
	var open_detail_count := 0
	for index in range(entries.size()):
		var entry := entries[index]
		var gallery_entry := _make_gallery_entry(
			str(entry.label),
			entry.reward as RewardInfo,
			index,
			bool(entry.get("details_open", false))
		)
		grid.add_child(gallery_entry)
		if gallery_entry.find_child("WeaponBuildPreview", true, false) != null:
			preview_count += 1
		var detail_overlay := gallery_entry.find_child("WeaponBranchDetailOverlay", true, false) as Control
		if detail_overlay != null and detail_overlay.visible:
			open_detail_count += 1
	print("REWARD_CARD_GALLERY_READY cards=%d weapons=%d" % [grid.get_child_count(), _showcase_weapons.size()])
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		if preview_count < 2 or open_detail_count != 1:
			push_error("RewardCardGallery: missing weapon build preview states")
			await TEST_TEARDOWN.finish(self, 1, _reset_runtime_state, [_card_builder])
			return
		print("PASS: reward card gallery builds all primary card types")
		await TEST_TEARDOWN.finish(self, 0, _reset_runtime_state, [_card_builder])


func _make_gallery_entry(label_text: String, reward: RewardInfo, index: int, details_open: bool = false) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.custom_minimum_size = Vector2(370.0, 470.0)
	entry.add_theme_constant_override("separation", 7)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.58, 0.82, 0.94, 1.0))
	entry.add_child(label)
	var card := _card_builder.call("_build_reward_card_button", reward, index % 3) as Button
	card.custom_minimum_size = Vector2(370.0, 520.0)
	entry.add_child(card)
	if details_open:
		var overlay := card.find_child("WeaponBranchDetailOverlay", true, false) as Control
		var content := card.find_child("CardContentMargin", true, false) as Control
		if overlay != null:
			overlay.visible = true
		if content != null:
			content.modulate.a = 0.25
	return entry


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


func _make_weapon_reward(weapon_id: String, level: int, rarity: String) -> RewardInfo:
	var reward := RewardInfo.new()
	reward.item_id = weapon_id
	reward.item_level = level
	reward.rarity = rarity
	return reward


func _make_upgrade_reward(weapon_id: String, from_level: int, to_level: int) -> RewardInfo:
	var reward := RewardInfo.new()
	reward.reward_kind = RewardInfo.KIND_WEAPON_UPGRADE
	reward.target_weapon_id = weapon_id
	reward.target_weapon_name = LocalizationManager.get_weapon_name_by_id(weapon_id, weapon_id)
	reward.target_weapon_from_level = from_level
	reward.target_weapon_to_level = to_level
	reward.rarity = "rare"
	return reward


func _make_module_reward() -> RewardInfo:
	var reward := RewardInfo.new()
	reward.module_scene = MODULE_SCENE
	reward.module_level = 1
	reward.rarity = "rare"
	return reward


func _make_cell_effect_reward() -> RewardInfo:
	var reward := RewardInfo.new()
	reward.reward_kind = RewardInfo.KIND_CELL_EFFECT
	reward.cell_effect_id = "speed_1"
	reward.rarity = "common"
	return reward


func _make_task_module_reward() -> RewardInfo:
	var reward := RewardInfo.new()
	reward.reward_kind = RewardInfo.KIND_TASK_MODULE
	reward.task_module_id = "task_kill_common"
	reward.rarity = "common"
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
	_showcase_weapons.clear()
	_card_builder = null
