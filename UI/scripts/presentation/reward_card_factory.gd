extends RefCounted
class_name RewardCardFactory

# Builds reward visuals; the panel owns selection and modal interaction.
const REWARD_ICON_SCENE := preload("res://UI/components/RewardIcon/RewardIcon.tscn")
const REWARD_CARD_SCENE := preload("res://UI/components/RewardCard/RewardCard.tscn")
const WEAPON_CORE_CONTENT_SCENE := preload("res://UI/components/WeaponCoreRewardContent/WeaponCoreRewardContent.tscn")
const CORE_WEAPON_STATS_SCENE := preload("res://UI/components/CoreWeaponStats/CoreWeaponStats.tscn")
const DAMAGE_TYPE_ICON_ROW_SCENE := preload("res://UI/components/DamageTypeIconRow/DamageTypeIconRow.tscn")
const BRANCH_FUSION_RECIPE_SCENE := preload("res://UI/components/BranchFusionRecipe/BranchFusionRecipe.tscn")
const WEAPON_BRANCH_PREVIEW_SECTION_SCENE := preload("res://UI/components/WeaponBranchPreviewSection/WeaponBranchPreviewSection.tscn")
const BRANCH_PREVIEW_CARD_SCENE := preload("res://UI/components/BranchPreviewCard/BranchPreviewCard.tscn")
const WEAPON_BRANCH_DETAIL_OVERLAY_SCENE := preload("res://UI/components/WeaponBranchDetailOverlay/WeaponBranchDetailOverlay.tscn")
const BRANCH_DETAIL_CARD_SCENE := preload("res://UI/components/BranchDetailCard/BranchDetailCard.tscn")
const MODULE_FIT_SECTION_SCENE := preload("res://UI/components/ModuleFitSection/ModuleFitSection.tscn")
const MODULE_FIT_WEAPON_TILE_SCENE := preload("res://UI/components/ModuleFitWeaponTile/ModuleFitWeaponTile.tscn")
const REWARD_CARD_LABEL_SCENE := preload("res://UI/components/RewardCardLabel/RewardCardLabel.tscn")
const MODULE_EFFECT_SUMMARY_SCENE := preload("res://UI/components/ModuleEffectSummary/ModuleEffectSummary.tscn")
const REWARD_TEXT_COLUMN_SCENE := preload("res://UI/components/RewardTextColumn/RewardTextColumn.tscn")
const REWARD_HEADER_SCENE := preload("res://UI/components/RewardHeader/RewardHeader.tscn")
const REWARD_CHIP_ROW_SCENE := preload("res://UI/components/RewardChipRow/RewardChipRow.tscn")
const WEAPON_DESCRIPTION_SECTION_SCENE := preload("res://UI/components/WeaponDescriptionSection/WeaponDescriptionSection.tscn")
const MODULE_EFFECT_SECTION_SCENE := preload("res://UI/components/ModuleEffectSection/ModuleEffectSection.tscn")
const REWARD_FEATURE_LIST_SCENE := preload("res://UI/components/RewardFeatureList/RewardFeatureList.tscn")
const REWARD_COMPARISON_BOX_SCENE := preload("res://UI/components/RewardComparisonBox/RewardComparisonBox.tscn")
const WEAPON_REWARD_HERO_SCENE := preload("res://UI/components/WeaponRewardHero/WeaponRewardHero.tscn")

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")
const WEAPON_STAT_FORMATTER := preload("res://UI/scripts/presentation/weapon_stat_formatter.gd")
const WEAPON_PREVIEW_DATA := preload("res://UI/scripts/presentation/reward_weapon_preview_data.gd")
const DAMAGE_TYPE_ICONS := {
	&"physical": preload("res://UI/themes/pixel/generated/damage_types/damage_physical_compact.png"),
	&"energy": preload("res://UI/themes/pixel/generated/damage_types/damage_energy.png"),
	&"fire": preload("res://UI/themes/pixel/generated/damage_types/damage_fire.png"),
	&"freeze": preload("res://UI/themes/pixel/generated/damage_types/damage_freeze.png"),
}
const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")
const CARD_FONT_SIZE_BONUS := 0
const STANDARD_CARD_MIN_HEIGHT := 372.0
const DETAILED_CARD_MIN_HEIGHT := 380.0

var _panel: Control
var _cropped_reward_textures: Dictionary = {}

func _init(panel: Control) -> void:
	_panel = panel

func build(reward: RewardInfo, reward_index: int, reusable: Button, card_data: Dictionary, _summary_mode: bool, type_color: Color) -> Button:
	var is_module_reward := card_data.has("compatible_weapons")
	var reward_type := StringName(card_data.get("reward_type", &"generic"))
	var detail_variant := StringName(card_data.get("detail_variant", reward_type))
	var is_weapon_core_reward := reward_type == &"weapon_core"
	var is_weapon_visual_reward := reward_type in [&"new_weapon", &"weapon_upgrade"]
	var weapon_preview: Dictionary = WEAPON_PREVIEW_DATA.build(reward) if is_weapon_visual_reward else {}
	var button := reusable if reusable != null else REWARD_CARD_SCENE.instantiate() as Button
	button.call("set_data", {
		"reward_index": reward_index,
		"reward_type": reward_type,
		"is_weapon_reward": is_weapon_visual_reward,
		"is_weapon_core_reward": is_weapon_core_reward,
		"minimum_height": 400.0 if is_weapon_visual_reward else (DETAILED_CARD_MIN_HEIGHT if is_module_reward or is_weapon_core_reward else STANDARD_CARD_MIN_HEIGHT),
		"key_text": str(reward_index + 1) if not _summary_mode and reward_index >= 0 and reward_index < 3 else "",
		"type_label": str(card_data.get("type_label", "Reward")).to_upper(),
		"selected_text": LocalizationManager.tr_key("ui.reward.selected", "SELECTED"),
		"type_color": type_color,
		"accent_color": TOKENS.COLOR_ACCENT_SYSTEM,
	})
	var full_detail := str(card_data.get("detail_text", "")).strip_edges()
	button.tooltip_text = ""
	var body := button.get_node("CardContentMargin/Body") as VBoxContainer
	if is_weapon_core_reward:
		var core_content := _build_weapon_core_content(card_data)
		body.add_child(core_content)
		_set_mouse_filter_recursive(button, Control.MOUSE_FILTER_IGNORE)
		_clear_tooltips_recursive(button)
		core_content.call("configure_tag_weapon_interactions", core_content.get_meta(&"core_chips", []), core_content.get_meta(&"tag_weapon_map", {}))
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		return button

	var text_box := REWARD_TEXT_COLUMN_SCENE.instantiate() as VBoxContainer
	if is_weapon_visual_reward:
		var weapon_hero := _build_weapon_reward_hero(card_data)
		body.add_child(weapon_hero)
		body.add_child(text_box)
	else:
		var header := REWARD_HEADER_SCENE.instantiate() as HBoxContainer
		body.add_child(header)
		header.call("set_content", _make_reward_icon(card_data, Vector2(72.0, 72.0), 7), text_box)

	var display_title := str(card_data.get("title", "Reward")).strip_edges()
	if is_weapon_visual_reward:
		display_title = _weapon_reward_display_name(reward, display_title)
	var name_label := _make_card_label(display_title, 19 if is_weapon_visual_reward else TOKENS.FONT_BUTTON, TOKENS.COLOR_TEXT_PRIMARY)
	var summary_count := int(reward.get_meta("summary_count", 1))
	if _summary_mode and summary_count > 1:
		name_label.text += " " + LocalizationManager.tr_format(
			"ui.reward.summary.count_suffix",
			{"count": summary_count},
			"x%d" % summary_count
		)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(0.0, 24.0 if is_weapon_visual_reward else 38.0)
	if is_weapon_visual_reward:
		name_label.name = "WeaponRewardName"
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_weapon_visual_reward:
		_attach_damage_icons_to_weapon_name(name_label, weapon_preview.get("damage_types", []))
	text_box.add_child(name_label)
	var chips: Array = card_data.get("chips", [])
	if is_module_reward and not chips.is_empty():
		var module_chip_row := REWARD_CHIP_ROW_SCENE.instantiate() as HFlowContainer
		BUILD_TAG_DISPLAY.populate_chip_row(module_chip_row, chips)
		text_box.add_child(module_chip_row)

	var meta_text := str(card_data.get("meta_text", "")).strip_edges()
	var level_text := str(card_data.get("level_text", "")).strip_edges()
	var meta_label := _make_card_label(level_text if level_text != "" else meta_text, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_SECONDARY)
	meta_label.clip_text = true
	if is_weapon_visual_reward:
		meta_label.name = "WeaponLevelLabel"
		meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_box.add_child(meta_label)
	var rarity_label := _make_rarity_label(str(card_data.get("rarity", reward.get_rarity())))
	if is_weapon_visual_reward:
		_attach_rarity_to_weapon_level(meta_label, rarity_label)
	else:
		text_box.add_child(rarity_label)

	var summary_parent: VBoxContainer = body
	if is_weapon_visual_reward:
		var description_box := WEAPON_DESCRIPTION_SECTION_SCENE.instantiate() as VBoxContainer
		body.add_child(description_box)
		summary_parent = description_box
	elif is_module_reward:
		var effect_box := MODULE_EFFECT_SECTION_SCENE.instantiate() as VBoxContainer
		body.add_child(effect_box)
		effect_box.call("set_heading", LocalizationManager.tr_key("ui.reward.module_effect", "Module Effect"))
		summary_parent = effect_box
	var role_summary := str(card_data.get("role_summary", "")).strip_edges()
	var behavior_summary := str(card_data.get("summary_text", "")).strip_edges()
	if is_weapon_visual_reward and role_summary != "" and role_summary != behavior_summary:
		var role_label := _make_card_label(role_summary, 15, TOKENS.COLOR_TEXT_PRIMARY)
		role_label.name = "WeaponRoleSummary"
		role_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		role_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		role_label.clip_text = true
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.tooltip_text = ""
		summary_parent.add_child(role_label)
	var summary_label := _make_card_label(behavior_summary, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_PRIMARY)
	summary_label.name = "BehaviorSummary"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.max_lines_visible = 2
	summary_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	summary_label.tooltip_text = ""
	if is_module_reward:
		# Keep the plain semantic node for callers that inspect card data, while the
		# visible rich-text version gives the module's thresholds and payoff priority.
		summary_label.visible = false
		summary_parent.add_child(summary_label)
		summary_parent.add_child(_make_highlighted_module_summary(behavior_summary))
	else:
		summary_parent.add_child(summary_label)

	var feature_lines: PackedStringArray = card_data.get("feature_lines", PackedStringArray())
	if not feature_lines.is_empty():
		var feature_box := REWARD_FEATURE_LIST_SCENE.instantiate() as VBoxContainer
		summary_parent.add_child(feature_box)
		for feature in feature_lines.slice(0, 2):
			var feature_label := _make_card_label("• %s" % str(feature).strip_edges(), 13, Color(0.70, 0.80, 0.84, 1.0))
			feature_label.name = "FeatureLine"
			_configure_wrapped_card_text(feature_label)
			feature_label.tooltip_text = ""
			feature_box.add_child(feature_label)

	if is_module_reward:
		body.add_child(_build_module_weapon_grid(card_data))
	elif is_weapon_visual_reward:
		body.add_child(_build_core_weapon_stats(card_data))
		body.add_child(_build_weapon_preview_section(weapon_preview, reward_index))
	else:
		var comparison_lines := _card_comparison_lines(card_data)
		var comparison_box := REWARD_COMPARISON_BOX_SCENE.instantiate() as VBoxContainer
		body.add_child(comparison_box)
		for comparison_line in comparison_lines:
			var comparison_label := _make_card_label(str(comparison_line), TOKENS.FONT_LABEL, TOKENS.COLOR_POSITIVE)
			comparison_label.name = "ComparisonLine"
			_configure_wrapped_card_text(comparison_label)
			comparison_label.tooltip_text = ""
			comparison_box.add_child(comparison_label)

	var tag_text := str(card_data.get("short_tag", "")).strip_edges()
	if not is_module_reward and not chips.is_empty():
		var chip_row := REWARD_CHIP_ROW_SCENE.instantiate() as HFlowContainer
		BUILD_TAG_DISPLAY.populate_chip_row(chip_row, chips)
		body.add_child(chip_row)
	elif not is_module_reward and tag_text != "" and detail_variant != &"weapon_upgrade":
		var tag_label := _make_card_label(tag_text, 14, Color(0.82, 0.90, 0.95, 1.0))
		tag_label.name = "ShortTagLabel"
		tag_label.clip_text = true
		body.add_child(tag_label)

	var synergy_text := str(card_data.get("synergy_label", "")).strip_edges()
	if synergy_text != "":
		var synergy_label := _make_card_label(synergy_text, 13, _synergy_status_color(StringName(card_data.get("synergy_status", &"neutral"))))
		synergy_label.name = "SynergyStatusLabel"
		synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		synergy_label.max_lines_visible = 2
		synergy_label.tooltip_text = ""
		body.add_child(synergy_label)

	_set_mouse_filter_recursive(button, Control.MOUSE_FILTER_IGNORE)
	_clear_tooltips_recursive(button)
	_panel.call("_restore_weapon_preview_interactions", button)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_weapon_visual_reward:
		button.add_child(_build_weapon_branch_detail_overlay(weapon_preview, reward_index))
	return button

func _build_weapon_core_content(card_data: Dictionary) -> VBoxContainer:
	var content := WEAPON_CORE_CONTENT_SCENE.instantiate() as VBoxContainer
	var source_name := str(card_data.get("source_weapon_name", "")).strip_edges()
	var amount := int(card_data.get("core_amount", 1))
	var current_count := int(card_data.get("current_core_count", 0))
	var resulting_count := int(card_data.get("resulting_core_count", amount))
	var usage_lines: PackedStringArray = card_data.get("usable_branch_lines", PackedStringArray())
	content.call("set_data", {
		"title": LocalizationManager.tr_key("ui.reward.type.weapon_core", "Weapon Core"),
		"source_icon": _crop_reward_texture_to_content(card_data.get("source_weapon_icon", null) as Texture2D),
		"source": LocalizationManager.tr_format("ui.reward.core.source", {"name": source_name}, "Source: %s" % source_name),
		"show_source": source_name != "",
		"gain": LocalizationManager.tr_format("ui.reward.core.gain", {"amount": amount}, "+%d Core" % amount),
		"inventory": LocalizationManager.tr_format("ui.reward.core.inventory", {"current": current_count, "resulting": resulting_count}, "Inventory: %d → %d" % [current_count, resulting_count]),
		"current_count": current_count,
		"resulting_count": resulting_count,
		"tag_heading": LocalizationManager.tr_key("ui.reward.core.inherited_tags", "INHERITED CORE TAGS"),
		"usage_heading": LocalizationManager.tr_key("ui.reward.core.usable_by_label", "Supported Weapons"),
		"usage_lines": usage_lines,
		"usage_entries": card_data.get("usable_weapon_entries", []),
		"usage_summary": LocalizationManager.tr_format("ui.reward.core.usage_summary", {"weapons": int(card_data.get("usable_weapon_count", usage_lines.size())), "branches": int(card_data.get("usable_branch_count", usage_lines.size()))}, "Supports %d weapons" % int(card_data.get("usable_weapon_count", usage_lines.size()))),
		"usage_more": LocalizationManager.tr_format("ui.reward.core.more_usages", {"count": maxi(0, usage_lines.size() - 2)}, "%d more" % maxi(0, usage_lines.size() - 2)),
		"usage_empty": LocalizationManager.tr_key("ui.reward.core.no_usable_branches", "No available fusion recipes found yet"),
	})
	var chips: Array = card_data.get("chips", [])
	BUILD_TAG_DISPLAY.populate_chip_row(content.call("get_chip_grid") as GridContainer, chips)
	content.call("emphasize_inherited_tags")
	content.set_meta(&"core_chips", chips)
	content.set_meta(&"tag_weapon_map", card_data.get("tag_weapon_map", {}))
	return content

func _build_weapon_core_usage_section(card_data: Dictionary) -> VBoxContainer:
	var usage_lines: PackedStringArray = card_data.get("usable_branch_lines", PackedStringArray())
	var content := WEAPON_CORE_CONTENT_SCENE.instantiate() as VBoxContainer
	content.call("set_data", {
		"usage_heading": LocalizationManager.tr_key("ui.reward.core.usable_by_label", "Supported Weapons"),
		"usage_lines": usage_lines,
		"usage_summary": LocalizationManager.tr_format("ui.reward.core.usage_summary", {"weapons": int(card_data.get("usable_weapon_count", usage_lines.size())), "branches": int(card_data.get("usable_branch_count", usage_lines.size()))}, "Supports %d weapons" % int(card_data.get("usable_weapon_count", usage_lines.size()))),
		"usage_more": LocalizationManager.tr_format("ui.reward.core.more_usages", {"count": maxi(0, usage_lines.size() - 2)}, "%d more" % maxi(0, usage_lines.size() - 2)),
		"usage_empty": LocalizationManager.tr_key("ui.reward.core.no_usable_branches", "No available fusion recipes found yet"),
	})
	var usage_section := content.get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection") as VBoxContainer
	usage_section.get_parent().remove_child(usage_section)
	content.free()
	return usage_section

func _build_core_weapon_stats(card_data: Dictionary) -> HBoxContainer:
	var stats_box := CORE_WEAPON_STATS_SCENE.instantiate() as HBoxContainer
	var lines: PackedStringArray = card_data.get("core_stat_lines", PackedStringArray())
	var core_keys: Array[StringName] = [&"damage", &"fire_interval_sec", &"ammo"]
	var items: Array = []
	for index in range(3):
		var fallback_key: StringName = core_keys[index]
		var text := str(lines[index]) if index < lines.size() else WEAPON_STAT_FORMATTER.format_line(fallback_key, null, " ")
		var separator_index := text.find(" ")
		var heading_text := text.left(separator_index) if separator_index >= 0 else WEAPON_STAT_FORMATTER.format_label(fallback_key)
		var value_text := text.substr(separator_index + 1) if separator_index >= 0 else "--"
		items.append({"heading": heading_text, "value": value_text})
	stats_box.call("set_data", items)
	return stats_box

func _build_weapon_reward_hero(card_data: Dictionary) -> CenterContainer:
	var hero := WEAPON_REWARD_HERO_SCENE.instantiate() as CenterContainer
	var icon := _make_reward_icon(card_data, Vector2(132.0, 76.0), 6)
	icon.name = "WeaponHeroImage"
	hero.call("set_icon", icon)
	return hero

func _build_weapon_preview_section(preview: Dictionary, reward_index: int) -> VBoxContainer:
	var section := WEAPON_BRANCH_PREVIEW_SECTION_SCENE.instantiate() as VBoxContainer
	section.call("set_heading", _inline_text("BRANCH DETAILS", "分支详情"))
	var branch_row := section.call("get_branch_container") as HBoxContainer
	_panel.call("_configure_weapon_detail_hotspot", branch_row, reward_index)
	var branch_count := (preview.get("branches", []) as Array).size()
	var hint := _make_card_label(
		_inline_text("%d branches · hover or focus for details" % branch_count, "%d 条分支 · 悬停或聚焦查看" % branch_count),
		13,
		TOKENS.COLOR_TEXT_SECONDARY
	)
	hint.custom_minimum_size.y = 28.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	branch_row.add_child(hint)
	return section

func _build_branch_preview_node(branch: Dictionary) -> PanelContainer:
	var damage_types: Array = branch.get("damage_types", [])
	var state := StringName(branch.get("state", &"locked"))
	var panel_node := BRANCH_PREVIEW_CARD_SCENE.instantiate() as PanelContainer
	var branch_icon_slot_size := 18.0 if damage_types.size() > 1 else 20.0
	var branch_name := str(branch.get("name", "Branch"))
	var data := _branch_component_data(branch, damage_types)
	data["name"] = branch_name
	data["description"] = str(branch.get("description", ""))
	data["status"] = _branch_state_short(state)
	data["icon_size"] = branch_icon_slot_size
	panel_node.call("set_data", data)
	return panel_node

func _build_damage_type_icon_row(damage_types: Array, icon_size: float, row_name: String) -> HBoxContainer:
	var row := DAMAGE_TYPE_ICON_ROW_SCENE.instantiate() as HBoxContainer
	var items: Array = []
	for type_variant in damage_types.slice(0, 2):
		var damage_type := Attack.normalize_damage_type(type_variant)
		var texture := DAMAGE_TYPE_ICONS.get(damage_type) as Texture2D
		if texture == null:
			continue
		var damage_color := WEAPON_PREVIEW_DATA.damage_color(damage_type)
		items.append({"type": str(damage_type), "texture": texture, "color": damage_color})
	row.call("set_data", items, icon_size, row_name)
	return row

func _attach_damage_icons_to_weapon_name(name_label: Label, damage_types: Array) -> void:
	_attach_damage_icons_to_label(name_label, damage_types, 24.0, "WeaponDamageTypeIcons", 5.0)

func _attach_damage_icons_to_label(
	label: Label,
	damage_types: Array,
	icon_size: float,
	row_name: String,
	gap: float
) -> void:
	var icon_row := _build_damage_type_icon_row(damage_types, icon_size, row_name)
	if icon_row.get_child_count() == 0:
		return
	var icon_count := icon_row.get_child_count()
	var row_width := float(icon_count) * icon_size + float(maxi(icon_count - 1, 0)) * 2.0
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	icon_row.set_anchors_preset(Control.PRESET_CENTER)
	icon_row.offset_right = -text_width * 0.5 - gap
	icon_row.offset_left = icon_row.offset_right - row_width
	icon_row.offset_top = -icon_size * 0.5
	icon_row.offset_bottom = icon_size * 0.5
	label.add_child(icon_row)

func _attach_rarity_to_weapon_level(level_label: Label, rarity_label: Label) -> void:
	var level_font := level_label.get_theme_font("font")
	var level_font_size := level_label.get_theme_font_size("font_size")
	var level_width := level_font.get_string_size(
		level_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		level_font_size
	).x
	var rarity_font := rarity_label.get_theme_font("font")
	var rarity_font_size := rarity_label.get_theme_font_size("font_size")
	var rarity_width := rarity_font.get_string_size(
		rarity_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		rarity_font_size
	).x
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rarity_label.set_anchors_preset(Control.PRESET_CENTER)
	rarity_label.offset_left = level_width * 0.5 + 8.0
	rarity_label.offset_right = rarity_label.offset_left + rarity_width
	rarity_label.offset_top = -12.0
	rarity_label.offset_bottom = 12.0
	level_label.add_child(rarity_label)

func _build_weapon_branch_detail_overlay(preview: Dictionary, reward_index: int) -> PanelContainer:
	var overlay := WEAPON_BRANCH_DETAIL_OVERLAY_SCENE.instantiate() as PanelContainer
	overlay.call("set_heading", _inline_text("WEAPON BRANCH DETAILS", "武器分支详情"))
	var row := overlay.call("get_branch_container") as HBoxContainer
	for branch_variant in preview.get("branches", []):
		row.add_child(_build_branch_detail_card(branch_variant as Dictionary))
	overlay.mouse_entered.connect(Callable(_panel, "_on_detail_overlay_mouse_entered").bind(reward_index))
	overlay.mouse_exited.connect(Callable(_panel, "_on_detail_overlay_mouse_exited").bind(reward_index))
	return overlay

func _build_branch_detail_card(branch: Dictionary) -> PanelContainer:
	var damage_types: Array = branch.get("damage_types", [])
	var card := BRANCH_DETAIL_CARD_SCENE.instantiate() as PanelContainer
	var data := _branch_component_data(branch, damage_types)
	data["name"] = str(branch.get("name", "Branch"))
	data["type_text"] = _damage_type_text(damage_types)
	data["description"] = str(branch.get("description", ""))
	card.call("set_data", data)
	return card

func _branch_component_data(branch: Dictionary, damage_types: Array) -> Dictionary:
	var icon_items: Array = []
	var accent_colors: Array = []
	for type_variant in damage_types.slice(0, 2):
		var damage_type := Attack.normalize_damage_type(type_variant)
		var color := WEAPON_PREVIEW_DATA.damage_color(damage_type)
		accent_colors.append(color)
		var texture := DAMAGE_TYPE_ICONS.get(damage_type) as Texture2D
		if texture != null:
			icon_items.append({"type": str(damage_type), "texture": texture, "color": color})
	var satisfied_tags: Array = branch.get("satisfied_fusion_tags", [])
	var tag_items: Array = []
	for tag_variant in branch.get("fusion_required_tags", []):
		var tag := StringName(tag_variant)
		var satisfied := satisfied_tags.has(tag)
		tag_items.append({
			"id": str(tag),
			"text": "【%s】" % LocalizationManager.get_module_term(tag, str(tag).replace("_", " ").capitalize()),
			"satisfied": satisfied,
			"color": _branch_primary_color(damage_types) if satisfied else TOKENS.COLOR_TEXT_SECONDARY,
		})
	var fuse := int(branch.get("unlock_fuse", 2))
	return {
		"primary_color": _branch_primary_color(damage_types),
		"icon_items": icon_items,
		"accent_colors": accent_colors,
		"recipe_prefix": _inline_text("Fuse %d:" % fuse, "融合 %d：" % fuse),
		"recipe_tags": tag_items,
		"background": TOKENS.COLOR_SURFACE_INTERACTIVE if StringName(branch.get("state", &"locked")) == &"acquired" else TOKENS.COLOR_SURFACE,
	}

func _branch_primary_color(damage_types: Array) -> Color:
	if damage_types.is_empty():
		return WEAPON_PREVIEW_DATA.damage_color(&"physical")
	return WEAPON_PREVIEW_DATA.damage_color(StringName(damage_types[0]))

func _damage_type_text(damage_types: Array) -> String:
	var labels := PackedStringArray()
	for type_variant in damage_types:
		var key := StringName(type_variant)
		labels.append(LocalizationManager.get_module_term(key, str(key).capitalize()))
	return " + ".join(labels)

func _branch_state_short(state: StringName) -> String:
	match state:
		&"acquired": return "✓ %s" % _inline_text("OWNED", "已获得")
		&"available": return _inline_text("AVAILABLE", "可解锁")
		_: return _inline_text("LOCKED", "未解锁")

func _build_branch_fusion_recipe(branch: Dictionary, damage_types: Array) -> HBoxContainer:
	var recipe_row := BRANCH_FUSION_RECIPE_SCENE.instantiate() as HBoxContainer
	var fuse := int(branch.get("unlock_fuse", 2))
	var satisfied_tags: Array = branch.get("satisfied_fusion_tags", [])
	var satisfied_color := _branch_primary_color(damage_types)
	var tag_items: Array = []
	for tag_variant in branch.get("fusion_required_tags", []):
		var tag := StringName(tag_variant)
		var tag_text := LocalizationManager.get_module_term(tag, str(tag).replace("_", " ").capitalize())
		tag_items.append({"id": str(tag), "text": "【%s】" % tag_text, "satisfied": satisfied_tags.has(tag), "color": satisfied_color if satisfied_tags.has(tag) else TOKENS.COLOR_TEXT_SECONDARY})
	recipe_row.call("set_data", _inline_text("Fuse %d:" % fuse, "融合 %d：" % fuse), tag_items)
	return recipe_row

func _inline_text(english: String, chinese: String) -> String:
	return chinese if LocalizationManager.get_locale() == "zh_CN" else english

func _build_module_weapon_grid(card_data: Dictionary) -> VBoxContainer:
	var section := MODULE_FIT_SECTION_SCENE.instantiate() as VBoxContainer
	var previews: Array = card_data.get("compatible_weapons", [])
	var owned_count := int(card_data.get("owned_weapon_count", 0))
	var compatible_count := 0
	for preview_variant in previews:
		if bool((preview_variant as Dictionary).get("compatible", true)):
			compatible_count += 1
	var count_text := _inline_text(
		"Equippable %d/%d" % [compatible_count, owned_count],
		"可装备 %d/%d" % [compatible_count, owned_count]
	)
	section.call("set_data", {
		"heading": LocalizationManager.tr_key("ui.module.fit.title", "Fit Check"),
		"count": count_text,
		"empty": previews.is_empty(),
		"empty_text": LocalizationManager.tr_key("ui.reward.no_compatible_weapons", "No owned weapon can equip this module"),
	})
	var grid := section.call("get_grid") as GridContainer
	for preview_variant in previews.slice(0, 4):
		grid.add_child(_build_module_weapon_tile(preview_variant as Dictionary))
	return section

func _build_module_weapon_tile(preview: Dictionary) -> PanelContainer:
	var compatible := bool(preview.get("compatible", true))
	var has_slot := bool(preview.get("has_slot", not bool(preview.get("requires_replace", false))))
	var state_color := Color(0.40, 0.86, 0.57, 1.0)
	if not compatible:
		state_color = Color(1.0, 0.34, 0.28, 1.0)
	elif not has_slot:
		state_color = Color(0.95, 0.74, 0.30, 1.0)
	var tile := MODULE_FIT_WEAPON_TILE_SCENE.instantiate() as PanelContainer
	var weapon_name := str(preview.get("name", "Weapon"))
	var status_text := _inline_text("Can equip now", "可直接装备")
	var status_icon := "✓ "
	if not compatible:
		status_text = str(preview.get("reason", LocalizationManager.tr_key("ui.module.fit.not_compatible", "Not compatible")))
		status_icon = "✕ "
	elif not has_slot:
		status_text = _inline_text("Module slots full", "模组槽已满")
		status_icon = "! "
	else:
		var fit_reason := str(preview.get("fit_reason", "")).strip_edges()
		if fit_reason != "":
			status_text = _inline_text("Can equip now", "可直接装备")
	tile.call("set_data", {"icon": preview.get("icon_texture", null), "name": weapon_name, "status": status_icon + status_text, "status_tooltip": status_text, "state_color": state_color})
	return tile

func _card_comparison_lines(card_data: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for value in card_data.get("comparison_lines", PackedStringArray()):
		var line := str(value).strip_edges()
		if line != "":
			lines.append(line)
		if lines.size() >= 3:
			return lines
	if StringName(card_data.get("detail_variant", &"generic")) == &"weapon_upgrade":
		return lines
	var candidates: Array[Dictionary] = [
		{"heading": LocalizationManager.tr_key("ui.reward.detail.section.combat_profile", "Combat Profile"), "value": card_data.get("detail_role", "")},
		{"heading": LocalizationManager.tr_key("ui.reward.detail.section.main_effect", "Main Effect"), "value": card_data.get("detail_effect", "")},
		{"heading": LocalizationManager.tr_key("ui.reward.detail.section.result_preview", "Result Preview"), "value": card_data.get("outcome_text", "")},
	]
	for candidate in candidates:
		if lines.size() >= 3:
			break
		var value := _compact_detail_text(str(candidate.get("value", "")), 46)
		if value == "" or _line_collection_contains(lines, value):
			continue
		lines.append("%s  %s" % [str(candidate.get("heading", "")), value])
	if lines.size() < 2:
		for value in card_data.get("detail_bullets", PackedStringArray()):
			var line := _compact_detail_text(str(value), 46)
			if line != "" and not _line_collection_contains(lines, line):
				lines.append("• %s" % line)
			if lines.size() >= 2:
				break
	return lines

func _line_collection_contains(lines: PackedStringArray, value: String) -> bool:
	for line in lines:
		if str(line).contains(value) or value.contains(str(line)):
			return true
	return false

func _synergy_status_color(status: StringName) -> Color:
	match status:
		&"direct_fit", &"unlocks_chain": return TOKENS.COLOR_POSITIVE
		&"partial_fit": return TOKENS.COLOR_WARNING
		&"blocked", &"conflict": return TOKENS.COLOR_DANGER
		_: return TOKENS.COLOR_TEXT_SECONDARY

func _make_reward_icon(card_data: Dictionary, minimum_size: Vector2 = Vector2(56.0, 56.0), content_margin: int = 6) -> Control:
	var fallback_key := str(card_data.get("fallback_icon_key", "reward")).strip_edges()
	var chip := BUILD_TAG_DISPLAY.build_tag_chip(fallback_key)
	var accent: Color = chip.get("color", Color(0.54, 0.64, 0.72, 1.0))
	var root := REWARD_ICON_SCENE.instantiate() as Control
	root.name = "RewardIcon"
	var texture := card_data.get("icon_texture", null) as Texture2D
	if texture != null:
		if fallback_key == "weapon":
			texture = _crop_reward_texture_to_content(texture)
	var badge_text := str(card_data.get("icon_badge_text", "")).strip_edges()
	root.call("set_data", {"size": minimum_size, "margin": content_margin, "texture": texture, "fallback": _fallback_icon_text(fallback_key), "badge": badge_text, "badge_color": card_data.get("icon_badge_color", accent) as Color})
	return root

func _crop_reward_texture_to_content(source: Texture2D) -> Texture2D:
	if source == null:
		return source
	var cache_key := source.get_rid()
	if _cropped_reward_textures.has(cache_key):
		return _cropped_reward_textures[cache_key] as Texture2D
	var image := source.get_image()
	if image == null or image.is_empty():
		_cropped_reward_textures[cache_key] = source
		return source
	var used_rect := image.get_used_rect()
	if not used_rect.has_area():
		_cropped_reward_textures[cache_key] = source
		return source
	var texture_rect := Rect2i(Vector2i.ZERO, image.get_size())
	var padded_rect := used_rect.grow(2).intersection(texture_rect)
	if padded_rect == texture_rect:
		_cropped_reward_textures[cache_key] = source
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(padded_rect)
	_cropped_reward_textures[cache_key] = atlas
	return atlas

func _fallback_icon_text(icon_key: String) -> String:
	match icon_key:
		"weapon_core":
			return "C"
		"weapon":
			return "W"
		"module":
			return "M"
		"terrain":
			return "T"
		"task":
			return "Q"
		"economy":
			return "$"
		_:
			return "R"

func _make_card_label(text: String, font_size: int, font_color: Color) -> Label:
	var label := REWARD_CARD_LABEL_SCENE.instantiate() as Label
	label.call("set_data", text, font_size + CARD_FONT_SIZE_BONUS, font_color)
	return label

func _make_highlighted_module_summary(summary_text: String) -> RichTextLabel:
	var summary := MODULE_EFFECT_SUMMARY_SCENE.instantiate() as RichTextLabel
	summary.call("set_data", summary_text, TOKENS.COLOR_ACCENT_SYSTEM)
	return summary

func _configure_wrapped_card_text(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

func _make_rarity_label(rarity: String) -> Label:
	var normalized := RARITY_UTIL.normalize(rarity)
	var rarity_text := "%s %s" % [_rarity_symbol(normalized), RARITY_UTIL.get_display_name(normalized)]
	var label := _make_card_label(rarity_text, TOKENS.FONT_LABEL, RARITY_UTIL.get_color(normalized))
	label.name = "RarityLabel"
	label.set_meta(&"rarity", normalized)
	label.tooltip_text = RARITY_UTIL.get_display_name(normalized)
	return label

func _rarity_symbol(rarity: String) -> String:
	match RARITY_UTIL.normalize(rarity):
		RARITY_UTIL.RARE: return "◆"
		RARITY_UTIL.EPIC: return "✦"
		_: return "◇"

func _compact_detail_text(text: String, _max_characters: int) -> String:
	var compact := text.replace("\r", " ").replace("\n", " ").replace("  ", " ").strip_edges()
	return compact

func _weapon_reward_display_name(reward: RewardInfo, fallback_title: String) -> String:
	if reward != null:
		if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
			var target_name := reward.target_weapon_name.strip_edges()
			if target_name != "":
				return target_name
			var target_id := reward.target_weapon_id.strip_edges()
			if target_id != "":
				var localized_target := LocalizationManager.get_weapon_name_by_id(target_id, "").strip_edges()
				if localized_target != "":
					return localized_target
		var item_id := reward.item_id.strip_edges()
		if item_id != "":
			var localized_item := LocalizationManager.get_weapon_name_by_id(item_id, "").strip_edges()
			if localized_item != "":
				return localized_item
	var normalized_fallback := fallback_title.strip_edges()
	if normalized_fallback != "":
		return normalized_fallback
	return LocalizationManager.tr_key("ui.branch.weapon", "Weapon")

func _clear_tooltips_recursive(root: Control) -> void:
	root.tooltip_text = ""
	for child in root.get_children():
		if child is Control:
			_clear_tooltips_recursive(child as Control)

func _set_mouse_filter_recursive(root: Control, mouse_filter_value: Control.MouseFilter) -> void:
	for child in root.get_children():
		var control := child as Control
		if control == null:
			continue
		control.mouse_filter = mouse_filter_value
		_set_mouse_filter_recursive(control, mouse_filter_value)
