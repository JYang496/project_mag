extends RefCounted
class_name WeaponObtainPreviewFormatter

static func format_obtain_preview(base_text: String, weapon_name: String, outcome: Dictionary) -> String:
	var result_type := str(outcome.get("result", "not_applicable"))
	match result_type:
		"fused":
			var target_fuse := int(outcome.get("target_fuse", 1))
			if bool(outcome.get("has_branch_options", false)):
				return LocalizationManager.tr_format(
					"ui.weapon.obtain_preview.fuse_branch",
					{"name": weapon_name, "fuse": target_fuse},
					"%s: Break through to Fuse %d; choose a branch to continue" % [weapon_name, target_fuse]
				)
			return LocalizationManager.tr_format(
				"ui.weapon.obtain_preview.fuse_no_branch",
				{"name": weapon_name, "fuse": target_fuse},
				"%s: Break through to Fuse %d; no branch available" % [weapon_name, target_fuse]
			)
		"converted_to_gold":
			return LocalizationManager.tr_format(
				"ui.weapon.obtain_preview.gold_action",
				{"name": weapon_name, "gold": int(outcome.get("gold", 0))},
				"%s: Fuse maxed; convert to +%d Gold" % [weapon_name, int(outcome.get("gold", 0))]
			)
		_:
			if weapon_name.strip_edges() != "":
				return LocalizationManager.tr_format(
					"ui.weapon.obtain_preview.new_named",
					{"name": weapon_name},
					"Obtain new %s" % weapon_name
				)
			return base_text
