extends SceneTree

const BRANCH_DIR := "res://data/weapon_branches/"
func _init() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var branches_by_weapon: Dictionary = {}
	var dir := DirAccess.open(BRANCH_DIR)
	if dir == null:
		push_error("Missing branch directory: %s" % BRANCH_DIR)
		quit(1)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			_validate_branch_resource_text(BRANCH_DIR + file_name, branches_by_weapon, errors, warnings)
		file_name = dir.get_next()
	dir.list_dir_end()
	_validate_weapon_sort_orders(branches_by_weapon, warnings)
	for warning in warnings:
		print("WARNING: %s" % warning)
	for error in errors:
		push_error(error)
	if errors.is_empty():
		print("Weapon branch validation passed: %d weapon groups checked." % branches_by_weapon.size())
		quit(0)
	else:
		print("Weapon branch validation failed: %d error(s), %d warning(s)." % [errors.size(), warnings.size()])
		quit(1)

func _validate_branch_resource_text(path: String, branches_by_weapon: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s cannot be opened." % path)
		return
	var text := file.get_as_text()
	var branch_id := _extract_assigned_string(text, "branch_id")
	var weapon_scene_path := _extract_assigned_string(text, "weapon_scene_path")
	var behavior_scene_path := _extract_assigned_string(text, "behavior_scene_path")
	var sort_order := _extract_assigned_int(text, "sort_order", 0)
	if branch_id == "":
		errors.append("%s has empty branch_id." % path)
	if weapon_scene_path == "":
		errors.append("%s is missing weapon_scene_path." % path)
	if behavior_scene_path == "":
		errors.append("%s is missing behavior_scene_path." % path)
	if sort_order == 0:
		warnings.append("%s has sort_order 0; set an explicit UI/default order." % path)
	if weapon_scene_path != "":
		if not branches_by_weapon.has(weapon_scene_path):
			branches_by_weapon[weapon_scene_path] = []
		branches_by_weapon[weapon_scene_path].append({
			"branch_id": branch_id,
			"sort_order": sort_order,
		})
func _validate_weapon_sort_orders(branches_by_weapon: Dictionary, warnings: Array[String]) -> void:
	for weapon_path in branches_by_weapon.keys():
		var seen_orders: Dictionary = {}
		for branch_info in branches_by_weapon[weapon_path]:
			var sort_order := int(branch_info.get("sort_order", 0))
			if not seen_orders.has(sort_order):
				seen_orders[sort_order] = []
			seen_orders[sort_order].append(str(branch_info.get("branch_id", "")))
		for sort_order in seen_orders.keys():
			var ids: Array = seen_orders[sort_order]
			if ids.size() > 1:
				warnings.append(
					"%s has duplicate sort_order %d for branches: %s" %
					[weapon_path, int(sort_order), ", ".join(ids)]
				)

func _extract_assigned_string(text: String, property_name: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?m)^%s\\s*=\\s*\"([^\"]*)\"" % property_name)
	var match := regex.search(text)
	if match == null:
		return ""
	return match.get_string(1).strip_edges()

func _extract_assigned_int(text: String, property_name: String, fallback: int) -> int:
	var regex := RegEx.new()
	regex.compile("(?m)^%s\\s*=\\s*(-?\\d+)" % property_name)
	var match := regex.search(text)
	if match == null:
		return fallback
	return int(match.get_string(1))
