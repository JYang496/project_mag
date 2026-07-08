extends RefCounted
class_name WeaponObtainPreviewFormatter

static func format_obtain_preview(base_text: String, weapon_name: String, outcome: Dictionary) -> String:
	var result_type := str(outcome.get("result", "not_applicable"))
	match result_type:
		"fused":
			var from_fuse := int(outcome.get("from_fuse", 1))
			var target_fuse := int(outcome.get("target_fuse", 1))
			if bool(outcome.get("has_branch_options", false)):
				return LocalizationManager.tr_format(
					"ui.weapon.obtain_preview.fuse_branch",
					{"name": weapon_name, "from": from_fuse, "to": target_fuse},
					"%s: Fuse %d -> %d; choose a branch next if one is available" % [weapon_name, from_fuse, target_fuse]
				)
			return LocalizationManager.tr_format(
				"ui.weapon.obtain_preview.fuse_no_branch",
				{"name": weapon_name, "from": from_fuse, "to": target_fuse},
				"%s: Fuse %d -> %d; choose a branch next if one is available" % [weapon_name, from_fuse, target_fuse]
			)
		"converted_to_gold":
			return LocalizationManager.tr_format(
				"ui.weapon.obtain_preview.gold_action",
				{"name": weapon_name, "gold": int(outcome.get("gold", 0))},
				"%s: Fuse maxed; convert to +%d Gold" % [weapon_name, int(outcome.get("gold", 0))]
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
