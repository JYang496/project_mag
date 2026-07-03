extends RefCounted
class_name ModuleFitFormatter

const STATUS_FITS: StringName = &"fits"
const STATUS_BLOCKED: StringName = &"blocked"
const STATUS_UNKNOWN: StringName = &"unknown"
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")

static func build_display_data(module_instance: Module, target_weapon: Weapon = null) -> Dictionary:
	var data := {
		"effect_chips": [],
		"fit_badge": BUILD_TAG_DISPLAY.build_fit_status_badge(STATUS_UNKNOWN, "No current weapon"),
		"fit_status": STATUS_UNKNOWN,
		"fit_label": "No current weapon",
		"fit_warnings": PackedStringArray(),
		"detail_lines": PackedStringArray(),
	}
	if module_instance == null or not is_instance_valid(module_instance):
		data["fit_label"] = "Invalid module"
		data["fit_badge"] = BUILD_TAG_DISPLAY.build_fit_status_badge(STATUS_UNKNOWN, "Invalid module")
		return data
	var effect_chips := build_effect_chips(module_instance)
	data["effect_chips"] = effect_chips
	if target_weapon == null or not is_instance_valid(target_weapon):
		data["detail_lines"] = PackedStringArray(["Fit: No current weapon"])
		return data
	var reason := ""
	if module_instance.has_method("get_incompatibility_reason"):
		reason = str(module_instance.get_incompatibility_reason(target_weapon)).strip_edges()
	if reason == "":
		data["fit_status"] = STATUS_FITS
		data["fit_label"] = "Fits current"
		data["fit_badge"] = BUILD_TAG_DISPLAY.build_fit_status_badge(STATUS_FITS, "Fits")
		data["detail_lines"] = PackedStringArray(["Fit: Current weapon satisfies module requirements"])
	else:
		var warnings := PackedStringArray([reason])
		data["fit_status"] = STATUS_BLOCKED
		data["fit_label"] = "Not compatible"
		data["fit_badge"] = BUILD_TAG_DISPLAY.build_fit_status_badge(STATUS_BLOCKED, "Blocked")
		data["fit_warnings"] = warnings
		data["detail_lines"] = PackedStringArray(["Fit: Current weapon does not satisfy module requirements", "Warning: %s" % reason])
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
		_append_unique_chip(chips, BUILD_TAG_DISPLAY.build_tag_chip(&"buff", "Buff"))
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
	return not (
		text.begins_with("Build Tags:")
		or text.begins_with("Effect Tags:")
		or text.begins_with("Best On:")
		or text.begins_with("Triggers:")
	)

static func _append_stat_chips(chips: Array, module_instance: Module) -> void:
	for key_variant in module_instance.stat_multipliers.keys():
		_append_unique_chip(chips, BUILD_TAG_DISPLAY.build_tag_chip(str(key_variant), _format_stat_key_label(str(key_variant))))
	for key_variant in module_instance.stat_additives.keys():
		_append_unique_chip(chips, BUILD_TAG_DISPLAY.build_tag_chip(str(key_variant), _format_stat_key_label(str(key_variant))))
	if chips.is_empty() and not module_instance.level_effects.is_empty():
		_append_unique_chip(chips, BUILD_TAG_DISPLAY.build_tag_chip(&"buff", "Buff"))

static func _format_stat_key_label(stat_key: String) -> String:
	var normalized := stat_key.strip_edges().to_lower()
	if normalized.contains("damage"):
		return "Damage"
	if normalized.contains("reload"):
		return "Reload"
	if normalized.contains("heat"):
		return "Heat"
	if normalized.contains("ammo") or normalized.contains("magazine"):
		return "Ammo"
	if normalized.contains("size") or normalized.contains("speed") or normalized.contains("bullet"):
		return "Projectile"
	if normalized.contains("crit"):
		return "Crit"
	if normalized.contains("shield") or normalized.contains("armor") or normalized.contains("hp"):
		return "Defense"
	if normalized.contains("radius") or normalized.contains("area") or normalized.contains("angle"):
		return "Area"
	return stat_key.replace("_", " ").capitalize()

static func _format_hook_tag(hook: StringName) -> String:
	if hook == ModuleHook.HIT \
			or hook == ModuleHook.DAMAGE_DEALT \
			or hook == ModuleHook.AREA_DAMAGE \
			or hook == ModuleHook.BEAM_HIT:
		return "On Hit"
	if hook == ModuleHook.RELOAD_START or hook == ModuleHook.RELOAD_DURATION:
		return "Reload"
	if hook == ModuleHook.KILL:
		return "Execute"
	if hook == ModuleHook.PROJECTILE_SPAWN:
		return "Projectile"
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
	match StringName(str(value)):
		&"heat":
			return "Heat"
		&"mark":
			return "Mark"
		&"freeze":
			return "Freeze"
		&"reload":
			return "Reload"
		&"close":
			return "Close"
		&"area":
			return "Area"
		&"beam":
			return "Beam"
		&"projectile":
			return "Projectile"
		&"melee_contact":
			return "Melee"
		&"on_hit":
			return "On Hit"
		&"execute":
			return "Execute"
		&"defense":
			return "Defense"
		&"economy":
			return "Economy"
		&"physical":
			return "Physical"
		&"energy":
			return "Energy"
		&"fire":
			return "Fire"
		&"charge":
			return "Charge"
		&"summon":
			return "Summon"
		&"trap":
			return "Trap"
		&"support":
			return "Support"
		&"movement":
			return "Movement"
		&"buff":
			return "Buff"
		&"debuff":
			return "Debuff"
		&"dot":
			return "DoT"
		&"duration":
			return "Duration"
		&"stacking":
			return "Stacking"
		&"trigger":
			return "Trigger"
		_:
			return str(value).replace("_", " ").capitalize()

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
