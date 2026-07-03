extends RefCounted
class_name ModuleFitFormatter

const STATUS_FITS: StringName = &"fits"
const STATUS_BLOCKED: StringName = &"blocked"
const STATUS_UNKNOWN: StringName = &"unknown"
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")

static func build_display_data(module_instance: Module, target_weapon: Weapon = null) -> Dictionary:
	var no_weapon := LocalizationManager.tr_key("ui.module.fit.no_weapon", "No current weapon")
	var data := {
		"effect_chips": [],
		"fit_badge": BUILD_TAG_DISPLAY.build_fit_status_badge(STATUS_UNKNOWN, no_weapon),
		"fit_status": STATUS_UNKNOWN,
		"fit_label": no_weapon,
		"fit_warnings": PackedStringArray(),
		"detail_lines": PackedStringArray(),
	}
	if module_instance == null or not is_instance_valid(module_instance):
		var invalid_module := LocalizationManager.tr_key("ui.module.fit.invalid_module", "Invalid module")
		data["fit_label"] = invalid_module
		data["fit_badge"] = BUILD_TAG_DISPLAY.build_fit_status_badge(STATUS_UNKNOWN, invalid_module)
		return data
	var effect_chips := build_effect_chips(module_instance)
	data["effect_chips"] = effect_chips
	if target_weapon == null or not is_instance_valid(target_weapon):
		data["detail_lines"] = PackedStringArray([
			LocalizationManager.tr_key("ui.module.fit.detail.no_weapon", "Fit: No current weapon")
		])
		return data
	var reason := ""
	if module_instance.has_method("get_incompatibility_reason"):
		reason = str(module_instance.get_incompatibility_reason(target_weapon)).strip_edges()
	if reason == "":
		data["fit_status"] = STATUS_FITS
		data["fit_label"] = LocalizationManager.tr_key("ui.module.fit.current", "Fits current")
		data["fit_badge"] = BUILD_TAG_DISPLAY.build_fit_status_badge(
			STATUS_FITS,
			LocalizationManager.tr_key("ui.module.fit.fits", "Fits")
		)
		data["detail_lines"] = PackedStringArray([
			LocalizationManager.tr_key(
				"ui.module.fit.detail.compatible",
				"Fit: Current weapon satisfies module requirements"
			)
		])
	else:
		var localized_reason := LocalizationManager.localize_module_reason(reason)
		var warnings := PackedStringArray([localized_reason])
		data["fit_status"] = STATUS_BLOCKED
		data["fit_label"] = LocalizationManager.tr_key("ui.module.fit.not_compatible", "Not compatible")
		data["fit_badge"] = BUILD_TAG_DISPLAY.build_fit_status_badge(
			STATUS_BLOCKED,
			LocalizationManager.tr_key("ui.module.fit.blocked", "Blocked")
		)
		data["fit_warnings"] = warnings
		data["detail_lines"] = PackedStringArray([
			LocalizationManager.tr_key(
				"ui.module.fit.detail.incompatible",
				"Fit: Current weapon does not satisfy module requirements"
			),
			LocalizationManager.tr_format(
				"ui.module.fit.warning",
				{"reason": localized_reason},
				"Warning: %s" % localized_reason
			),
		])
	return data

static func build_effect_chips(module_instance: Module, limit: int = 0) -> Array:
	var chips: Array = []
	if module_instance == null or not is_instance_valid(module_instance):
		return chips
	for tag in module_instance.get_normalized_module_tags():
		_append_unique_chip(chips, BUILD_TAG_DISPLAY.build_tag_chip(tag, _format_taxonomy_label(tag)))
	for hook in module_instance.get_normalized_required_hooks():
		var hook_key := _format_hook_tag_key(hook)
		_append_unique_chip(chips, BUILD_TAG_DISPLAY.build_tag_chip(hook_key, _format_hook_tag(hook)))
	for delivery in module_instance.get_normalized_required_delivery_types():
		_append_unique_chip(chips, BUILD_TAG_DISPLAY.build_tag_chip(delivery, _format_taxonomy_label(delivery)))
	_append_stat_chips(chips, module_instance)
	if chips.is_empty():
		_append_unique_chip(
			chips,
			BUILD_TAG_DISPLAY.build_tag_chip(
				&"buff",
				LocalizationManager.get_module_term(&"buff", "Buff")
			)
		)
	if limit > 0 and chips.size() > limit:
		return chips.slice(0, limit)
	return chips

static func build_short_card_text(module_instance: Module, target_weapon: Weapon = null, max_effect_chips: int = 3) -> String:
	var data := build_display_data(module_instance, target_weapon)
	var parts := PackedStringArray()
	var fit_label := str(data.get("fit_label", "")).strip_edges()
	if fit_label != "":
		parts.append(fit_label)
	for label in BUILD_TAG_DISPLAY.chip_labels(data.get("effect_chips", []), max_effect_chips):
		parts.append(str(label))
	return " / ".join(parts)

static func get_current_weapon() -> Weapon:
	if PlayerData.player_weapon_list.is_empty():
		return null
	var index := int(PlayerData.main_weapon_index)
	if index < 0:
		index = int(PlayerData.on_select_weapon)
	if index < 0 or index >= PlayerData.player_weapon_list.size():
		index = 0
	return PlayerData.player_weapon_list[index] as Weapon

static func filter_effect_description(line: String) -> bool:
	var text := line.strip_edges()
	if text == "":
		return false
	var hidden_prefixes := PackedStringArray([
		"Build Tags:",
		"Effect Tags:",
		"Best On:",
		"Triggers:",
		LocalizationManager.tr_key("ui.module.build_tags_prefix", "Build Tags:"),
		LocalizationManager.tr_key("ui.module.effect_tags_prefix", "Effect Tags:"),
		LocalizationManager.tr_key("ui.module.best_on_prefix", "Best On:"),
		LocalizationManager.tr_key("ui.module.triggers_prefix", "Triggers:"),
	])
	for prefix in hidden_prefixes:
		if text.begins_with(prefix):
			return false
	return true

static func _append_stat_chips(chips: Array, module_instance: Module) -> void:
	for key_variant in module_instance.stat_multipliers.keys():
		_append_unique_chip(chips, BUILD_TAG_DISPLAY.build_tag_chip(str(key_variant), _format_stat_key_label(str(key_variant))))
	for key_variant in module_instance.stat_additives.keys():
		_append_unique_chip(chips, BUILD_TAG_DISPLAY.build_tag_chip(str(key_variant), _format_stat_key_label(str(key_variant))))
	if chips.is_empty() and not module_instance.level_effects.is_empty():
		_append_unique_chip(
			chips,
			BUILD_TAG_DISPLAY.build_tag_chip(
				&"buff",
				LocalizationManager.get_module_term(&"buff", "Buff")
			)
		)

static func _format_stat_key_label(stat_key: String) -> String:
	var normalized := stat_key.strip_edges().to_lower()
	if normalized.contains("damage"):
		return LocalizationManager.get_module_term(&"stat.damage", "Damage")
	if normalized.contains("reload"):
		return LocalizationManager.get_module_term(&"reload", "Reload")
	if normalized.contains("heat"):
		return LocalizationManager.get_module_term(&"heat", "Heat")
	if normalized.contains("ammo") or normalized.contains("magazine"):
		return LocalizationManager.get_module_term(&"ammo", "Ammo")
	if normalized.contains("size") or normalized.contains("speed") or normalized.contains("bullet"):
		return LocalizationManager.get_module_term(&"projectile", "Projectile")
	if normalized.contains("crit"):
		return LocalizationManager.get_module_term(&"crit", "Crit")
	if normalized.contains("shield") or normalized.contains("armor") or normalized.contains("hp"):
		return LocalizationManager.get_module_term(&"defense", "Defense")
	if normalized.contains("radius") or normalized.contains("area") or normalized.contains("angle"):
		return LocalizationManager.get_module_term(&"area", "Area")
	var fallback := stat_key.replace("_", " ").capitalize()
	return LocalizationManager.get_module_term(StringName("stat.%s" % normalized), fallback)

static func _format_hook_tag(hook: StringName) -> String:
	if hook == ModuleHook.HIT \
			or hook == ModuleHook.DAMAGE_DEALT \
			or hook == ModuleHook.AREA_DAMAGE \
			or hook == ModuleHook.BEAM_HIT:
		return LocalizationManager.get_module_term(&"on_hit", "On Hit")
	if hook == ModuleHook.RELOAD_START or hook == ModuleHook.RELOAD_DURATION:
		return LocalizationManager.get_module_term(&"reload", "Reload")
	if hook == ModuleHook.KILL:
		return LocalizationManager.get_module_term(&"execute", "Execute")
	if hook == ModuleHook.PROJECTILE_SPAWN:
		return LocalizationManager.get_module_term(&"projectile", "Projectile")
	return ""

static func _format_hook_tag_key(hook: StringName) -> StringName:
	if hook == ModuleHook.HIT \
			or hook == ModuleHook.DAMAGE_DEALT \
			or hook == ModuleHook.AREA_DAMAGE \
			or hook == ModuleHook.BEAM_HIT:
		return &"on_hit"
	if hook == ModuleHook.RELOAD_START or hook == ModuleHook.RELOAD_DURATION:
		return &"reload"
	if hook == ModuleHook.KILL:
		return &"execute"
	if hook == ModuleHook.PROJECTILE_SPAWN:
		return &"projectile"
	return hook

static func _format_taxonomy_label(value: StringName) -> String:
	var fallback := ""
	match StringName(str(value)):
		&"heat":
			fallback = "Heat"
		&"mark":
			fallback = "Mark"
		&"freeze":
			fallback = "Freeze"
		&"reload":
			fallback = "Reload"
		&"close":
			fallback = "Close"
		&"area":
			fallback = "Area"
		&"beam":
			fallback = "Beam"
		&"projectile":
			fallback = "Projectile"
		&"melee_contact":
			fallback = "Melee"
		&"on_hit":
			fallback = "On Hit"
		&"execute":
			fallback = "Execute"
		&"defense":
			fallback = "Defense"
		&"economy":
			fallback = "Economy"
		&"physical":
			fallback = "Physical"
		&"energy":
			fallback = "Energy"
		&"fire":
			fallback = "Fire"
		&"charge":
			fallback = "Charge"
		&"summon":
			fallback = "Summon"
		&"trap":
			fallback = "Trap"
		&"support":
			fallback = "Support"
		&"movement":
			fallback = "Movement"
		&"buff":
			fallback = "Buff"
		&"debuff":
			fallback = "Debuff"
		&"dot":
			fallback = "DoT"
		&"duration":
			fallback = "Duration"
		&"stacking":
			fallback = "Stacking"
		&"trigger":
			fallback = "Trigger"
		_:
			fallback = str(value).replace("_", " ").capitalize()
	return LocalizationManager.get_module_term(value, fallback)

static func _append_unique_chip(chips: Array, chip: Dictionary) -> void:
	var source_key := str(chip.get("source_key", "")).strip_edges()
	for existing in chips:
		if str(existing.get("source_key", "")) == source_key:
			return
	for index in range(chips.size()):
		var other := chips[index] as Dictionary
		var chip_weight := int(chip.get("sort_weight", 900))
		var other_weight := int(other.get("sort_weight", 900))
		if chip_weight < other_weight:
			chips.insert(index, chip)
			return
	chips.append(chip)
