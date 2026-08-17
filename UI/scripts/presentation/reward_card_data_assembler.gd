extends RefCounted
class_name RewardCardDataAssembler

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const MODULE_FIT_FORMATTER := preload("res://UI/scripts/module_fit_formatter.gd")
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")
const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")
const WEAPON_DISPLAY_POLICY := preload("res://UI/scripts/presentation/weapon_display_policy.gd")
const WEAPON_STAT_FORMATTER := preload("res://UI/scripts/presentation/weapon_stat_formatter.gd")
const MODULE_OFFER_CATALOG := preload("res://Player/Weapons/Core/module_offer_catalog.gd")

var _owner: Object
func _init(owner: Object) -> void:
	_owner = owner

func _build_reward_card_data(reward: RewardInfo) -> Dictionary:
	var data := {
		"type": _localize_reward_category("Economy"),
		"name": LocalizationManager.tr_key("ui.reward.default", "Reward"),
		"tag": "",
	}
	if reward == null:
		return data
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		var weapon_name := reward.target_weapon_name.strip_edges()
		if weapon_name.strip_edges() == "":
			weapon_name = LocalizationManager.tr_key("ui.branch.weapon", "Weapon")
		data["type"] = _format_reward_type_label(reward, "Weapon")
		data["name"] = weapon_name
		data["tag"] = "Lv.%d -> Lv.%d" % [int(reward.target_weapon_from_level), int(reward.target_weapon_to_level)]
		return data
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		var definition := CellEffectRuntime.get_definition(reward.cell_effect_id)
		data["name"] = definition.get_display_name() if definition != null else _localize_reward_category("Cell Effect")
		data["type"] = _format_reward_type_label(reward, "Terrain")
		data["tag"] = _localize_reward_category("Cell Effect")
		return data
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		var task_definition := CellTaskModuleRuntime.get_definition(reward.task_module_id)
		if task_definition != null:
			data["name"] = task_definition.get_display_name()
			data["tag"] = task_definition.get_task_label()
		else:
			data["name"] = _localize_reward_category("Task Module")
			data["tag"] = _localize_reward_category("Task")
		data["type"] = _localize_reward_category("Task")
		return data
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var weapon_name := LocalizationManager.get_weapon_name_by_id(reward.item_id, reward.item_id)
		var base_weapon_text := LocalizationManager.tr_format(
			"ui.reward.weapon",
			{"id": weapon_name, "level": reward.item_level},
			"Weapon %s Lv.%d" % [weapon_name, reward.item_level]
		)
		var weapon_text := base_weapon_text
		var outcome := _get_weapon_obtain_prediction(reward.item_id)
		var result_type := str(outcome.get("result", "not_applicable"))
		if not outcome.is_empty():
			weapon_text = _format_weapon_obtain_prediction(base_weapon_text, weapon_name, outcome)
		if result_type == "fused":
			data["type"] = _format_reward_type_label(reward, LocalizationManager.tr_key("ui.reward.type.weapon_fusion", "Weapon Fusion"))
		elif result_type == "converted_to_gold":
			data["type"] = _format_reward_type_label(reward, LocalizationManager.tr_key("ui.reward.type.duplicate_weapon", "Duplicate Weapon"))
		else:
			data["type"] = _format_reward_type_label(reward, "Weapon")
		data["name"] = weapon_name
		data["tag"] = weapon_text if weapon_text != base_weapon_text else "Lv.%d" % int(reward.item_level)
		return data
	if reward.module_scene:
		var module_name := _extract_scene_name(reward.module_scene.resource_path)
		var module_id := reward.module_scene.resource_path.get_file().get_basename()
		if module_id != "":
			module_name = LocalizationManager.tr_key("module.%s.name" % module_id, module_name)
		data["type"] = _format_reward_type_label(reward, "Module")
		data["name"] = module_name
		data["tag"] = "Lv.%d" % max(1, reward.module_level)
		return data
	var economy_lines: PackedStringArray = []
	if reward.total_chip_value > 0:
		economy_lines.append(LocalizationManager.tr_format(
			"ui.reward.exp",
			{"value": reward.total_chip_value},
			"EXP +%d" % reward.total_chip_value
		))
	if reward.gold_value > 0:
		economy_lines.append(LocalizationManager.tr_format(
			"ui.reward.gold",
			{"value": reward.gold_value},
			"Gold +%d" % reward.gold_value
		))
	if not economy_lines.is_empty():
		var category := "Economy" if reward.gold_value > 0 or reward.reward_kind == RewardInfo.KIND_ECONOMY else "Supply"
		data["type"] = _format_reward_type_label(reward, category)
		data["name"] = economy_lines[0]
		if economy_lines.size() > 1:
			data["tag"] = economy_lines[1]
	return data

func _format_reward_type_label(_reward: RewardInfo, category: String) -> String:
	return _localize_reward_category(category)

func _localize_reward_category(category: String) -> String:
	var normalized := category.strip_edges()
	match normalized:
		"Weapon":
			return LocalizationManager.tr_key("ui.reward.category.weapon", normalized)
		"Module":
			return LocalizationManager.tr_key("ui.reward.category.module", normalized)
		"Terrain":
			return LocalizationManager.tr_key("ui.reward.category.terrain", normalized)
		"Task":
			return LocalizationManager.tr_key("ui.reward.category.task", normalized)
		"Task Module":
			return LocalizationManager.tr_key("ui.reward.category.task_module", normalized)
		"Economy":
			return LocalizationManager.tr_key("ui.reward.category.economy", normalized)
		"Supply":
			return LocalizationManager.tr_key("ui.reward.category.supply", normalized)
		"Cell Effect":
			return LocalizationManager.tr_key("ui.reward.category.cell_effect", normalized)
		"New Weapon":
			return LocalizationManager.tr_key("ui.reward.category.new_weapon", normalized)
		"Reward":
			return LocalizationManager.tr_key("ui.reward.default", normalized)
		_:
			return normalized

func _build_reward_display_data(reward: RewardInfo) -> Dictionary:
	var data := {
		"title": LocalizationManager.tr_key("ui.reward.default", "Reward"),
		"type_label": _localize_reward_category("Supply"),
		"short_tag": "",
		"detail_text": "",
		"outcome_text": "",
		"rarity": RARITY_UTIL.COMMON,
		"chips": [],
		"meta_text": "",
		"level_text": "",
		"summary_text": "",
		"role_summary": "",
		"feature_lines": PackedStringArray(),
		"detail_variant": &"generic",
		"detail_preview": "",
		"detail_role": "",
		"detail_effect": "",
		"comparison_lines": PackedStringArray(),
		"core_stat_lines": PackedStringArray(),
		"detail_bullets": PackedStringArray(),
		"icon_texture": null,
		"fallback_icon_key": "reward",
		"icon_badge_text": "",
		"icon_badge_color": Color(0.42, 0.78, 0.48, 1.0),
	}
	if reward == null:
		return data
	data["rarity"] = reward.get_rarity()
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		data["detail_variant"] = &"weapon_upgrade"
		var weapon_name := reward.target_weapon_name.strip_edges()
		if weapon_name == "":
			weapon_name = LocalizationManager.tr_key("ui.branch.weapon", "Weapon")
		data["title"] = weapon_name
		data["type_label"] = _format_reward_type_label(reward, LocalizationManager.tr_key("ui.reward.type.weapon_upgrade", "Weapon Upgrade"))
		data["short_tag"] = "Lv.%d -> Lv.%d" % [int(reward.target_weapon_from_level), int(reward.target_weapon_to_level)]
		data["level_text"] = str(data["short_tag"])
		data["meta_text"] = LocalizationManager.tr_format(
			"ui.reward.meta.equipped_weapon_upgrade",
			{"from": int(reward.target_weapon_from_level), "to": int(reward.target_weapon_to_level)},
			"Equipped weapon upgrade: Lv.%d -> Lv.%d" % [int(reward.target_weapon_from_level), int(reward.target_weapon_to_level)]
		)
		data["fallback_icon_key"] = "weapon"
		data["icon_badge_text"] = "Lv"
		data["icon_badge_color"] = _get_reward_action_color(reward)
		var upgrade_detail := PackedStringArray([str(data["short_tag"])])
		var upgrade_summary := LocalizationManager.tr_key(
			"ui.reward.summary.weapon_upgrade",
			"Upgrade equipped weapon level."
		)
		var target_definition := DataHandler.read_weapon_data(reward.target_weapon_id) as WeaponDefinition
		data["role_summary"] = _weapon_role_summary(reward.target_weapon_id)
		if target_definition != null:
			var model = WEAPON_DISPLAY_BUILDER.build_at_levels(
				target_definition,
				int(reward.target_weapon_from_level),
				int(reward.target_weapon_to_level)
			)
			data["icon_texture"] = model.icon
			if model.first_description_sentence() != "":
				upgrade_summary = model.first_description_sentence()
				upgrade_detail.append(upgrade_summary)
			var change_count := 0
			var comparison_lines := PackedStringArray()
			data["core_stat_lines"] = _core_upgrade_stat_lines(model.upgrade_deltas)
			for delta_data in model.upgrade_deltas:
				if not bool(delta_data.get("changed", false)):
					continue
				var delta_line := WEAPON_STAT_FORMATTER.format_delta_line(delta_data)
				upgrade_detail.append(delta_line)
				comparison_lines.append(delta_line)
				change_count += 1
				if change_count >= WEAPON_DISPLAY_POLICY.summary_limit(WEAPON_DISPLAY_POLICY.REWARD_DETAIL):
					break
			data["comparison_lines"] = comparison_lines
		data["detail_text"] = "\n".join(upgrade_detail)
		data["detail_preview"] = str(data["short_tag"])
		data["detail_effect"] = "\n".join(upgrade_detail.slice(1))
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.weapon_upgrade", "Upgrade equipped weapon level")
		data["summary_text"] = upgrade_summary
		data["detail_bullets"] = _fallback_detail_bullets(reward)
		return data
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		var definition := CellEffectRuntime.get_definition(reward.cell_effect_id)
		if definition != null:
			data["title"] = definition.get_display_name()
			data["detail_text"] = definition.get_description()
			data["icon_texture"] = definition.icon_texture
		else:
			data["title"] = _localize_reward_category("Cell Effect")
		data["type_label"] = _format_reward_type_label(reward, "Terrain")
		data["short_tag"] = _localize_reward_category("Cell Effect")
		data["level_text"] = str(data["short_tag"])
		data["meta_text"] = LocalizationManager.tr_key("ui.reward.cell_effect_meta", "Terrain Effect")
		data["fallback_icon_key"] = "terrain"
		data["chips"] = [BUILD_TAG_DISPLAY.build_tag_chip(&"terrain", _localize_reward_category("Terrain"))]
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.cell_effect", "Added to cell effects")
		data["summary_text"] = _first_sentence(str(data["detail_text"]), LocalizationManager.tr_key("ui.reward.summary.cell_effect", "Adds a terrain effect."))
		_apply_structured_description(data, str(data["detail_text"]), str(data["summary_text"]))
		data["detail_bullets"] = _fallback_detail_bullets(reward)
		return data
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		var task_definition := CellTaskModuleRuntime.get_definition(reward.task_module_id)
		if task_definition != null:
			data["title"] = task_definition.get_display_name()
			data["short_tag"] = LocalizationManager.tr_format(
				"ui.reward.task_tag",
				{"task": task_definition.get_task_label()},
				"Task: %s" % task_definition.get_task_label()
			)
			data["detail_text"] = task_definition.get_description()
			data["icon_texture"] = task_definition.icon_texture
			data["meta_text"] = LocalizationManager.tr_format(
				"ui.reward.task_module_meta",
				{"task": task_definition.get_task_label()},
				"%s Task Module" % task_definition.get_task_label()
			)
		else:
			data["title"] = _localize_reward_category("Task Module")
			data["short_tag"] = LocalizationManager.tr_format(
				"ui.reward.task_tag",
				{"task": LocalizationManager.tr_key("ui.common.unknown", "Unknown")},
				"Task: Unknown"
			)
			data["meta_text"] = _localize_reward_category("Task Module")
		data["type_label"] = _localize_reward_category("Task Module")
		data["fallback_icon_key"] = "task"
		data["chips"] = [BUILD_TAG_DISPLAY.build_tag_chip(&"task", _localize_reward_category("Task"))]
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.task_module", "Added to Ready To Install")
		data["level_text"] = str(data["short_tag"])
		data["summary_text"] = _first_sentence(str(data["detail_text"]), LocalizationManager.tr_key("ui.reward.summary.task_module", "Adds a task module."))
		_apply_structured_description(data, str(data["detail_text"]), str(data["summary_text"]))
		data["detail_bullets"] = _fallback_detail_bullets(reward)
		return data
	var summary_chunks: PackedStringArray = []
	var detail_chunks: PackedStringArray = []
	data["type_label"] = _format_reward_type_label(reward, "Reward")
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		data["detail_variant"] = &"new_weapon"
		var weapon_name := LocalizationManager.get_weapon_name_by_id(reward.item_id, reward.item_id)
		var weapon_definition := DataHandler.read_weapon_data(reward.item_id) as WeaponDefinition
		data["role_summary"] = _weapon_role_summary(reward.item_id)
		var base_weapon_text := LocalizationManager.tr_format(
			"ui.reward.weapon",
			{"id": weapon_name, "level": reward.item_level},
			"Weapon %s Lv.%d" % [weapon_name, reward.item_level]
		)
		var weapon_text := base_weapon_text
		var outcome := _get_weapon_obtain_prediction(reward.item_id)
		var result_type := str(outcome.get("result", "not_applicable"))
		if result_type == "not_applicable":
			outcome = _with_new_weapon_destination_prediction(outcome)
		if not outcome.is_empty():
			weapon_text = _format_weapon_obtain_prediction(base_weapon_text, weapon_name, outcome)
		summary_chunks.append(weapon_name)
		detail_chunks.append(weapon_text)
		if weapon_definition != null:
			var model = WEAPON_DISPLAY_BUILDER.build_from_definition(weapon_definition, int(reward.item_level))
			data["icon_texture"] = model.icon
			var structured_weapon_copy := _structured_description(model.description)
			if not structured_weapon_copy.is_empty():
				data["summary_text"] = str(structured_weapon_copy[0])
				data["detail_effect"] = str(structured_weapon_copy[0])
				data["feature_lines"] = structured_weapon_copy.slice(1, mini(3, structured_weapon_copy.size()))
				detail_chunks.append(model.description)
			if not model.taxonomy_labels.is_empty():
				detail_chunks.append(model.taxonomy_text())
				data["detail_role"] = model.taxonomy_text()
			var stat_summary := WEAPON_STAT_FORMATTER.format_summary(
				model.current_stats,
				WEAPON_DISPLAY_POLICY.summary_limit(WEAPON_DISPLAY_POLICY.REWARD_DETAIL),
				" · "
			)
			if stat_summary != "":
				detail_chunks.append(stat_summary)
				data["comparison_lines"] = PackedStringArray(stat_summary.split(" · ", false))
			data["core_stat_lines"] = _core_current_stat_lines(model.current_stats)
		data["type_label"] = _format_reward_type_label(reward, "New Weapon")
		data["level_text"] = "Lv.%d" % int(reward.item_level)
		data["meta_text"] = LocalizationManager.tr_format(
			"ui.reward.level_category_meta",
			{"level": int(reward.item_level), "category": LocalizationManager.tr_key("ui.branch.weapon", "Weapon")},
			"Lv.%d - %s" % [int(reward.item_level), LocalizationManager.tr_key("ui.branch.weapon", "Weapon")]
		)
		data["fallback_icon_key"] = "weapon"
		data["icon_badge_text"] = ""
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.weapon_obtain", "Obtain new weapon")
		data["detail_preview"] = LocalizationManager.tr_format(
			"ui.reward.detail.preview.new_weapon",
			{"name": weapon_name, "level": int(reward.item_level)},
			"Obtain %s · Lv.%d" % [weapon_name, int(reward.item_level)]
		)
		if result_type == "fused":
			data["detail_variant"] = &"weapon_fusion"
			var from_fuse := int(outcome.get("from_fuse", 1))
			var target_fuse := int(outcome.get("target_fuse", 1))
			data["type_label"] = _format_reward_type_label(reward, LocalizationManager.tr_key("ui.reward.type.weapon_fusion", "Weapon Fusion"))
			data["meta_text"] = LocalizationManager.tr_format(
				"ui.reward.meta.weapon_fuse",
				{"from": from_fuse, "to": target_fuse},
				"Fuse %d -> %d" % [from_fuse, target_fuse]
			)
			data["icon_badge_text"] = "^"
			data["icon_badge_color"] = _get_reward_action_color(reward)
			data["outcome_text"] = LocalizationManager.tr_format(
				"ui.reward.outcome.weapon_fuse",
				{"name": weapon_name, "fuse": target_fuse},
				"Fuse equipped %s to Fuse %d; choose a branch next if one is available" % [weapon_name, target_fuse]
			)
			data["detail_preview"] = LocalizationManager.tr_format(
				"ui.reward.detail.preview.weapon_fusion",
				{"name": weapon_name, "from": from_fuse, "to": target_fuse},
				"%s · Fuse %d -> %d" % [weapon_name, from_fuse, target_fuse]
			)
		elif result_type == "converted_to_gold":
			var gold_value := int(outcome.get("gold", 0))
			data["role_summary"] = ""
			data["title"] = LocalizationManager.tr_format(
				"ui.reward.gold",
				{"value": gold_value},
				"Gold +%d" % gold_value
			)
			data["type_label"] = _format_reward_type_label(reward, "Economy")
			data["meta_text"] = LocalizationManager.tr_key("ui.reward.economy_meta", "Run Resource")
			data["short_tag"] = ""
			summary_chunks.clear()
			summary_chunks.append(str(data["title"]))
			detail_chunks.clear()
			detail_chunks.append(str(data["title"]))
			data["icon_badge_text"] = "$"
			data["icon_badge_color"] = _get_reward_action_color(reward)
			data["fallback_icon_key"] = "economy"
			data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.resource", "Added to resources")
	if reward.module_scene:
		var module_data := _build_module_reward_display_data(reward.module_scene, reward.module_level)
		var module_name := str(module_data.get("name", _extract_scene_name(reward.module_scene.resource_path)))
		var module_summary := LocalizationManager.tr_format(
			"ui.reward.module",
			{"name": module_name, "level": max(1, reward.module_level)},
			"Module %s Lv.%d" % [module_name, max(1, reward.module_level)]
		)
		summary_chunks.append(module_name)
		detail_chunks.append(module_summary)
		var module_short_tag := str(module_data.get("short_tag", "")).strip_edges()
		if module_short_tag != "":
			summary_chunks.append(module_short_tag)
		var module_detail := str(module_data.get("detail_text", "")).strip_edges()
		if module_detail != "":
			detail_chunks.append(module_detail)
		data["chips"] = module_data.get("chips", [])
		data["icon_texture"] = module_data.get("icon_texture", null)
		data["summary_text"] = module_data.get("effect_summary", "")
		data["feature_lines"] = module_data.get("effect_lines", PackedStringArray())
		data["compatible_weapons"] = module_data.get("compatible_weapons", [])
		data["owned_weapon_count"] = int(module_data.get("owned_weapon_count", 0))
		data["fallback_icon_key"] = "module"
		data["meta_text"] = LocalizationManager.tr_format(
			"ui.reward.level_category_meta",
			{"level": max(1, reward.module_level), "category": _format_reward_type_label(reward, "Module")},
			"Lv.%d - %s" % [max(1, reward.module_level), _format_reward_type_label(reward, "Module")]
		)
		var module_type_label := _format_reward_type_label(reward, "Module")
		if MODULE_OFFER_CATALOG.is_new_tier_scene(reward.module_scene.resource_path):
			module_type_label = "NEW · %s" % module_type_label
		data["type_label"] = module_type_label
		data["level_text"] = "Lv.%d" % max(1, reward.module_level)
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.module_obtain", "Added to temporary modules")
	if reward.total_chip_value > 0:
		summary_chunks.append(LocalizationManager.tr_format(
			"ui.reward.exp",
			{"value": reward.total_chip_value},
			"EXP +%d" % reward.total_chip_value
		))
		data["chips"] = _append_display_chip(data.get("chips", []), BUILD_TAG_DISPLAY.build_tag_chip(&"economy", _localize_reward_category("Economy")))
		data["type_label"] = _format_reward_type_label(reward, "Economy")
		data["meta_text"] = LocalizationManager.tr_key("ui.reward.economy_meta", "Run Resource")
		data["fallback_icon_key"] = "economy"
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.resource", "Added to resources")
	if reward.gold_value > 0:
		summary_chunks.append(LocalizationManager.tr_format(
			"ui.reward.gold",
			{"value": reward.gold_value},
			"Gold +%d" % reward.gold_value
		))
		data["chips"] = _append_display_chip(data.get("chips", []), BUILD_TAG_DISPLAY.build_tag_chip(&"economy", _localize_reward_category("Economy")))
		data["type_label"] = _format_reward_type_label(reward, "Economy")
		data["meta_text"] = LocalizationManager.tr_key("ui.reward.economy_meta", "Run Resource")
		data["fallback_icon_key"] = "economy"
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.resource", "Added to resources")
	if not summary_chunks.is_empty():
		data["title"] = summary_chunks[0]
		if summary_chunks.size() > 1:
			data["short_tag"] = " + ".join(summary_chunks.slice(1))
		var detail_source: PackedStringArray = detail_chunks if not detail_chunks.is_empty() else summary_chunks
		data["detail_text"] = "\n".join(detail_source)
	if str(data["summary_text"]).strip_edges() == "":
		data["summary_text"] = _first_sentence(str(data["detail_text"]), _fallback_summary(reward))
	if str(data["level_text"]).strip_edges() == "":
		data["level_text"] = _derive_level_text(reward, data)
	data["detail_bullets"] = _fallback_detail_bullets(reward)
	return data

func _weapon_role_summary(weapon_id: String) -> String:
	var normalized_id := weapon_id.strip_edges()
	if normalized_id == "":
		return ""
	return LocalizationManager.tr_key("weapon.%s.role_summary" % normalized_id, "")

func _core_current_stat_lines(stats: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for key in [&"damage", &"fire_interval_sec", &"ammo"]:
		lines.append(WEAPON_STAT_FORMATTER.format_line(key, stats.get(str(key), stats.get(key, null)), " "))
	return lines

func _core_upgrade_stat_lines(deltas: Array[Dictionary]) -> PackedStringArray:
	var by_key := {}
	for delta_data in deltas:
		by_key[StringName(str(delta_data.get("key", &"")))] = delta_data
	var lines := PackedStringArray()
	for key in [&"damage", &"fire_interval_sec", &"ammo"]:
		if by_key.has(key):
			lines.append(WEAPON_STAT_FORMATTER.format_delta_line(by_key[key] as Dictionary))
		else:
			lines.append(WEAPON_STAT_FORMATTER.format_line(key, null, " "))
	return lines

func _apply_structured_description(data: Dictionary, description: String, fallback: String) -> void:
	var lines := _structured_description(description)
	if lines.is_empty():
		data["summary_text"] = fallback
		data["feature_lines"] = PackedStringArray()
		return
	data["summary_text"] = str(lines[0])
	data["feature_lines"] = lines.slice(1, mini(3, lines.size()))

func _structured_description(description: String) -> PackedStringArray:
	var normalized := description.replace("\r", " ").replace("\n", " ").strip_edges()
	for delimiter in ["；", ";", "。", ".", "！", "!", "？", "?"]:
		normalized = normalized.replace(delimiter, "\n")
	var lines := PackedStringArray()
	for fragment in normalized.split("\n", false):
		var line := str(fragment).strip_edges()
		if line != "" and not lines.has(line):
			lines.append(line)
	return lines

func _build_module_reward_display_data(module_scene: PackedScene, module_level: int) -> Dictionary:
	var data := {
		"name": "",
		"short_tag": "",
		"detail_text": "",
		"effect_summary": "",
		"effect_lines": PackedStringArray(),
		"compatible_weapons": [],
		"owned_weapon_count": 0,
		"chips": [],
		"icon_texture": null,
	}
	if module_scene == null:
		return data
	var module_instance := module_scene.instantiate() as Module
	if module_instance == null:
		return data
	module_instance.set_module_level(max(1, module_level))
	data["name"] = LocalizationManager.get_module_name(module_instance)
	data["icon_texture"] = _get_module_texture(module_instance)
	var fit_data: Dictionary = MODULE_FIT_FORMATTER.build_display_data(module_instance, MODULE_FIT_FORMATTER.get_current_weapon())
	var effect_chips: Array = fit_data.get("effect_chips", [])
	var chips: Array = []
	chips.append(fit_data.get("fit_badge", {}))
	for chip in effect_chips:
		chips.append(chip)
	data["chips"] = chips
	var tag_parts := PackedStringArray()
	var fit_label := str(fit_data.get("fit_label", "")).strip_edges()
	if fit_label != "":
		tag_parts.append(fit_label)
	for label in BUILD_TAG_DISPLAY.chip_labels(effect_chips, 3):
		tag_parts.append(str(label))
	if not tag_parts.is_empty():
		data["short_tag"] = " / ".join(tag_parts)
	var descriptions := PackedStringArray()
	var effect_descriptions := PackedStringArray()
	for description in module_instance.get_effect_descriptions():
		var effect_line := str(description).strip_edges()
		if MODULE_FIT_FORMATTER.filter_effect_description(effect_line):
			effect_descriptions.append(effect_line)
	if not effect_descriptions.is_empty():
		data["effect_summary"] = effect_descriptions[0]
		data["effect_lines"] = effect_descriptions.slice(1, mini(3, effect_descriptions.size()))
	data["compatible_weapons"] = _build_compatible_weapon_previews(module_instance)
	data["owned_weapon_count"] = _valid_owned_weapon_count()
	for detail_line in fit_data.get("detail_lines", PackedStringArray()):
		var fit_line := str(detail_line).strip_edges()
		if fit_line != "":
			descriptions.append(fit_line)
	var chip_labels := BUILD_TAG_DISPLAY.chip_labels(effect_chips, 4)
	if not chip_labels.is_empty():
		descriptions.append(_format_module_chip_summary(effect_chips))
	for effect_line in effect_descriptions:
		descriptions.append(effect_line)
	data["detail_text"] = "\n".join(descriptions)
	module_instance.queue_free()
	return data

func _build_compatible_weapon_previews(module_instance: Module) -> Array:
	var previews: Array = []
	if module_instance == null or not is_instance_valid(module_instance):
		return previews
	for weapon_variant in PlayerData.player_weapon_list:
		var weapon := weapon_variant as Weapon
		if weapon == null or not is_instance_valid(weapon):
			continue
		if str(module_instance.get_incompatibility_reason(weapon)).strip_edges() != "":
			continue
		var used_slots := weapon.get_module_count()
		var max_slots := weapon.module_slot_capacity
		previews.append({
			"name": LocalizationManager.get_weapon_instance_display_name(weapon),
			"icon_texture": weapon.sprite.texture if weapon.sprite != null else null,
			"used_slots": used_slots,
			"max_slots": max_slots,
			"requires_replace": used_slots >= max_slots,
		})
		if previews.size() >= 4:
			break
	return previews

func _valid_owned_weapon_count() -> int:
	var count := 0
	for weapon_variant in PlayerData.player_weapon_list:
		var weapon := weapon_variant as Weapon
		if weapon != null and is_instance_valid(weapon):
			count += 1
	return count

func _format_module_chip_summary(effect_chips: Array) -> String:
	var compatibility := PackedStringArray()
	var tags := PackedStringArray()
	for chip in effect_chips:
		var chip_data := chip as Dictionary
		var label := str(chip_data.get("label", "")).strip_edges()
		if label == "":
			continue
		var source_key := str(chip_data.get("source_key", "")).strip_edges()
		if source_key == "projectile" or source_key == "beam" or source_key == "area" or source_key == "melee_contact":
			compatibility.append(label)
		else:
			tags.append(label)
	var lines := PackedStringArray()
	if not tags.is_empty():
		lines.append(LocalizationManager.tr_format(
			"ui.reward.detail.tags",
			{"tags": " / ".join(tags.slice(0, 4))},
			"Tags: %s" % " / ".join(tags.slice(0, 4))
		))
	if not compatibility.is_empty():
		lines.append(LocalizationManager.tr_format(
			"ui.reward.detail.compatible_with",
			{"types": " / ".join(compatibility)},
			"Compatible With: %s" % " / ".join(compatibility)
		))
	return "\n".join(lines)

func _get_reward_action_color(reward: RewardInfo) -> Color: return _owner.call("_get_reward_action_color", reward)
func _get_weapon_obtain_prediction(weapon_id: String) -> Dictionary: return _owner.call("_get_weapon_obtain_prediction", weapon_id)
func _with_new_weapon_destination_prediction(outcome: Dictionary) -> Dictionary: return _owner.call("_with_new_weapon_destination_prediction", outcome)
func _format_weapon_obtain_prediction(base_text: String, weapon_name: String, outcome: Dictionary) -> String: return _owner.call("_format_weapon_obtain_prediction", base_text, weapon_name, outcome)
func _extract_scene_name(path: String) -> String: return _owner.call("_extract_scene_name", path)
func _get_module_texture(module_instance: Module) -> Texture2D: return _owner.call("_get_module_texture", module_instance)
func _first_sentence(value: String, fallback: String) -> String: return _owner.call("_first_sentence", value, fallback)
func _fallback_summary(reward: RewardInfo) -> String: return _owner.call("_fallback_summary", reward)
func _derive_level_text(reward: RewardInfo, data: Dictionary) -> String: return _owner.call("_derive_level_text", reward, data)
func _fallback_detail_bullets(reward: RewardInfo) -> PackedStringArray: return _owner.call("_fallback_detail_bullets", reward)
func _append_display_chip(existing: Variant, chip: Dictionary) -> Array: return _owner.call("_append_display_chip", existing, chip)
