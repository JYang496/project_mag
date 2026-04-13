extends Node

signal language_changed(new_locale: String)

const SETTINGS_PATH := "user://localization_settings.cfg"
const SETTINGS_SECTION := "localization"
const SETTINGS_KEY_LOCALE := "locale"
const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "zh_CN"]

var _current_locale: String = DEFAULT_LOCALE
var _weapon_scene_to_id: Dictionary = {}

func _ready() -> void:
	_rebuild_content_lookup()
	var saved_locale := _load_saved_locale()
	if saved_locale == "":
		saved_locale = _resolve_system_locale()
	set_locale(saved_locale, false)

func available_locales() -> PackedStringArray:
	return SUPPORTED_LOCALES.duplicate()

func get_locale() -> String:
	return _current_locale

func set_locale(locale: String, save_setting: bool = true) -> void:
	var normalized := _normalize_locale(locale)
	var changed := normalized != _current_locale or TranslationServer.get_locale() != normalized
	_current_locale = normalized
	TranslationServer.set_locale(_current_locale)
	if save_setting:
		_save_locale(_current_locale)
	if changed:
		language_changed.emit(_current_locale)

func locale_display_name(locale: String) -> String:
	var normalized := _normalize_locale(locale)
	match normalized:
		"zh_CN":
			return tr_key("ui.language.zh_cn", "简体中文")
		_:
			return tr_key("ui.language.en", "English")

func tr_key(key: String, fallback: String = "") -> String:
	var translated: String = str(TranslationServer.translate(key))
	if translated == "" or translated == key:
		return fallback if fallback != "" else key
	return translated

func tr_format(key: String, params: Dictionary = {}, fallback: String = "") -> String:
	var output := tr_key(key, fallback)
	for key_variant in params.keys():
		var slot := "{%s}" % str(key_variant)
		output = output.replace(slot, str(params[key_variant]))
	return output

func get_weapon_name_by_id(weapon_id: String, fallback: String = "") -> String:
	return tr_key("weapon.%s.name" % weapon_id, fallback)

func get_weapon_description_by_id(weapon_id: String, fallback: String = "") -> String:
	return tr_key("weapon.%s.desc" % weapon_id, fallback)

func get_weapon_name_from_definition(weapon_def: WeaponDefinition) -> String:
	if weapon_def == null:
		return ""
	return get_weapon_name_by_id(str(weapon_def.weapon_id), str(weapon_def.display_name))

func get_weapon_description_from_definition(weapon_def: WeaponDefinition) -> String:
	if weapon_def == null:
		return ""
	return get_weapon_description_by_id(str(weapon_def.weapon_id), str(weapon_def.description))

func get_weapon_name_from_node(weapon: Weapon) -> String:
	if weapon == null:
		return ""
	var fallback_name := ""
	var item_name: Variant = weapon.get("ITEM_NAME")
	if item_name != null and str(item_name) != "":
		fallback_name = str(item_name)
	elif weapon.name != "":
		fallback_name = weapon.name
	var scene_path := str(weapon.scene_file_path)
	var weapon_id := str(_weapon_scene_to_id.get(scene_path, ""))
	if weapon_id == "":
		return fallback_name
	return get_weapon_name_by_id(weapon_id, fallback_name)

func get_branch_display_name(branch_def: WeaponBranchDefinition) -> String:
	if branch_def == null:
		return ""
	return tr_key("branch.%s.name" % branch_def.branch_id, str(branch_def.display_name))

func get_branch_description(branch_def: WeaponBranchDefinition) -> String:
	if branch_def == null:
		return ""
	return tr_key("branch.%s.desc" % branch_def.branch_id, str(branch_def.description))

func get_module_id_from_instance(module_instance: Module) -> String:
	if module_instance == null:
		return ""
	var scene_path := str(module_instance.scene_file_path)
	if scene_path != "":
		return scene_path.get_file().get_basename()
	var script_variant: Variant = module_instance.get_script()
	if script_variant is Script:
		var script_path := str((script_variant as Script).resource_path)
		if script_path != "":
			return script_path.get_file().get_basename()
	return ""

func get_module_name(module_instance: Module) -> String:
	if module_instance == null:
		return ""
	var fallback := module_instance.get_module_display_name()
	var module_id := get_module_id_from_instance(module_instance)
	if module_id == "":
		return fallback
	return tr_key("module.%s.name" % module_id, fallback)

func get_route_display_name(route_def: RunRouteDefinition) -> String:
	if route_def == null:
		return ""
	return tr_key("route.%s.name" % route_def.route_id, str(route_def.display_name))

func get_route_description(route_def: RunRouteDefinition) -> String:
	if route_def == null:
		return ""
	return tr_key("route.%s.desc" % route_def.route_id, str(route_def.description))

func get_mecha_display_name(mecha_def: MechaDefinition) -> String:
	if mecha_def == null:
		return ""
	return tr_key("mecha.%s.name" % str(mecha_def.mecha_id), str(mecha_def.display_name))

func localize_module_reason(reason: String) -> String:
	var normalized := reason.strip_edges()
	if normalized == "":
		return normalized
	var exact_map := {
		"Invalid module.": "ui.module.reason.invalid_module",
		"Invalid weapon.": "ui.module.reason.invalid_weapon",
		"Weapon has no module container.": "ui.module.reason.no_container",
		"No module slots available.": "ui.module.reason.no_slots",
		"Module is not equipped.": "ui.module.reason.not_equipped",
		"Not compatible with melee weapons.": "ui.module.reason.not_melee",
		"Not compatible with ranged weapons.": "ui.module.reason.not_ranged",
		"Weapon does not match required traits.": "ui.module.reason.trait_required",
	}
	if exact_map.has(normalized):
		return tr_key(str(exact_map[normalized]), normalized)
	var prefix := "Requires one of: "
	if normalized.begins_with(prefix):
		var tail := normalized.trim_prefix(prefix)
		return tr_format("ui.module.reason.requires_one_of", {"traits": tail}, normalized)
	return normalized

func _normalize_locale(locale: String) -> String:
	var normalized := locale.strip_edges()
	if normalized == "":
		return DEFAULT_LOCALE
	if normalized.begins_with("zh"):
		return "zh_CN"
	return "en"

func _resolve_system_locale() -> String:
	return _normalize_locale(OS.get_locale())

func _load_saved_locale() -> String:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return ""
	return _normalize_locale(str(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY_LOCALE, "")))

func _save_locale(locale: String) -> void:
	var cfg := ConfigFile.new()
	var _err := cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY_LOCALE, _normalize_locale(locale))
	cfg.save(SETTINGS_PATH)

func _rebuild_content_lookup() -> void:
	_weapon_scene_to_id.clear()
	if GlobalVariables.weapon_list.is_empty():
		DataHandler.load_weapon_data()
	for key_variant in GlobalVariables.weapon_list.keys():
		var weapon_id := str(key_variant)
		var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if weapon_def == null or weapon_def.scene == null:
			continue
		var scene_path := str(weapon_def.scene.resource_path)
		if scene_path == "":
			continue
		_weapon_scene_to_id[scene_path] = weapon_id
