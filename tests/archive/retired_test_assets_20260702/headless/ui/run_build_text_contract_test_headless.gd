extends SceneTree

const WEAPON_DIR := "res://data/weapons/"
const BRANCH_DIR := "res://data/weapon_branches/"
const PASSIVE_DIR := "res://data/weapon_passives/"
const MODULE_DIR := "res://Player/Weapons/Modules/"
const BUILD_TAGS := [
	"Heat", "Mark", "Freeze", "Reload", "Close", "Area", "Beam", "Projectile", "Melee",
	"On Hit", "Execute", "Defense", "Economy"
]

func _init() -> void:
	var ok := _run()
	quit(0 if ok else 1)

func _run() -> bool:
	if not _assert_resource_directory_texts(WEAPON_DIR, true, true):
		return false
	if not _assert_resource_directory_texts(BRANCH_DIR, true, false):
		return false
	if not _assert_resource_directory_texts(PASSIVE_DIR, false, false):
		return false
	if not _assert_module_text_contracts():
		return false
	print("BuildTextContractTest: PASS")
	return true

func _assert_resource_directory_texts(directory_path: String, require_build_tag: bool, require_title_case_name: bool) -> bool:
	for file_name in DirAccess.get_files_at(directory_path):
		if not file_name.ends_with(".tres"):
			continue
		var path := "%s%s" % [directory_path, file_name]
		var text := FileAccess.get_file_as_string(path)
		var display_name := _extract_assignment(text, "display_name")
		var description := _extract_assignment(text, "description")
		if not _assert_readable_text("%s display_name" % path, display_name, true):
			return false
		if not _assert_readable_text("%s description" % path, description, true):
			return false
		if require_title_case_name and display_name.length() > 0 and display_name[0] != display_name[0].to_upper():
			return _fail("%s display_name is not title-cased: %s" % [path, display_name])
		if require_build_tag and not _contains_any(description, BUILD_TAGS):
			return _fail("%s description has no canonical build tag." % path)
		if directory_path == BRANCH_DIR and not _contains_any(description, ["branch", "Branch"]):
			return _fail("%s description does not identify branch role." % path)
		if directory_path == PASSIVE_DIR:
			if not _contains_any(description, ["trigger", "Trigger", "setup", "spend", "spends"]):
				return _fail("%s description does not state trigger/setup." % path)
			if not _contains_any(description, ["reload", "Reload", "recharge", "refresh"]):
				return _fail("%s description does not state refresh/recharge." % path)
	return true

func _assert_module_text_contracts() -> bool:
	for file_name in DirAccess.get_files_at(MODULE_DIR):
		if not file_name.ends_with(".tscn") or file_name == "wmod_base.tscn":
			continue
		var scene_path := "%s%s" % [MODULE_DIR, file_name]
		var scene_text := FileAccess.get_file_as_string(scene_path)
		if not _contains_any(scene_text, ["level_effects", "stat_multipliers", "stat_additives"]):
			return _fail("%s has no readable effect field." % scene_path)
		if not scene_text.contains("module_tags") \
				and not scene_text.contains("required_weapon_traits") \
				and not scene_text.contains("required_delivery_types") \
				and not scene_text.contains("required_hooks") \
				and not scene_text.contains("required_weapon_capabilities"):
			return _fail("%s has no readable tag, target, or trigger field." % scene_path)
		var script_path := _extract_ext_script_path(scene_text)
		if script_path == "":
			return _fail("%s has no script path." % scene_path)
		var item_name := _extract_assignment(scene_text, "item_name")
		if item_name == "":
			var script_text := FileAccess.get_file_as_string(script_path)
			item_name = _extract_var_assignment(script_text, "ITEM_NAME")
			if item_name == "":
				item_name = _extract_var_assignment(script_text, "item_name")
		if not _assert_readable_text("%s item name" % scene_path, item_name, true):
			return false
	return true

func _extract_assignment(text: String, key: String) -> String:
	var prefix := "%s = \"" % key
	for line in text.split("\n"):
		if not str(line).begins_with(prefix):
			continue
		return _extract_quoted_value(str(line))
	return ""

func _extract_var_assignment(text: String, key: String) -> String:
	var needle := key
	for line_variant in text.split("\n"):
		var line := str(line_variant).strip_edges()
		if not line.contains(needle) or not line.contains("="):
			continue
		return _extract_quoted_value(line)
	return ""

func _extract_ext_script_path(scene_text: String) -> String:
	for line_variant in scene_text.split("\n"):
		var line := str(line_variant)
		if line.contains("type=\"Script\"") and line.contains("path=\""):
			var marker := "path=\""
			var start := line.find(marker)
			if start < 0:
				continue
			start += marker.length()
			var end := line.find("\"", start)
			if end > start:
				return line.substr(start, end - start)
	return ""

func _extract_quoted_value(line: String) -> String:
	var start := line.find("\"")
	if start < 0:
		return ""
	var end := line.rfind("\"")
	if end <= start:
		return ""
	return line.substr(start + 1, end - start - 1).strip_edges()

func _assert_readable_text(label: String, value: String, reject_test_placeholder: bool) -> bool:
	var normalized := value.strip_edges()
	if normalized == "":
		return _fail("%s is empty." % label)
	if reject_test_placeholder and normalized.to_lower().contains("test"):
		return _fail("%s still contains test placeholder text: %s" % [label, normalized])
	return true

func _contains_any(value: String, needles: Array) -> bool:
	for needle in needles:
		if value.contains(str(needle)):
			return true
	return false

func _fail(message: String) -> bool:
	push_error("BuildTextContractTest: %s" % message)
	return false
