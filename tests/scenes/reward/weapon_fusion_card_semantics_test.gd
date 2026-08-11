extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false

class FusionPredictionStub:
	extends Node
	func predict_auto_fuse_weapon_obtain(weapon_id: String) -> Dictionary:
		if weapon_id == "1":
			return {
				"result": "fused",
				"weapon_id": "1",
				"from_fuse": 1,
				"target_fuse": 2,
				"has_branch_options": false,
			}
		return {"result": "not_applicable", "weapon_id": weapon_id}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	LocalizationManager.set_locale("en", false)
	var previous_player = PlayerData.player
	var stub := FusionPredictionStub.new()
	get_tree().root.add_child(stub)
	PlayerData.player = stub

	var panel := RewardSelectionPanel.new()
	var fusion_reward := RewardInfo.new()
	fusion_reward.item_id = "1"
	fusion_reward.item_level = 1
	var fusion_data: Dictionary = panel.call("_build_reward_display_data", fusion_reward)
	_assert_eq(str(fusion_data.get("type_label", "")), "Weapon Fusion", "duplicate weapon card type")
	_assert_contains(str(fusion_data.get("meta_text", "")), "Fuse 1 -> 2", "duplicate weapon meta")
	_assert_contains(str(fusion_data.get("outcome_text", "")), "Fuse equipped", "duplicate weapon outcome")
	_assert_model_layers(panel, fusion_reward, "fusion")
	if _failed:
		return

	var new_reward := RewardInfo.new()
	new_reward.item_id = "2"
	new_reward.item_level = 1
	var new_data: Dictionary = panel.call("_build_reward_display_data", new_reward)
	_assert_eq(str(new_data.get("type_label", "")), "New Weapon", "new weapon card type")
	_assert_contains(str(new_data.get("outcome_text", "")), "Obtain new weapon", "new weapon outcome")
	if str(new_data.get("summary_text", "")).contains("Obtain"):
		_fail("new weapon behavior summary should omit the shared obtain operation")
	if (new_data.get("feature_lines", PackedStringArray()) as PackedStringArray).size() > 2:
		_fail("new weapon card should expose no more than two feature lines")
	if (panel.call("_card_comparison_lines", new_data) as PackedStringArray).size() < 2:
		_fail("new weapon card should fill its decision facts area")
	var rendered_new_card := panel.call("_build_reward_card_button", new_reward, 0) as Button
	var weapon_hero := rendered_new_card.find_child("WeaponRewardHero", true, false) as CenterContainer
	var hero_image := rendered_new_card.find_child("WeaponHeroImage", true, false) as Control
	var hero_texture := rendered_new_card.find_child("RewardIconTexture", true, false) as TextureRect
	if weapon_hero == null or weapon_hero.custom_minimum_size.y < 80.0:
		_fail("new weapon card should reserve a centered hero image stage")
	if hero_image == null or hero_image.custom_minimum_size.x < 130.0 or hero_image.custom_minimum_size.y < 74.0:
		_fail("new weapon card hero image should be materially larger than the legacy 56px icon")
	if hero_texture == null or hero_texture.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		_fail("weapon hero should preserve nearest-neighbor pixel presentation")
	var behavior_summary := rendered_new_card.find_child("BehaviorSummary", true, false) as Label
	var hold_progress_nodes := rendered_new_card.find_children("HoldProgress", "ProgressBar", true, false)
	var feature_list := rendered_new_card.find_child("FeatureList", true, false) as VBoxContainer
	var description_slot := rendered_new_card.find_child("WeaponDescriptionSlot", true, false) as VBoxContainer
	var core_stats := rendered_new_card.find_child("CoreWeaponStats", true, false) as HBoxContainer
	if hold_progress_nodes.size() != 1 or hold_progress_nodes[0].get_index() != 0:
		_fail("the single hold-progress track should occupy the card's top status-line slot")
	elif behavior_summary == null or feature_list == null:
		_fail("new weapon card should render separate behavior and feature layers")
	elif description_slot == null or description_slot.custom_minimum_size.y != 96.0:
		_fail("weapon description should occupy its fixed non-scrolling slot")
	elif core_stats == null or core_stats.get_child_count() != 3:
		_fail("weapon cards should render exactly three fixed core-stat slots")
	elif core_stats.get_child(0).name != "CoreStatDamage" or core_stats.get_child(1).name != "CoreStatFireInterval" or core_stats.get_child(2).name != "CoreStatAmmo":
		_fail("core-stat slots should keep damage, fire interval, and ammo order")
	elif behavior_summary.get_theme_font_size("font_size") != 15 or behavior_summary.get_theme_constant("line_spacing") != -2:
		_fail("reward card copy should use the enlarged compact text treatment")
	elif feature_list.get_theme_constant("separation") != 2:
		_fail("reward card feature rows should use compact vertical spacing")
	elif behavior_summary.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		_fail("behavior summary should wrap without trimming localized copy")
	elif rendered_new_card.custom_minimum_size.y > 410.0 or rendered_new_card.clip_contents:
		_fail("detailed reward cards should fit the draft viewport without clipping or scrolling")
	elif feature_list.get_child_count() < 1 or feature_list.get_child_count() > 2:
		_fail("new weapon card should render one or two feature rows")
	else:
		for feature_line in feature_list.get_children():
			var feature_label := feature_line as Label
			if feature_label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
				_fail("feature summaries should wrap without an ellipsis")
	rendered_new_card.free()
	_assert_model_layers(panel, new_reward, "new weapon")
	if _failed:
		return

	var upgrade_reward := RewardInfo.new()
	upgrade_reward.reward_kind = RewardInfo.KIND_WEAPON_UPGRADE
	upgrade_reward.target_weapon_name = "Machine Gun"
	upgrade_reward.target_weapon_id = "1"
	upgrade_reward.target_weapon_from_level = 1
	upgrade_reward.target_weapon_to_level = 2
	var upgrade_data: Dictionary = panel.call("_build_reward_display_data", upgrade_reward)
	_assert_eq(str(upgrade_data.get("type_label", "")), "Weapon Upgrade", "upgrade card type")
	_assert_contains(str(upgrade_data.get("outcome_text", "")), "Upgrade equipped weapon", "upgrade outcome")
	var upgrade_summary := str(upgrade_data.get("summary_text", "")).strip_edges()
	if upgrade_summary == "" or upgrade_summary == "Lv." or upgrade_summary.begins_with("Lv."):
		_fail("weapon upgrade summary should use weapon behavior copy instead of the level range")
	var rendered_upgrade_card := panel.call("_build_reward_card_button", upgrade_reward, 1) as Button
	var rendered_upgrade_lines := rendered_upgrade_card.find_children("CoreStat*", "VBoxContainer", true, false)
	var expected_upgrade_lines := upgrade_data.get("core_stat_lines", PackedStringArray()) as PackedStringArray
	if rendered_upgrade_lines.size() != 3 or expected_upgrade_lines.size() != 3:
		_fail("weapon upgrade card should retain three fixed core-stat slots")
	for line in rendered_upgrade_lines:
		var value_label := (line as VBoxContainer).get_node("Value") as Label
		var line_text := value_label.text
		if line_text.contains("Main Effect") or line_text.contains("Result Preview"):
			_fail("weapon upgrade card should not render generic main-effect or result-preview rows")
	if rendered_upgrade_card.find_child("ShortTagLabel", true, false) != null:
		_fail("weapon upgrade card should not repeat its level range at the bottom")
	rendered_upgrade_card.free()
	_assert_model_layers(panel, upgrade_reward, "weapon upgrade")
	if _failed:
		return

	var module_reward := RewardInfo.new()
	module_reward.module_scene = load("res://Player/Weapons/Modules/wmod_crit_calibrator.tscn") as PackedScene
	module_reward.module_level = 1
	var module_data: Dictionary = panel.call("_build_reward_display_data", module_reward)
	_assert_contains(str(module_data.get("type_label", "")), "Module", "module card type")
	if str(module_data.get("summary_text", "")).strip_edges() == "":
		_fail("module card should describe the module's actual effect")
	if not module_data.has("compatible_weapons"):
		_fail("module card should expose compatible owned weapons")
	var rendered_module_card := panel.call("_build_reward_card_button", module_reward, 0) as Button
	if rendered_module_card.find_child("ModuleEffectBox", true, false) == null:
		_fail("module card should render a dedicated effect description section")
	if rendered_module_card.find_child("CompatibleWeaponsSection", true, false) == null:
		_fail("module card should render compatible weapon information")
	rendered_module_card.free()
	var four_weapon_previews: Array = []
	for index in range(4):
		four_weapon_previews.append({
			"name": "Weapon %d" % (index + 1),
			"icon_texture": null,
			"used_slots": index % 2,
			"max_slots": 1,
			"requires_replace": index % 2 == 1,
		})
	var four_weapon_section := panel.call("_build_module_weapon_grid", {
		"compatible_weapons": four_weapon_previews,
		"owned_weapon_count": 4,
	}) as VBoxContainer
	var weapon_grid := four_weapon_section.find_child("CompatibleWeaponsGrid", true, false) as GridContainer
	if weapon_grid == null or weapon_grid.columns != 2 or weapon_grid.get_child_count() != 4:
		_fail("four compatible weapons should render in a fixed 2x2 grid")
	else:
		for tile in weapon_grid.get_children():
			if tile.find_child("WeaponIcon", true, false) == null or tile.find_child("WeaponFitStatus", true, false) == null:
				_fail("each compatible weapon tile should include image and status text")
	four_weapon_section.free()
	_assert_model_layers(panel, module_reward, "module")

	var economy_reward := RewardInfo.new()
	economy_reward.reward_kind = RewardInfo.KIND_ECONOMY
	economy_reward.gold_value = 120
	economy_reward.total_chip_value = 40
	var economy_data: Dictionary = panel.call("_build_reward_display_data", economy_reward)
	_assert_contains(str(economy_data.get("type_label", "")), "Economy", "economy card type")
	_assert_model_layers(panel, economy_reward, "economy")

	LocalizationManager.set_locale("zh_CN", false)
	_assert_eq(LocalizationManager.tr_key("ui.reward.detail.section.result_preview", ""), "结果预览", "localized result preview heading")
	_assert_eq(LocalizationManager.tr_key("ui.reward.module_effect", ""), "模组效果", "localized module effect heading")
	_assert_eq(LocalizationManager.tr_key("ui.reward.compatible_weapons", ""), "可装备武器", "localized compatible weapons heading")
	var localized_new_data: Dictionary = panel.call("_build_reward_display_data", new_reward)
	var localized_summary := str(localized_new_data.get("summary_text", ""))
	var localized_features := localized_new_data.get("feature_lines", PackedStringArray()) as PackedStringArray
	var localized_comparison := panel.call("_card_comparison_lines", localized_new_data) as PackedStringArray
	var localized_core_stats := localized_new_data.get("core_stat_lines", PackedStringArray()) as PackedStringArray
	if localized_summary.contains("；") or localized_summary.contains(";"):
		_fail("localized behavior summary should not keep semicolon-packed feature copy")
	if localized_features.is_empty() or localized_features.size() > 2:
		_fail("localized weapon copy should expose one or two separate feature lines")
	for comparison_line in localized_comparison:
		if str(comparison_line).contains("…"):
			_fail("localized comparison copy should not be shortened with an ellipsis")
	if localized_core_stats.size() != 3:
		_fail("localized weapon cards should retain all three fixed core-stat slots")
	else:
		_assert_contains(localized_core_stats[0], "伤害", "localized fixed damage slot")
		_assert_contains(localized_core_stats[1], "射击间隔", "localized fixed fire interval slot")
		_assert_contains(localized_core_stats[2], "弹匣容量", "localized fixed ammo slot")

	var full_panel := preload("res://UI/scenes/reward_selection_panel.tscn").instantiate() as RewardSelectionPanel
	get_tree().root.add_child(full_panel)
	full_panel.call("_apply_unified_layout")
	var options_scroll := full_panel.get_node("Panel/VBox/OptionsScroll") as ScrollContainer
	if options_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_fail("reward cards should not show a right-side vertical scrollbar")
	if full_panel.get_node_or_null("Panel/VBox/SelectedDetail") != null:
		_fail("reward panel should not reserve a full-details row below the cards")
	var action_panel := full_panel.get_node_or_null("Panel/VBox/ActionPanel") as PanelContainer
	if action_panel == null or action_panel.get_index() != 3:
		_fail("confirmation actions should remain directly below the reward cards")
	full_panel.queue_free()
	LocalizationManager.set_locale("en", false)

	panel.free()
	PlayerData.player = previous_player
	stub.queue_free()
	print("PASS: reward weapon fusion card semantics")
	await TEST_TEARDOWN.finish(self, 0)

func _assert_model_layers(panel: RewardSelectionPanel, reward: RewardInfo, label: String) -> void:
	var model: Variant = panel.call("_build_reward_card_model", reward)
	if str(model.behavior_summary).strip_edges() == "": _fail("%s missing primary behavior summary" % label)
	if model.primary_chips().size() > 3: _fail("%s exposes more than three primary tags" % label)
	if model.synergy_status == &"neutral" and str(model.synergy_label).strip_edges() != "": _fail("%s neutral reward should not show a standalone build label" % label)
	if str(model.full_detail).strip_edges() == "": _fail("%s missing full detail layer" % label)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _assert_contains(actual: String, expected: String, label: String) -> void:
	if actual.contains(expected):
		return
	_fail("%s expected to contain %s got %s" % [label, expected, actual])

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("FAIL: ", message)
	await TEST_TEARDOWN.finish(self, 1)
