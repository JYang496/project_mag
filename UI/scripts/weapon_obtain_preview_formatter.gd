extends RefCounted
class_name WeaponObtainPreviewFormatter

static func format_obtain_preview(base_text: String, weapon_name: String, outcome: Dictionary) -> String:
	var result_type := str(outcome.get("result", "not_applicable"))
	match result_type:
		"dismantled_to_core":
			return LocalizationManager.tr_format(
				"ui.weapon.obtain_preview.core_action",
				{"name": weapon_name, "tags": _format_tags(outcome.get("core_tags", [])), "count": int(outcome.get("current_core_count", 0))},
				"%s: dismantle into 1 core [%s] · owned %d" % [weapon_name, _format_tags(outcome.get("core_tags", [])), int(outcome.get("current_core_count", 0))]
			)
		_:
			if weapon_name.strip_edges() != "":
				if bool(outcome.get("will_equip_to_empty_slot", false)):
					return LocalizationManager.tr_format(
						"ui.weapon.obtain_preview.new_equip",
						{"name": weapon_name},
						"Obtain new %s; equips to an empty slot" % weapon_name
					)
				if bool(outcome.get("will_choose_replacement", false)):
					return LocalizationManager.tr_format(
						"ui.weapon.obtain_preview.new_replace",
						{"name": weapon_name},
						"Obtain new %s; choose replace or store next" % weapon_name
					)
				return LocalizationManager.tr_format(
					"ui.weapon.obtain_preview.new_named",
					{"name": weapon_name},
					"Obtain new %s" % weapon_name
				)
			return base_text

static func _format_tags(values: Variant) -> String:
	var parts := PackedStringArray()
	if values is Array:
		for value in values: parts.append(str(value))
	return ", ".join(parts)
