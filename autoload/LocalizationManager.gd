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

func get_weapon_instance_display_name(weapon: Weapon) -> String:
	var base_name := get_weapon_name_from_node(weapon)
	if weapon == null or not is_instance_valid(weapon):
		return base_name
	var runtime: WeaponBranchRuntime = weapon.branch_runtime
	if runtime == null:
		return base_name
	var selected_ids: Array[String] = runtime.branch_ids
	if selected_ids.is_empty():
		return base_name
	var branch_names := PackedStringArray()
	for branch_id_variant in selected_ids:
		var branch_id := str(branch_id_variant).strip_edges()
		if branch_id == "":
			continue
		var branch_def := DataHandler.read_weapon_branch_definition(weapon.scene_file_path, branch_id)
		branch_names.append(get_branch_display_name(branch_def) if branch_def != null else branch_id)
	if branch_names.is_empty():
		return base_name
	return tr_format(
		"ui.weapon.name_with_branches",
		{"weapon": base_name, "branches": " / ".join(branch_names)},
		"%s · %s" % [base_name, " / ".join(branch_names)]
	)

func get_branch_display_name(branch_def: WeaponBranchDefinition) -> String:
	if branch_def == null:
		return ""
	return tr_key("branch.%s.name" % branch_def.branch_id, str(branch_def.display_name))

func get_branch_description(branch_def: WeaponBranchDefinition) -> String:
	if branch_def == null:
		return ""
	return tr_key("branch.%s.desc" % branch_def.branch_id, str(branch_def.description))


func get_weapon_passive_display_name(passive_def: WeaponPassiveBranchDefinition) -> String:
	if passive_def == null:
		return ""
	return tr_key("passive.%s.name" % passive_def.passive_id, str(passive_def.display_name))


func get_weapon_passive_description(passive_def: WeaponPassiveBranchDefinition) -> String:
	if passive_def == null:
		return ""
	return tr_key("passive.%s.desc" % passive_def.passive_id, str(passive_def.description))


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

func get_module_effect_description(
	module_instance: Module,
	level: int,
	fallback: String = ""
) -> String:
	var module_id := get_module_id_from_instance(module_instance)
	if module_id == "":
		return fallback
	return tr_key("module.%s.effect.%d" % [module_id, clampi(level, 1, Module.MAX_LEVEL)], fallback)

func get_module_detail(
	module_instance: Module,
	detail_id: String,
	params: Dictionary = {},
	fallback: String = ""
) -> String:
	var module_id := get_module_id_from_instance(module_instance)
	if module_id == "":
		return fallback
	return tr_format("module.%s.%s" % [module_id, detail_id], params, fallback)

func get_module_term(term: StringName, fallback: String = "") -> String:
	var normalized := str(term).strip_edges().to_lower()
	if normalized == "":
		return fallback
	return tr_key("ui.module.term.%s" % normalized, fallback)

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
		"Modules can only be managed in the Rest Area.": "ui.module.reason.rest_area_only",
		"Only one module of each type can be owned.": "ui.module.reason.unique",
		"Not compatible with melee weapons.": "ui.module.reason.not_melee",
		"Not compatible with ranged weapons.": "ui.module.reason.not_ranged",
		"Weapon does not match required traits.": "ui.module.reason.trait_required",
		"Requires an ammo-based weapon.": "ui.module.reason.ammo_required",
		"Requires a weapon with shared multi-projectile firing.": "ui.module.reason.multi_projectile_required",
	}
	if exact_map.has(normalized):
		return tr_key(str(exact_map[normalized]), normalized)
	var dynamic_prefixes := {
		"Requires one of: ": "ui.module.reason.requires_one_of",
		"Requires delivery type: ": "ui.module.reason.requires_delivery",
		"Requires one of capabilities: ": "ui.module.reason.requires_capability",
		"Requires weapon property: ": "ui.module.reason.requires_property",
	}
	for prefix_variant in dynamic_prefixes.keys():
		var prefix := str(prefix_variant)
		if normalized.begins_with(prefix):
			var localized_terms := PackedStringArray()
			for raw_term in normalized.trim_prefix(prefix).split(",", false):
				var term := raw_term.strip_edges()
				localized_terms.append(get_module_term(StringName(term), term))
			return tr_format(
				str(dynamic_prefixes[prefix_variant]),
				{"requirements": ", ".join(localized_terms)},
				normalized
			)
	return normalized

func localize_cell_management_reason(reason: String) -> String:
	var normalized := reason.strip_edges()
	var exact_map := {
		"Missing cell effect.": "ui.management.reason.missing_cell_effect",
		"Not enough available cell effects.": "ui.management.reason.not_enough_cell_effects",
		"Invalid cell.": "ui.management.reason.invalid_cell",
		"No available copies.": "ui.management.reason.no_available_copies",
		"Same cell.": "ui.management.reason.same_cell",
		"Finish or cancel pending edits on these cells first.": "ui.management.reason.pending_edits",
		"Source cell has no installed effect.": "ui.management.reason.source_empty",
		"Source effect is missing.": "ui.management.reason.source_effect_missing",
		"This effect cannot be swapped.": "ui.management.reason.effect_not_swappable",
		"Target effect is missing.": "ui.management.reason.target_effect_missing",
		"Target effect cannot be swapped.": "ui.management.reason.target_not_swappable",
		"Missing task module.": "ui.management.reason.missing_task_module",
		"Invalid task module slot.": "ui.management.reason.invalid_task_slot",
		"Task modules can only be deployed during prepare.": "ui.management.reason.prepare_only",
		"Cell already has a deployed task.": "ui.management.reason.cell_has_task",
		"Maximum deployed tasks reached.": "ui.management.reason.task_limit",
		"Task modules can only target active cells.": "ui.management.reason.active_cells_only",
		"No deployed task on this cell.": "ui.management.reason.no_deployed_task",
		"Deployed task modules cannot be removed.": "ui.management.reason.cannot_remove_deployed",
		"Drop this task module on an active cell.": "ui.management.reason.drop_on_active_cell",
	}
	if exact_map.has(normalized):
		return tr_key(str(exact_map[normalized]), normalized)
	if normalized.begins_with("Not enough ") and normalized.ends_with(" cell effects."):
		var rarity := normalized.trim_prefix("Not enough ").trim_suffix(" cell effects.")
		return tr_format(
			"ui.management.reason.not_enough_rarity",
			{"rarity": get_rarity_name(rarity)},
			normalized
		)
	return normalized

func get_rarity_name(rarity: String) -> String:
	var normalized := rarity.strip_edges().to_lower()
	return tr_key("ui.rarity.%s" % normalized, rarity.capitalize())

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
		if weapon_def == null:
			continue
		var scene_path := weapon_def.scene_path
		if scene_path == "":
			continue
		_weapon_scene_to_id[scene_path] = weapon_id
