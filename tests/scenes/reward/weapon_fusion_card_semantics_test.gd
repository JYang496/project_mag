extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false

class CorePredictionStub:
	extends Node
	func predict_weapon_obtain(weapon_id: String) -> Dictionary:
		if weapon_id == "1":
			return {
				"result": "dismantled_to_core",
				"weapon_id": "1",
				"core_amount": 1,
				"core_tags": [&"physical", &"projectile", &"heat", &"ammo"],
				"current_core_count": 2,
				"resulting_core_count": 3,
				"usable_branches": [{"weapon_id": "1", "branch_id": "gatling_mg"}],
			}
		return {"result": "not_applicable", "weapon_id": weapon_id}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	LocalizationManager.set_locale("en", false)
	var previous_player = PlayerData.player
	var stub := CorePredictionStub.new()
	get_tree().root.add_child(stub)
	PlayerData.player = stub

	var panel := RewardSelectionPanel.new()
	var saved_core_stacks := InventoryData.get_weapon_core_stacks().duplicate(true)
	InventoryData.restore_weapon_core_inventory([
		{"tags": [&"energy", &"summon"], "count": 1},
	])
	var one_dual_core_matches: Array[StringName] = RewardWeaponPreviewData._matched_fusion_tags([&"energy", &"summon"])
	if one_dual_core_matches.size() != 1:
		_fail("one dual-Tag core must satisfy only one branch recipe condition")
	InventoryData.restore_weapon_core_inventory([
		{"tags": [&"energy", &"summon"], "count": 1},
		{"tags": [&"energy"], "count": 1},
	])
	var two_distinct_core_matches: Array[StringName] = RewardWeaponPreviewData._matched_fusion_tags([&"energy", &"summon"])
	if two_distinct_core_matches.size() != 2:
		_fail("two distinct cores must be reassigned to satisfy both branch recipe conditions")
	InventoryData.restore_weapon_core_inventory(saved_core_stacks)
	var core_reward := RewardInfo.new()
	core_reward.item_id = "1"
	core_reward.item_level = 1
	var core_data: Dictionary = panel.call("_build_reward_display_data", core_reward)
	_assert_eq(StringName(core_data.get("reward_type", &"generic")), &"weapon_core", "duplicate weapon semantic type")
	_assert_eq(str(core_data.get("type_label", "")), "Weapon Core", "duplicate weapon card type")
	_assert_eq(str(core_data.get("source_weapon_name", "")), "Machine Gun", "duplicate core source weapon")
	_assert_eq(int(core_data.get("core_amount", 0)), 1, "duplicate core amount")
	_assert_eq(int(core_data.get("current_core_count", -1)), 2, "duplicate current core count")
	_assert_eq(int(core_data.get("resulting_core_count", -1)), 3, "duplicate resulting core count")
	_assert_eq((core_data.get("core_tags", []) as Array).size(), 4, "duplicate raw core tags")
	_assert_eq((core_data.get("usable_branches", []) as Array).size(), 1, "duplicate raw usable branches")
	for cleared_field in ["summary_text", "role_summary"]:
		if str(core_data.get(cleared_field, "")).strip_edges() != "":
			_fail("duplicate core card must clear weapon field: %s" % cleared_field)
	for cleared_lines_field in ["feature_lines", "core_stat_lines", "comparison_lines"]:
		if core_data.get(cleared_lines_field, []).size() != 0:
			_fail("duplicate core card must clear weapon lines: %s" % cleared_lines_field)
	_assert_contains(str(core_data.get("meta_text", "")), "2 -> 3", "duplicate core inventory meta")
	_assert_contains(str(core_data.get("outcome_text", "")), "dismantled into 1 core", "duplicate weapon outcome")
	_assert_contains(str(core_data.get("detail_preview", "")), "Physical", "duplicate core full localized tags")
	_assert_contains(str(core_data.get("detail_effect", "")), "Gatling", "core branch usage comes from recipe query")
	_assert_contains(str(core_data.get("detail_text", "")), "retained", "core Tag source explanation moves to the detail view")
	if (core_data.get("chips", []) as Array).size() != 4:
		_fail("duplicate core card must retain every inherent Tag")
	var core_model: RewardCardModel = panel.call("_build_reward_card_model", core_reward)
	if (core_model.to_display_data().get("chips", []) as Array).size() != 4:
		_fail("duplicate core card rendering must not truncate full Tag sets")
	var rendered_core_card := panel.call("_build_reward_card_button", core_reward, 0) as Button
	_assert_eq(bool(rendered_core_card.get_meta(&"is_weapon_reward", true)), false, "core is not a weapon visual reward")
	_assert_eq(bool(rendered_core_card.get_meta(&"is_weapon_core_reward", false)), true, "core has its own visual semantic")
	var core_content := rendered_core_card.find_child("WeaponCoreContent", true, false) as VBoxContainer
	var core_title := rendered_core_card.find_child("WeaponCoreTitle", true, false) as Label
	var core_icon := rendered_core_card.find_child("WeaponCoreIconStage", true, false) as CenterContainer
	var core_material_icon := rendered_core_card.find_child("WeaponCoreMaterialIcon", true, false) as Control
	var core_material_mark := rendered_core_card.find_child("WeaponCoreMark", true, false) as Label
	var core_source_image := rendered_core_card.find_child("WeaponCoreSourceImage", true, false) as TextureRect
	var core_source := rendered_core_card.find_child("WeaponCoreSource", true, false) as Label
	var core_gain := rendered_core_card.find_child("WeaponCoreGain", true, false) as Label
	var core_inventory := rendered_core_card.find_child("WeaponCoreInventory", true, false) as Label
	var core_inventory_status := rendered_core_card.find_child("WeaponCoreInventoryStatus", true, false) as PanelContainer
	var core_acquisition := rendered_core_card.find_child("WeaponCoreAcquisitionSection", true, false) as VBoxContainer
	var core_inheritance := rendered_core_card.find_child("WeaponCoreInheritanceSection", true, false) as VBoxContainer
	var core_usage_panel := rendered_core_card.find_child("WeaponCoreUsagePanel", true, false) as PanelContainer
	var core_usage_icon := rendered_core_card.find_child("WeaponCoreUsageIcon", true, false) as Label
	var core_usage := rendered_core_card.find_child("WeaponCoreUsageSection", true, false) as VBoxContainer
	if rendered_core_card.get_combined_minimum_size().y > 410.0:
		_fail("duplicate core card must fit the fixed reward viewport without vertical scrolling")
	if core_content == null or core_title == null or core_icon == null or core_material_icon == null or core_material_mark == null or core_source_image == null or core_source == null or core_gain == null or core_inventory == null or core_inventory_status == null or core_acquisition == null or core_inheritance == null or core_usage_panel == null or core_usage_icon == null or core_usage == null:
		_fail("duplicate core card must render its dedicated material-content hierarchy")
	elif core_title.text != "Machine Gun Core" or not core_source.text.contains("Machine Gun"):
		_fail("duplicate core card must use the source weapon as its primary identity")
	elif core_material_mark.text != "◆" or core_material_icon.custom_minimum_size.x < 100.0:
		_fail("duplicate core card must prioritize the enlarged source weapon over a generic letter mark")
	elif not core_gain.text.contains("+1") or not core_inventory.text.contains("2 → 3"):
		_fail("duplicate core card must show dismantle amount and inventory transition")
	elif int(core_inventory_status.get_meta(&"current_count", -1)) != 2 or int(core_inventory_status.get_meta(&"resulting_count", -1)) != 3:
		_fail("duplicate core inventory status must retain its before and after counts")
	elif core_inventory_status.custom_minimum_size.y < 28.0 or core_inventory_status.custom_minimum_size.y > 32.0:
		_fail("duplicate core inventory status must stay within the 28-32px target height")
	elif rendered_core_card.find_child("WeaponCoreInventoryProgress", true, false) != null:
		_fail("duplicate core card must not imply recipe progress with an inventory progress bar")
	elif core_content.size_flags_vertical != Control.SIZE_EXPAND_FILL or core_content.get_theme_constant("separation") != 8:
		_fail("duplicate core card must expand with eight pixels between its information blocks")
	elif core_content.get_child_count() != 3:
		_fail("duplicate core card must expose exactly acquisition, inheritance, and usage information blocks")
	elif core_usage_panel.size_flags_vertical != (Control.SIZE_EXPAND | Control.SIZE_SHRINK_END):
		_fail("duplicate core usage panel must absorb remaining height while shrinking to the bottom edge")
	elif core_usage_panel.get_index() != 2:
		_fail("duplicate core usage panel must remain the bottom-aligned information block")
	elif core_usage_icon.text.strip_edges() == "":
		_fail("duplicate core card must identify its fusion-usage section with an icon")
	elif core_title.get_index() >= core_icon.get_index() or core_icon.get_index() >= core_gain.get_index():
		_fail("duplicate core card must order source identity, source image, then immediate gain")
	var forbidden_core_nodes := [
		"WeaponDescriptionSlot", "WeaponRoleSummary", "CoreWeaponStats", "WeaponBuildPreview",
		"ModuleInstallationRequirements", "BranchPreviewRow", "WeaponLevelLabel",
	]
	for forbidden_name in forbidden_core_nodes:
		if rendered_core_card.find_child(forbidden_name, true, false) != null:
			_fail("duplicate core card must not render weapon node: %s" % forbidden_name)
	if not rendered_core_card.find_children("DamageType*", "Control", true, false).is_empty():
		_fail("duplicate core card must not render weapon damage-type icons")
	if rendered_core_card.find_child("RarityLabel", true, false) != null:
		_fail("duplicate core card must not render weapon rarity")
	for retained_behavior_node in ["HoldProgress", "KeyBadge", "SelectedBadge"]:
		if rendered_core_card.find_child(retained_behavior_node, true, false) == null:
			_fail("duplicate core card must retain reward-selection behavior node: %s" % retained_behavior_node)
	for readable_label in [core_source, core_gain, core_inventory]:
		if readable_label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			_fail("core material copy must wrap without truncation: %s" % readable_label.name)
	var rendered_core_tag_heading := rendered_core_card.find_child("CoreTagHeading", true, false) as Label
	if rendered_core_tag_heading == null or not rendered_core_tag_heading.text.contains("INHERITED TAGS"):
		_fail("duplicate core card must identify the chips as inherited core Tags")
	var rendered_core_tags := rendered_core_card.find_child("BuildChipRow", true, false) as GridContainer
	if rendered_core_tags == null or rendered_core_tags.columns != 2 or rendered_core_tags.get_child_count() != 4:
		_fail("duplicate core card must constrain every Tag to a two-column grid")
	elif rendered_core_tags.get_combined_minimum_size().x > 260.0:
		_fail("duplicate core Tag grid must remain inside a draft card column")
	var rendered_usage_lines := rendered_core_card.find_children("WeaponCoreUsageLine*", "Label", true, false)
	var rendered_usage_summary := rendered_core_card.find_child("WeaponCoreUsageSummary", true, false) as Label
	if rendered_usage_lines.size() != 1 or not (rendered_usage_lines[0] as Label).text.contains("Gatling"):
		_fail("duplicate core card must render matching fusion branches from usable_branches")
	elif (rendered_usage_lines[0] as Label).get_theme_font_size("font_size") != 13:
		_fail("duplicate core branch body text must use the readable 13px size")
	if rendered_usage_summary == null or not rendered_usage_summary.text.contains("1"):
		_fail("duplicate core card must summarize the total supported fusion branches before examples")
	for usage_count in range(4):
		_assert_core_usage_count(panel, usage_count)
	var assembler: Variant = panel.call("_get_reward_data_assembler")
	var filtered_usage_lines: PackedStringArray = assembler.call("_format_core_usage_lines", [
		{"weapon_id": "missing_weapon", "branch_id": "missing_branch"},
		{"weapon_id": "1", "branch_id": "missing_branch"},
		{"weapon_id": "1", "branch_id": "gatling_mg"},
	])
	if filtered_usage_lines.size() != 1 or not filtered_usage_lines[0].contains("Gatling"):
		_fail("invalid usable branch data must be skipped while valid recipes remain visible")
	rendered_core_card.free()
	_assert_model_layers(panel, core_reward, "core")
	if _failed:
		return

	var new_reward := RewardInfo.new()
	new_reward.item_id = "2"
	new_reward.item_level = 1
	var new_data: Dictionary = panel.call("_build_reward_display_data", new_reward)
	_assert_eq(StringName(new_data.get("reward_type", &"generic")), &"new_weapon", "new weapon semantic type")
	_assert_eq(str(new_data.get("type_label", "")), "Weapon", "weapon card type must not use a NEW prefix")
	_assert_contains(str(new_data.get("outcome_text", "")), "Obtain new weapon", "new weapon outcome")
	if panel.call("_get_reward_type_color", core_reward) == panel.call("_get_reward_type_color", new_reward):
		_fail("weapon core material color must remain distinct from new weapon rewards")
	if str(new_data.get("summary_text", "")).contains("Obtain"):
		_fail("new weapon behavior summary should omit the shared obtain operation")
	if (new_data.get("feature_lines", PackedStringArray()) as PackedStringArray).size() > 2:
		_fail("new weapon card should expose no more than two feature lines")
	if (panel.call("_card_comparison_lines", new_data) as PackedStringArray).size() < 2:
		_fail("new weapon card should fill its decision facts area")
	var rendered_new_card := panel.call("_build_reward_card_button", new_reward, 0) as Button
	if rendered_new_card.find_child("ModuleInstallationRequirements", true, false) != null:
		_fail("weapon cards should not repeat module installation requirements above branch preview")
	var branch_preview_section := rendered_new_card.find_child("WeaponBuildPreview", true, false) as VBoxContainer
	var branch_preview_row := rendered_new_card.find_child("BranchPreviewRow", true, false) as HBoxContainer
	var branch_preview_nodes := rendered_new_card.find_children("BranchPreviewNode", "PanelContainer", true, false)
	if branch_preview_section == null or branch_preview_section.size_flags_vertical != Control.SIZE_EXPAND_FILL:
		_fail("weapon branch preview section should absorb the card's remaining vertical space")
	if branch_preview_row == null or branch_preview_row.size_flags_vertical != Control.SIZE_EXPAND_FILL:
		_fail("weapon branch row should expand into the available preview space")
	for branch_preview_variant in branch_preview_nodes:
		var branch_preview_node := branch_preview_variant as PanelContainer
		var preview_title_row := branch_preview_node.find_child("BranchPreviewTitleRow", true, false) as HBoxContainer
		var preview_title_offset := branch_preview_node.find_child("BranchPreviewTitleOffset", true, false) as Control
		var preview_name := branch_preview_node.find_child("BranchPreviewName", true, false) as Label
		var preview_icons := branch_preview_node.find_child("BranchDamageTypeIcons", true, false) as HBoxContainer
		var preview_recipe := branch_preview_node.find_child("BranchPreviewFusionRecipe", true, false) as HBoxContainer
		var preview_state := branch_preview_node.find_child("BranchPreviewUnlockState", true, false) as Label
		var preview_accent := branch_preview_node.find_child("BranchAccentStrip", true, false) as HBoxContainer
		if branch_preview_node.size_flags_vertical != Control.SIZE_EXPAND_FILL:
			_fail("each branch preview card should fill the remaining row height")
		elif preview_title_offset == null or preview_title_offset.custom_minimum_size.y != 3.0:
			_fail("branch damage icon and name should be offset downward by three pixels")
		elif preview_title_row == null or preview_name == null or preview_name.text.strip_edges() == "":
			_fail("each branch preview should retain a visible name in a horizontal title row")
		elif preview_icons == null or preview_icons.get_parent() != preview_title_row or preview_name.get_parent() != preview_title_row:
			_fail("branch icons and name should be sibling controls that both participate in layout")
		elif preview_recipe == null or preview_state == null or preview_accent == null:
			_fail("branch preview should use top identity, middle fusion recipe, and bottom unlock state")
		elif preview_title_row.get_index() >= preview_recipe.get_index() or preview_recipe.get_index() >= preview_state.get_index():
			_fail("branch preview three-part hierarchy should remain in top, middle, bottom order")
		var preview_style := branch_preview_node.get_theme_stylebox("panel") as StyleBoxFlat
		if preview_style == null or preview_style.get_border_width(SIDE_LEFT) != 1:
			_fail("branch preview should use a neutral one-pixel secondary border")
	var branch_recipe := panel.call("_build_branch_fusion_recipe", {
		"unlock_fuse": 2,
		"fusion_required_tags": [&"physical", &"projectile"],
		"satisfied_fusion_tags": [&"physical"],
	}, [&"physical"]) as HBoxContainer
	var branch_recipe_prefix := branch_recipe.find_child("FusionRecipePrefix", true, false) as Label
	var branch_recipe_conditions := branch_recipe.find_child("FusionRecipeConditions", true, false) as VBoxContainer
	var physical_recipe_tag := branch_recipe.find_child("FusionRecipeTagPhysical", true, false) as Label
	var projectile_recipe_tag := branch_recipe.find_child("FusionRecipeTagProjectile", true, false) as Label
	if branch_recipe_prefix == null or branch_recipe_conditions == null:
		_fail("branch fusion count and condition list should use separate layout columns")
	elif branch_recipe_prefix.get_parent() != branch_recipe or branch_recipe_conditions.get_parent() != branch_recipe:
		_fail("branch fusion count and condition list should remain sibling columns")
	elif physical_recipe_tag == null or projectile_recipe_tag == null or physical_recipe_tag.text != "【Physical】" or projectile_recipe_tag.text != "【Projectile】":
		_fail("branch details should use the compact Fuse N: 【Tag】【Tag】 recipe")
	elif physical_recipe_tag.get_parent() != branch_recipe_conditions or projectile_recipe_tag.get_parent() != branch_recipe_conditions:
		_fail("branch fusion Tag conditions should align in their own vertical list")
	elif not bool(physical_recipe_tag.get_meta(&"satisfied", false)) or bool(projectile_recipe_tag.get_meta(&"satisfied", true)):
		_fail("branch recipe Tag color states should reflect distinct matching cores")
	branch_recipe.free()
	var weapon_hero := rendered_new_card.find_child("WeaponRewardHero", true, false) as CenterContainer
	var hero_image := rendered_new_card.find_child("WeaponHeroImage", true, false) as Control
	var hero_texture := rendered_new_card.find_child("RewardIconTexture", true, false) as TextureRect
	var new_weapon_name := rendered_new_card.find_child("WeaponRewardName", true, false) as Label
	var new_weapon_level := rendered_new_card.find_child("WeaponLevelLabel", true, false) as Label
	if weapon_hero == null or weapon_hero.custom_minimum_size.y < 80.0:
		_fail("new weapon card should reserve a centered hero image stage")
	if hero_image == null or hero_image.custom_minimum_size.x < 130.0 or hero_image.custom_minimum_size.y < 74.0:
		_fail("new weapon card hero image should be materially larger than the legacy 56px icon")
	if new_weapon_name == null or new_weapon_name.text.strip_edges() == "":
		_fail("new weapon card should show its weapon name below the hero image")
	elif new_weapon_name.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or new_weapon_name.autowrap_mode != TextServer.AUTOWRAP_OFF:
		_fail("weapon names should use the centered single-line slot below the hero image")
	elif new_weapon_level == null or new_weapon_name.get_parent() != new_weapon_level.get_parent() or new_weapon_name.get_index() >= new_weapon_level.get_index():
		_fail("weapon names should remain between the hero image and level text")
	if hero_texture == null or hero_texture.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		_fail("weapon hero should preserve nearest-neighbor pixel presentation")
	panel.call("_apply_reward_card_style", rendered_new_card, new_reward, false)
	var unselected_style := rendered_new_card.get_theme_stylebox("normal") as StyleBoxFlat
	if unselected_style == null or unselected_style.get_border_width(SIDE_LEFT) != 1 or unselected_style.border_color.a > 0.65:
		_fail("unselected rewards should use a low-opacity one-pixel blue-gray border")
	panel.call("_apply_reward_card_style", rendered_new_card, new_reward, true)
	var selected_style := rendered_new_card.get_theme_stylebox("normal") as StyleBoxFlat
	var selected_bar := rendered_new_card.find_child("SelectionIndicatorBar", true, false) as ColorRect
	if selected_style == null or selected_style.get_border_width(SIDE_LEFT) != 2 or selected_bar == null or not selected_bar.visible:
		_fail("selected rewards should use a two-pixel cyan border and visible top accent bar")
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
	elif behavior_summary.get_theme_font_size("font_size") != 14 or behavior_summary.get_theme_constant("line_spacing") != -2:
		_fail("reward card copy should use the shared compact label token")
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
	_assert_eq(StringName(upgrade_data.get("reward_type", &"generic")), &"weapon_upgrade", "weapon upgrade semantic type")
	_assert_eq(str(upgrade_data.get("type_label", "")), "Weapon Upgrade", "upgrade card type")
	_assert_contains(str(upgrade_data.get("outcome_text", "")), "Upgrade equipped weapon", "upgrade outcome")
	var upgrade_summary := str(upgrade_data.get("summary_text", "")).strip_edges()
	if upgrade_summary == "" or upgrade_summary == "Lv." or upgrade_summary.begins_with("Lv."):
		_fail("weapon upgrade summary should use weapon behavior copy instead of the level range")
	var rendered_upgrade_card := panel.call("_build_reward_card_button", upgrade_reward, 1) as Button
	var upgrade_weapon_name := rendered_upgrade_card.find_child("WeaponRewardName", true, false) as Label
	var rendered_upgrade_lines := rendered_upgrade_card.find_children("CoreStat*", "VBoxContainer", true, false)
	var expected_upgrade_lines := upgrade_data.get("core_stat_lines", PackedStringArray()) as PackedStringArray
	if rendered_upgrade_lines.size() != 3 or expected_upgrade_lines.size() != 3:
		_fail("weapon upgrade card should retain three fixed core-stat slots")
	if upgrade_weapon_name == null or upgrade_weapon_name.text != "Machine Gun":
		_fail("weapon upgrade card should show the target weapon name below the hero image")
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
	module_reward.module_scene = load("res://Player/Weapons/Modules/wmod_chill_chain_freeze.tscn") as PackedScene
	module_reward.module_level = 1
	_assert_explicit_module_trait_requirements()
	_assert_module_build_tag_derivation(module_reward.module_scene)
	var module_data: Dictionary = panel.call("_build_reward_display_data", module_reward)
	_assert_eq(StringName(module_data.get("reward_type", &"generic")), &"module", "module semantic type")
	_assert_contains(str(module_data.get("type_label", "")), "Module", "module card type")
	if str(module_data.get("summary_text", "")).strip_edges() == "":
		_fail("module card should describe the module's actual effect")
	if not module_data.has("compatible_weapons"):
		_fail("module card should expose owned weapon fit states")
	var module_chips := module_data.get("chips", []) as Array
	var chip_sources := PackedStringArray()
	for chip_variant in module_chips:
		var chip := chip_variant as Dictionary
		chip_sources.append(str(chip.get("source_key", "")))
		if str(chip.get("status", "")).begins_with("fit"):
			_fail("module tags should not include current-weapon fit badges")
	for expected_source in ["freeze", "on_hit", "on_move", "debuff"]:
		if not chip_sources.has(expected_source):
			_fail("module card should retain all module tags and hooks: %s" % expected_source)
	if chip_sources.has("trigger"):
		_fail("a concrete On Hit tag should replace the legacy generic Trigger tag")
	var rendered_module_card := panel.call("_build_reward_card_button", module_reward, 0) as Button
	if rendered_module_card.find_child("ModuleEffectBox", true, false) == null:
		_fail("module card should render a dedicated effect description section")
	if rendered_module_card.find_child("CompatibleWeaponsSection", true, false) == null:
		_fail("module card should render weapon fit information")
	var rendered_chip_row := rendered_module_card.find_child("BuildChipRow", true, false) as HFlowContainer
	if rendered_chip_row == null or rendered_chip_row.get_child_count() != module_chips.size():
		_fail("module card should render every module tag in a wrapping row (rendered=%d, model=%d)" % [
			-1 if rendered_chip_row == null else rendered_chip_row.get_child_count(),
			module_chips.size(),
		])
	rendered_module_card.free()
	var four_weapon_previews: Array = []
	for index in range(4):
		four_weapon_previews.append({
			"name": "Weapon %d" % (index + 1),
			"icon_texture": null,
			"used_slots": index % 2,
			"max_slots": 1,
			"compatible": index < 2,
			"has_slot": index % 2 == 0,
			"fit_reason": "Satisfies trait: Freeze" if index < 2 else "",
			"reason": "Requires one of: freeze" if index >= 2 else "",
		})
	var four_weapon_section := panel.call("_build_module_weapon_grid", {
		"compatible_weapons": four_weapon_previews,
		"owned_weapon_count": 4,
	}) as VBoxContainer
	var weapon_grid := four_weapon_section.find_child("CompatibleWeaponsGrid", true, false) as GridContainer
	if weapon_grid == null or weapon_grid.columns != 2 or weapon_grid.get_child_count() != 4:
		_fail("all four owned weapons should render in a fixed 2x2 fit grid")
	else:
		var status_lines := PackedStringArray()
		for tile in weapon_grid.get_children():
			if tile.find_child("WeaponIcon", true, false) == null or tile.find_child("WeaponFitStatus", true, false) == null:
				_fail("each weapon fit tile should include image and status text")
			else:
				status_lines.append((tile.find_child("WeaponFitStatus", true, false) as Label).text)
		if not status_lines[0].contains("Can equip now") or not status_lines[1].contains("Module slots full"):
			_fail("compatible weapons should distinguish open and full module slots")
		if not status_lines[2].contains("Requires one of") or not status_lines[3].contains("Requires one of"):
			_fail("incompatible weapons should show their incompatibility reason")
	four_weapon_section.free()
	_assert_model_layers(panel, module_reward, "module")

	var economy_reward := RewardInfo.new()
	economy_reward.reward_kind = RewardInfo.KIND_ECONOMY
	economy_reward.gold_value = 120
	economy_reward.total_chip_value = 40
	var economy_data: Dictionary = panel.call("_build_reward_display_data", economy_reward)
	_assert_eq(StringName(economy_data.get("reward_type", &"generic")), &"generic", "generic reward semantic type")
	_assert_contains(str(economy_data.get("type_label", "")), "Economy", "economy card type")
	_assert_model_layers(panel, economy_reward, "economy")

	LocalizationManager.set_locale("zh_CN", false)
	_assert_eq(LocalizationManager.tr_key("ui.reward.detail.section.result_preview", ""), "结果预览", "localized result preview heading")
	_assert_eq(LocalizationManager.tr_key("ui.reward.module_effect", ""), "模组效果", "localized module effect heading")
	_assert_eq(LocalizationManager.tr_key("ui.reward.compatible_weapons", ""), "可装备武器", "localized compatible weapons heading")
	_assert_eq(LocalizationManager.tr_format("ui.reward.weapon_fit_reason", {"requirements": "投射物"}, ""), "满足特性：投射物", "localized satisfied trait status")
	_assert_eq(LocalizationManager.tr_format("ui.reward.weapon_fit_with_slot", {"requirements": "满足特性：投射物"}, ""), "满足特性：投射物，有空槽", "localized satisfied trait and slot status")
	_assert_eq(LocalizationManager.tr_format("ui.reward.weapon_requires_trait", {"requirements": "投射物"}, ""), "需要特性：投射物", "localized required trait status")
	_assert_eq(LocalizationManager.tr_key("ui.reward.core.inherited_tags", ""), "继承标签", "localized core Tag source heading")
	_assert_contains(LocalizationManager.tr_key("ui.reward.core.tag_source_hint", ""), "来自该武器", "localized core Tag source explanation")
	_assert_contains(LocalizationManager.tr_key("ui.reward.core.tag_source_hint", ""), "融合配方", "localized core Tag purpose explanation")
	_assert_eq(LocalizationManager.tr_key("ui.reward.type.weapon_core", ""), "武器核心", "localized core title")
	_assert_eq(LocalizationManager.tr_format("ui.reward.core.named_title", {"name": "机枪"}, ""), "机枪核心", "localized source-named core title")
	_assert_eq(LocalizationManager.tr_format("ui.reward.core.gain", {"amount": 2}, ""), "+2 核心", "localized immediate core gain")
	_assert_eq(LocalizationManager.tr_format("ui.reward.core.usage_summary", {"count": 14}, ""), "可支持 14 条融合分支", "localized fusion branch summary")
	_assert_eq(LocalizationManager.tr_format("ui.reward.core.source", {"name": "机枪"}, ""), "来源：机枪", "localized core source")
	_assert_eq(LocalizationManager.tr_format("ui.reward.core.dismantled_amount", {"amount": 2}, ""), "重复武器已分解为 2 个核心。", "localized core amount")
	_assert_eq(LocalizationManager.tr_format("ui.reward.core.inventory", {"current": 8, "resulting": 10}, ""), "库存：8 → 10", "localized core inventory")
	_assert_eq(LocalizationManager.tr_format("ui.reward.core.more_usages", {"count": 1}, ""), "另有 1 项", "localized additional usage count")
	_assert_eq(LocalizationManager.tr_key("ui.reward.core.no_usable_branches", ""), "暂未发现可用融合配方", "localized empty fusion usage")
	var localized_branch_recipe := panel.call("_build_branch_fusion_recipe", {
		"unlock_fuse": 2,
		"fusion_required_tags": [&"physical", &"projectile"],
		"satisfied_fusion_tags": [&"physical"],
	}, [&"physical"]) as HBoxContainer
	var localized_recipe_labels := localized_branch_recipe.find_children("FusionRecipeTag*", "Label", true, false)
	if localized_recipe_labels.size() != 2 or (localized_recipe_labels[0] as Label).text != "【物理】" or (localized_recipe_labels[1] as Label).text != "【投射物】":
		_fail("Chinese branch details should use the compact 融合 N：【Tag】【Tag】 recipe")
	localized_branch_recipe.free()
	var localized_core_card := panel.call("_build_reward_card_button", core_reward, 0) as Button
	if (localized_core_card.find_child("WeaponCoreTitle", true, false) as Label).text != "机枪核心":
		_fail("Chinese core card must use the source-named material title")
	if not (localized_core_card.find_child("WeaponCoreSource", true, false) as Label).text.begins_with("来源："):
		_fail("Chinese core card must localize the source label")
	localized_core_card.free()
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
	if full_panel.title_label.get_theme_font_size("font_size") < 27:
		_fail("reward selection title should use the enlarged hierarchy")
	var options_scroll := full_panel.get_node("Panel/VBox/OptionsScroll") as ScrollContainer
	if options_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_fail("reward cards should not show a right-side vertical scrollbar")
	if full_panel.get_node_or_null("Panel/VBox/SelectedDetail") != null:
		_fail("reward panel should not repeat card descriptions below the cards")
	var action_panel := full_panel.get_node_or_null("Panel/VBox/ActionPanel") as PanelContainer
	if action_panel == null or action_panel.get_index() != 3:
		_fail("confirmation actions should remain directly below the reward cards")
	full_panel.queue_free()
	LocalizationManager.set_locale("en", false)
	await get_tree().process_frame
	var previous_ui := GlobalVariables.ui
	var runtime_ui := preload("res://UI/scenes/UI.tscn").instantiate() as UI
	get_tree().root.add_child(runtime_ui)
	await get_tree().process_frame
	runtime_ui.battle_hud.visible = true
	var runtime_phase_dock := runtime_ui.hud_phase_controller.phase_dock as Control
	if runtime_phase_dock != null:
		runtime_phase_dock.visible = true
	if not runtime_ui.request_reward_selection("", [new_reward], Callable(), Callable(), true):
		_fail("runtime reward panel should open for HUD and action-state validation")
	else:
		var runtime_panel := runtime_ui.reward_selection_panel
		if runtime_ui.battle_hud.visible:
			_fail("opening reward selection should temporarily hide the battle HUD")
		if runtime_phase_dock != null and runtime_phase_dock.visible:
			_fail("opening reward selection should hide the top-left phase status dock")
		if runtime_panel.confirm_button.disabled or runtime_panel.confirm_button.text != "Confirm Reward":
			_fail("a selected reward should expose an enabled, high-contrast confirmation action")
		runtime_panel.call("_open_weapon_detail", 0)
		if runtime_panel.confirm_button.disabled or runtime_panel.confirm_button.text != "Confirm Reward":
			_fail("an open detail should keep the selected reward confirmable")
		var close_details_font_size := -1
		var close_details_font_color := Color.TRANSPARENT
		var close_details_has_box := false
		for detail_child in runtime_panel.detail_hint.find_children("*", "Label", true, false):
			var detail_label := detail_child as Label
			if detail_label.text == "CLOSE DETAILS":
				close_details_font_size = detail_label.get_theme_font_size("font_size")
				close_details_font_color = detail_label.get_theme_color("font_color")
				close_details_has_box = detail_label.has_theme_stylebox_override("normal")
		runtime_panel.call("_close_weapon_detail")
		var view_details_label: Label = null
		for detail_child in runtime_panel.detail_hint.find_children("*", "Label", true, false):
			if (detail_child as Label).text == "VIEW DETAILS":
				view_details_label = detail_child as Label
		if view_details_label == null or runtime_panel.confirm_button.disabled:
			_fail("closed details should restore View Details and the enabled confirm action")
		elif close_details_font_size != view_details_label.get_theme_font_size("font_size") \
				or close_details_font_color != view_details_label.get_theme_color("font_color") \
				or close_details_has_box != view_details_label.has_theme_stylebox_override("normal"):
			_fail("View Details and Close Details should use the same text styling")
		var confirmed_rewards: Array = []
		runtime_panel.reward_confirmed.connect(func(reward: RewardInfo) -> void: confirmed_rewards.append(reward))
		runtime_panel.call("_open_weapon_detail", 0)
		runtime_panel.confirm_button.grab_focus()
		var confirm_event := InputEventKey.new()
		confirm_event.keycode = KEY_SPACE
		confirm_event.physical_keycode = KEY_SPACE
		confirm_event.pressed = true
		runtime_panel.call("_input", confirm_event)
		if runtime_panel.visible or confirmed_rewards.size() != 1 or confirmed_rewards[0] != new_reward:
			_fail("Space should confirm the selected reward while weapon details are open")
		if not runtime_ui.battle_hud.visible:
			_fail("closing reward selection should restore the battle HUD's previous visibility")
		if runtime_ui.hud_phase_controller._selection_modal_active:
			_fail("closing reward selection should release phase status dock suppression")
	runtime_ui.call("_init_battle_contract_selection_panel")
	runtime_phase_dock.visible = true
	runtime_ui.battle_contract_selection_panel.visible = true
	await get_tree().process_frame
	if runtime_phase_dock.visible or not runtime_ui.hud_phase_controller._selection_modal_active:
		_fail("protocol selection should share top-left phase status dock suppression")
	runtime_ui.battle_contract_selection_panel.visible = false
	await get_tree().process_frame
	if runtime_ui.hud_phase_controller._selection_modal_active:
		_fail("closing protocol selection should release phase status dock suppression")
	runtime_ui.queue_free()
	await get_tree().process_frame
	GlobalVariables.ui = previous_ui

	panel.free()
	PlayerData.player = previous_player
	stub.queue_free()
	print("PASS: reward weapon fusion card semantics")
	await TEST_TEARDOWN.finish(self, 0)

func _assert_explicit_module_trait_requirements() -> void:
	var machine_gun := (load("res://Player/Weapons/Instances/machine_gun.tscn") as PackedScene).instantiate() as Weapon
	var freeze_module := (load("res://Player/Weapons/Modules/wmod_ice_prison_freeze.tscn") as PackedScene).instantiate() as Module
	var fire_module := (load("res://Player/Weapons/Modules/wmod_ember_mark_fire.tscn") as PackedScene).instantiate() as Module
	_assert_eq(freeze_module.get_normalized_required_weapon_traits(), [WeaponTrait.FREEZE], "freeze module explicit requirements")
	_assert_eq(fire_module.get_normalized_required_weapon_traits(), [WeaponTrait.FIRE], "fire module explicit requirements")
	_assert_contains(freeze_module.get_incompatibility_reason(machine_gun), "freeze", "heat-only weapon rejected by freeze module")
	_assert_contains(fire_module.get_incompatibility_reason(machine_gun), "fire", "heat-only weapon rejected by fire module")
	machine_gun.add_runtime_weapon_trait(&"test_freeze", WeaponTrait.FREEZE)
	_assert_eq(freeze_module.get_incompatibility_reason(machine_gun), "", "runtime freeze trait accepted by freeze module")
	var runtime_traits := machine_gun.stat_pipeline.get_normalized_weapon_traits()
	if not runtime_traits.has(WeaponTrait.FREEZE) or not runtime_traits.has(WeaponTrait.HEAT):
		_fail("runtime freeze trait should retain its derived heat trait")
	machine_gun.free()
	freeze_module.free()
	fire_module.free()

func _assert_module_build_tag_derivation(module_scene: PackedScene) -> void:
	var module_instance := module_scene.instantiate() as Module
	var effect_tags := module_instance.get_effect_tags()
	var trigger_tags := module_instance.get_derived_trigger_tags()
	var build_tags := module_instance.get_build_tags()
	if effect_tags.has(&"trigger") or effect_tags.has(&"on_hit"):
		_fail("effect tags should filter trigger facts derived from runtime Hook data")
	for expected_effect in [&"freeze", &"debuff", &"movement"]:
		if not effect_tags.has(expected_effect):
			_fail("effect tags should preserve %s" % expected_effect)
	_assert_eq(trigger_tags, [&"on_hit"], "derived trigger tags")
	if not build_tags.has(&"on_hit") or build_tags.count(&"on_hit") != 1:
		_fail("build tags should contain one derived on_hit tag")
	if build_tags.has(&"trigger"):
		_fail("build tags should omit legacy Trigger when a concrete trigger exists")
	_assert_eq(
		ModuleHook.display_tags_for_events([&"hit_confirmed", &"target_killed"]),
		[&"on_hit", &"execute"],
		"central event display tag mapping"
	)
	_assert_eq(
		ModuleHook.display_tags_for_events([&"skill_cast_finished"]),
		[&"trigger"],
		"unmapped event display tag fallback"
	)
	module_instance.free()

func _assert_core_usage_count(panel: RewardSelectionPanel, usage_count: int) -> void:
	var lines := PackedStringArray()
	for index in range(usage_count):
		lines.append("Weapon %d · Branch %d" % [index + 1, index + 1])
	var section := panel.call("_build_weapon_core_usage_section", {"usable_branch_lines": lines}) as VBoxContainer
	var visible_lines := section.find_children("WeaponCoreUsageLine*", "Label", true, false)
	if visible_lines.size() != mini(2, usage_count):
		_fail("core usage count %d should render at most two branch rows (rendered=%d)" % [usage_count, visible_lines.size()])
	var more := section.find_child("WeaponCoreUsageMore", true, false) as Label
	var empty := section.find_child("WeaponCoreUsageEmpty", true, false) as Label
	if usage_count == 0 and empty == null:
		_fail("core usage count 0 should render the neutral empty state")
	elif usage_count > 0 and empty != null:
		_fail("non-empty core usage should not render the empty state")
	if usage_count == 3 and (more == null or not more.text.contains("1")):
		_fail("core usage count 3 should summarize one additional recipe")
	elif usage_count < 3 and more != null:
		_fail("core usage count %d should not render an additional-count row" % usage_count)
	section.free()

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
