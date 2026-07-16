extends Node

const RESOURCE_CATALOG := preload("res://autoload/ResourceCatalog.gd")
var save_data : SaveData
var _weapon_id_by_scene_path: Dictionary = {}
const WEAPON_DIRECTORY_PATH := "res://data/weapons/"
const MECHA_DIRECTORY_PATH := "res://data/mechas/"
const ECONOMY_DIRECTORY_PATH := "res://data/economy/"
const WEAPON_BRANCH_DIRECTORY_PATH := "res://data/weapon_branches/"
const WEAPON_PASSIVE_BRANCH_DIRECTORY_PATH := "res://data/weapon_passives/"
const WEAPON_BRANCH_ID_ALIASES := {
	"twin_mg": "gatling_mg",
	"gatling_mg": "gatling_mg",
}
var _weapon_prepare_result: Dictionary = {"ok": false, "errors": PackedStringArray(), "count": 0}
var _mecha_prepare_result: Dictionary = {"ok": false, "errors": PackedStringArray(), "count": 0}
var _economy_prepare_result: Dictionary = {"ok": false, "errors": PackedStringArray(), "count": 0}
var _weapon_branch_prepare_result: Dictionary = {"ok": false, "errors": PackedStringArray(), "count": 0}
var _weapon_passive_branch_prepare_result: Dictionary = {"ok": false, "errors": PackedStringArray(), "count": 0}

func _ready():
	load_game()

func prepare_world_data(include_deferred_runtime_data: bool = false) -> Dictionary:
	var errors := PackedStringArray()
	if GlobalVariables.weapon_list.is_empty():
		_collect_prepare_errors(prepare_weapon_data(), errors)
	if GlobalVariables.mecha_list.is_empty():
		_collect_prepare_errors(prepare_mecha_data(), errors)
	if GlobalVariables.economy_data == null:
		_collect_prepare_errors(prepare_economy_data(), errors)
	if include_deferred_runtime_data:
		_collect_prepare_errors(prepare_deferred_runtime_data(), errors)
	return _build_prepare_result(errors.is_empty(), errors, 0)

func prepare_deferred_runtime_data() -> Dictionary:
	var errors := PackedStringArray()
	if GlobalVariables.weapon_branch_list.is_empty():
		_collect_prepare_errors(prepare_weapon_branch_data(), errors)
	if GlobalVariables.weapon_passive_branch_list.is_empty():
		_collect_prepare_errors(prepare_weapon_passive_branch_data(), errors)
	return _build_prepare_result(errors.is_empty(), errors, 0)

# This function is used for locate weapon file location which stored in data/weapons.
func load_weapon_data() -> Dictionary:
	return prepare_weapon_data(true)

func prepare_weapon_data(force: bool = false) -> Dictionary:
	if not force and bool(_weapon_prepare_result.get("ok", false)) and not GlobalVariables.weapon_list.is_empty():
		return _weapon_prepare_result.duplicate(true)
	var catalog_result: Dictionary = RESOURCE_CATALOG.collect_startup_catalog_paths(
		"weapons",
		WEAPON_DIRECTORY_PATH,
		".tres"
	)
	var errors := PackedStringArray()
	if not bool(catalog_result.get("ok", false)):
		errors.append_array(catalog_result.get("errors", PackedStringArray()))
	var loaded_weapons := {}
	var loaded_scene_ids := {}
	for path in catalog_result.get("paths", PackedStringArray()):
		_register_weapon_resource(load(str(path)), str(path), loaded_weapons, loaded_scene_ids, errors)
	if loaded_weapons.is_empty():
		errors.append("no weapon data loaded")
	if not errors.is_empty():
		_weapon_prepare_result = _build_prepare_result(false, errors, 0)
		push_error("DataHandler: failed to prepare weapons: %s" % "; ".join(errors))
		return _weapon_prepare_result.duplicate(true)
	GlobalVariables.weapon_list = loaded_weapons
	_weapon_id_by_scene_path = loaded_scene_ids
	_weapon_prepare_result = _build_prepare_result(true, errors, GlobalVariables.weapon_list.size())
	return _weapon_prepare_result.duplicate(true)

func load_mecha_data() -> Dictionary:
	return prepare_mecha_data(true)

func prepare_mecha_data(force: bool = false) -> Dictionary:
	if not force and bool(_mecha_prepare_result.get("ok", false)) and not GlobalVariables.mecha_list.is_empty():
		return _mecha_prepare_result.duplicate(true)
	var catalog_result: Dictionary = RESOURCE_CATALOG.collect_startup_catalog_paths(
		"mechas",
		MECHA_DIRECTORY_PATH,
		".tres"
	)
	var errors := PackedStringArray()
	if not bool(catalog_result.get("ok", false)):
		errors.append_array(catalog_result.get("errors", PackedStringArray()))
	var loaded_mechas := {}
	for path in catalog_result.get("paths", PackedStringArray()):
		_register_mecha_resource(load(str(path)), str(path), loaded_mechas, errors)
	if loaded_mechas.is_empty():
		errors.append("no mecha data loaded")
	if not errors.is_empty():
		_mecha_prepare_result = _build_prepare_result(false, errors, 0)
		push_error("DataHandler: failed to prepare mechas: %s" % "; ".join(errors))
		return _mecha_prepare_result.duplicate(true)
	GlobalVariables.mecha_list = loaded_mechas
	_mecha_prepare_result = _build_prepare_result(true, errors, GlobalVariables.mecha_list.size())
	return _mecha_prepare_result.duplicate(true)

func load_weapon_branch_data() -> Dictionary:
	return prepare_weapon_branch_data(true)

func prepare_weapon_branch_data(force: bool = false) -> Dictionary:
	if not force and bool(_weapon_branch_prepare_result.get("ok", false)) and not GlobalVariables.weapon_branch_list.is_empty():
		return _weapon_branch_prepare_result.duplicate(true)
	var catalog_result: Dictionary = RESOURCE_CATALOG.collect_startup_catalog_paths(
		"weapon_branches",
		WEAPON_BRANCH_DIRECTORY_PATH,
		".tres"
	)
	var errors := PackedStringArray()
	if not bool(catalog_result.get("ok", false)):
		errors.append_array(catalog_result.get("errors", PackedStringArray()))
	var loaded_branches := {}
	var seen_branch_ids := {}
	for path in catalog_result.get("paths", PackedStringArray()):
		_register_weapon_branch_resource(load(str(path)), str(path), loaded_branches, seen_branch_ids, errors)
	if loaded_branches.is_empty():
		errors.append("no weapon branch data loaded")
	if not errors.is_empty():
		_weapon_branch_prepare_result = _build_prepare_result(false, errors, 0)
		push_error("DataHandler: failed to prepare weapon branches: %s" % "; ".join(errors))
		return _weapon_branch_prepare_result.duplicate(true)
	GlobalVariables.weapon_branch_list = loaded_branches
	_weapon_branch_prepare_result = _build_prepare_result(true, errors, seen_branch_ids.size())
	return _weapon_branch_prepare_result.duplicate(true)

func load_weapon_passive_branch_data() -> Dictionary:
	return prepare_weapon_passive_branch_data(true)

func prepare_weapon_passive_branch_data(force: bool = false) -> Dictionary:
	if not force and bool(_weapon_passive_branch_prepare_result.get("ok", false)) and not GlobalVariables.weapon_passive_branch_list.is_empty():
		return _weapon_passive_branch_prepare_result.duplicate(true)
	var catalog_result: Dictionary = RESOURCE_CATALOG.collect_startup_catalog_paths(
		"weapon_passives",
		WEAPON_PASSIVE_BRANCH_DIRECTORY_PATH,
		".tres"
	)
	var errors := PackedStringArray()
	if not bool(catalog_result.get("ok", false)):
		errors.append_array(catalog_result.get("errors", PackedStringArray()))
	var loaded_passives := {}
	for path in catalog_result.get("paths", PackedStringArray()):
		_register_weapon_passive_branch_resource(load(str(path)), str(path), loaded_passives, errors)
	if loaded_passives.is_empty():
		errors.append("no weapon passive branch data loaded")
	if not errors.is_empty():
		_weapon_passive_branch_prepare_result = _build_prepare_result(false, errors, 0)
		push_error("DataHandler: failed to prepare weapon passive branches: %s" % "; ".join(errors))
		return _weapon_passive_branch_prepare_result.duplicate(true)
	GlobalVariables.weapon_passive_branch_list = loaded_passives
	_weapon_passive_branch_prepare_result = _build_prepare_result(true, errors, GlobalVariables.weapon_passive_branch_list.size())
	return _weapon_passive_branch_prepare_result.duplicate(true)

func load_economy_data() -> Dictionary:
	return prepare_economy_data(true)

func prepare_economy_data(force: bool = false) -> Dictionary:
	if not force and bool(_economy_prepare_result.get("ok", false)) and GlobalVariables.economy_data != null:
		return _economy_prepare_result.duplicate(true)
	var catalog_result: Dictionary = RESOURCE_CATALOG.collect_startup_catalog_paths(
		"economy",
		ECONOMY_DIRECTORY_PATH,
		".tres"
	)
	var errors := PackedStringArray()
	if not bool(catalog_result.get("ok", false)):
		errors.append_array(catalog_result.get("errors", PackedStringArray()))
	var paths: PackedStringArray = catalog_result.get("paths", PackedStringArray())
	if paths.size() != 1:
		errors.append("economy catalog must contain exactly one resource; got %d" % paths.size())
	var economy: EconomyConfig = null
	if paths.size() >= 1:
		var resource := load(paths[0])
		if resource == null:
			errors.append("failed to load economy config: %s" % paths[0])
		else:
			economy = resource as EconomyConfig
	if economy == null:
		errors.append("economy config has invalid type")
	if not errors.is_empty():
		_economy_prepare_result = _build_prepare_result(false, errors, 0)
		push_error("DataHandler: failed to prepare economy: %s" % "; ".join(errors))
		return _economy_prepare_result.duplicate(true)
	GlobalVariables.economy_data = economy
	_economy_prepare_result = _build_prepare_result(true, errors, 1)
	return _economy_prepare_result.duplicate(true)

func get_world_prepare_results() -> Dictionary:
	return {
		"weapons": _weapon_prepare_result.duplicate(true),
		"mechas": _mecha_prepare_result.duplicate(true),
		"economy": _economy_prepare_result.duplicate(true),
		"weapon_branches": _weapon_branch_prepare_result.duplicate(true),
		"weapon_passives": _weapon_passive_branch_prepare_result.duplicate(true),
	}

func read_weapon_branch_options(scene_path: String, current_fuse: int = 1) -> Array[WeaponBranchDefinition]:
	if GlobalVariables.weapon_branch_list.is_empty():
		load_weapon_branch_data()
	if scene_path == "":
		return []
	var branch_list_variant: Variant = GlobalVariables.weapon_branch_list.get(scene_path, [])
	var branch_list: Array = branch_list_variant if branch_list_variant is Array else []
	var options: Array[WeaponBranchDefinition] = []
	for item in branch_list:
		var def := item as WeaponBranchDefinition
		if def == null:
			continue
		if current_fuse < int(def.unlock_fuse):
			continue
		options.append(def)
	return options

func read_weapon_branch_definition(scene_path: String, branch_id: String) -> WeaponBranchDefinition:
	if branch_id == "":
		return null
	var normalized_branch_id := _normalize_weapon_branch_id(branch_id)
	var options := read_weapon_branch_options(scene_path, 999)
	for def in options:
		if _normalize_weapon_branch_id(def.branch_id) == normalized_branch_id:
			return def
	return null

func read_weapon_passive_branch_definition(passive_id: String) -> Resource:
	if passive_id == "":
		return null
	if GlobalVariables.weapon_passive_branch_list.is_empty():
		load_weapon_passive_branch_data()
	var def_variant: Variant = GlobalVariables.weapon_passive_branch_list.get(str(passive_id), null)
	return def_variant as Resource

func _normalize_weapon_branch_id(branch_id: String) -> String:
	var normalized := str(branch_id).strip_edges()
	if normalized == "":
		return ""
	if WEAPON_BRANCH_ID_ALIASES.has(normalized):
		return str(WEAPON_BRANCH_ID_ALIASES[normalized])
	return normalized

func read_mecha_data(id: String) -> MechaDefinition:
	if GlobalVariables.mecha_list.is_empty():
		load_mecha_data()
	var data = GlobalVariables.mecha_list.get(id)
	if data == null:
		return null
	return data as MechaDefinition

func prewarm_mecha_default_weapon(id: String) -> bool:
	var mecha := read_mecha_data(id)
	if mecha == null or mecha.default_weapon_id.is_empty():
		return false
	var weapon := read_weapon_data(mecha.default_weapon_id) as WeaponDefinition
	if weapon == null or weapon.request_scene() != OK:
		return false
	# Prewarm means the default weapon must be fully loaded and cached before
	# callers begin another threaded scene graph load (not merely requested).
	return weapon.get_scene() != null

func read_weapon_data(id: String):
	if GlobalVariables.weapon_list.is_empty():
		load_weapon_data()
	var data = GlobalVariables.weapon_list.get(str(id))
	if data == null:
		return null
	return data

func get_weapon_id_from_scene_path(scene_path: String) -> String:
	var normalized_path := str(scene_path).strip_edges()
	if normalized_path == "":
		return ""
	if GlobalVariables.weapon_list.is_empty():
		load_weapon_data()
	if _weapon_id_by_scene_path.has(normalized_path):
		return str(_weapon_id_by_scene_path[normalized_path])
	return ""

func get_weapon_id_from_instance(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return ""
	return get_weapon_id_from_scene_path(str(weapon.scene_file_path))

func get_weapon_ids() -> Array[String]:
	if GlobalVariables.weapon_list.is_empty():
		load_weapon_data()
	var ids: Array[String] = []
	for key_variant in GlobalVariables.weapon_list.keys():
		var key := str(key_variant)
		var def := read_weapon_data(key) as WeaponDefinition
		if def == null:
			continue
		if bool(def.is_hidden):
			continue
		ids.append(key)
	return ids

func build_weapon_save_payload(weapon: Weapon) -> Dictionary:
	if weapon == null or not is_instance_valid(weapon):
		return {}
	var module_payloads: Array[Dictionary] = []
	if weapon.modules != null:
		for child in weapon.modules.get_children():
			var module_node := child as Module
			if module_node == null:
				continue
			module_payloads.append({
				"scene_path": str(module_node.scene_file_path),
				"level": int(module_node.module_level),
			})
	return {
		"weapon_id": get_weapon_id_from_instance(weapon),
		"level": int(weapon.level),
		"fuse": int(weapon.fuse),
		"branch_ids": weapon.branch_runtime.branch_ids.duplicate(),
		"modules": module_payloads,
	}

func instantiate_weapon_from_save_payload(payload: Dictionary) -> Weapon:
	var weapon_id := str(payload.get("weapon_id", "")).strip_edges()
	var weapon_def := read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null or weapon_def.scene == null:
		push_warning("Cannot restore saved weapon id=%s." % weapon_id)
		return null
	var weapon := weapon_def.scene.instantiate() as Weapon
	if weapon == null:
		push_warning("Cannot instantiate saved weapon id=%s." % weapon_id)
		return null
	weapon.fuse = clampi(int(payload.get("fuse", 1)), 1, int(weapon.FINAL_MAX_FUSE))
	weapon.level = int(payload.get("level", 1))
	return weapon

func restore_weapon_runtime_from_save_payload(weapon: Weapon, payload: Dictionary) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if weapon.has_method("refresh_max_level_from_data"):
		weapon.call("refresh_max_level_from_data")
	var saved_level := clampi(int(payload.get("level", 1)), 1, int(weapon.max_level))
	if weapon.has_method("set_level"):
		weapon.call("set_level", saved_level)
	else:
		weapon.level = saved_level
	var saved_branch_ids: Array = payload.get("branch_ids", [])
	weapon.branch_runtime.restore_branch_ids(saved_branch_ids)
	if payload.has("modules"):
		_restore_weapon_modules_from_payload(weapon, payload.get("modules", []))
	if weapon.has_method("calculate_status"):
		weapon.call("calculate_status")

func _restore_weapon_modules_from_payload(weapon: Weapon, module_payloads: Array) -> void:
	if weapon == null or weapon.modules == null:
		return
	for module_payload_variant in module_payloads:
		if not (module_payload_variant is Dictionary):
			continue
		var module_payload := module_payload_variant as Dictionary
		var scene_path := str(module_payload.get("scene_path", "")).strip_edges()
		if scene_path == "":
			continue
		var module_scene := load(scene_path) as PackedScene
		if module_scene == null:
			push_warning("Skipping missing saved module scene: %s" % scene_path)
			continue
		var module_instance := module_scene.instantiate() as Module
		if module_instance == null:
			push_warning("Skipping invalid saved module scene: %s" % scene_path)
			continue
		module_instance.set_module_level(int(module_payload.get("level", 1)))
		weapon.modules.add_child(module_instance)

func _register_weapon_resource(
	resource: Resource,
	source_path: String,
	output: Dictionary,
	scene_id_output: Dictionary,
	errors: PackedStringArray
) -> void:
	if resource == null:
		errors.append("failed to load weapon resource: %s" % source_path)
		return
	var weapon_id_value = resource.get("weapon_id")
	if weapon_id_value == null:
		errors.append("weapon resource missing weapon_id: %s" % source_path)
		return
	var weapon_id := str(weapon_id_value).strip_edges()
	if weapon_id == "":
		errors.append("weapon resource has empty weapon_id: %s" % source_path)
		return
	if output.has(weapon_id):
		errors.append("duplicate weapon_id '%s': %s" % [weapon_id, source_path])
		return
	output[weapon_id] = resource
	var scene_path := str(resource.get("scene_path")).strip_edges()
	if scene_path != "":
		if scene_id_output.has(scene_path):
			errors.append("duplicate weapon scene_path '%s': %s" % [scene_path, source_path])
			return
		scene_id_output[scene_path] = weapon_id

func _register_mecha_resource(
	resource: Resource,
	source_path: String,
	output: Dictionary,
	errors: PackedStringArray
) -> void:
	if resource == null:
		errors.append("failed to load mecha resource: %s" % source_path)
		return
	var mecha_id_value = resource.get("mecha_id")
	if mecha_id_value == null:
		errors.append("mecha resource missing mecha_id: %s" % source_path)
		return
	var mecha_id := str(mecha_id_value).strip_edges()
	if mecha_id == "":
		errors.append("mecha resource has empty mecha_id: %s" % source_path)
		return
	if output.has(mecha_id):
		errors.append("duplicate mecha_id '%s': %s" % [mecha_id, source_path])
		return
	output[mecha_id] = resource

func _register_weapon_branch_resource(
	resource: Resource,
	source_path: String,
	output: Dictionary,
	seen_branch_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	var branch_def := resource as WeaponBranchDefinition
	if branch_def == null:
		errors.append("failed to load weapon branch resource: %s" % source_path)
		return
	var branch_id := str(branch_def.branch_id).strip_edges()
	if branch_id == "":
		errors.append("weapon branch resource has empty branch_id: %s" % source_path)
		return
	var scene_path := branch_def.weapon_scene_path
	if scene_path == "":
		errors.append("weapon branch resource missing weapon_scene_path: %s" % source_path)
		return
	if seen_branch_ids.has(branch_id):
		errors.append("duplicate weapon branch_id '%s': %s" % [branch_id, source_path])
		return
	seen_branch_ids[branch_id] = source_path
	if not output.has(scene_path):
		output[scene_path] = []
	var branch_list: Array = output[scene_path]
	branch_list.append(branch_def)
	output[scene_path] = branch_list

func _register_weapon_passive_branch_resource(
	resource: Resource,
	source_path: String,
	output: Dictionary,
	errors: PackedStringArray
) -> void:
	if resource == null:
		errors.append("failed to load weapon passive resource: %s" % source_path)
		return
	var passive_id_value: Variant = resource.get("passive_id")
	if passive_id_value == null:
		errors.append("weapon passive resource missing passive_id: %s" % source_path)
		return
	var passive_id := str(passive_id_value).strip_edges()
	if passive_id == "":
		errors.append("weapon passive resource has empty passive_id: %s" % source_path)
		return
	if output.has(passive_id):
		errors.append("duplicate weapon passive_id '%s': %s" % [passive_id, source_path])
		return
	output[passive_id] = resource

func _collect_prepare_errors(result: Dictionary, errors: PackedStringArray) -> void:
	if bool(result.get("ok", false)):
		return
	for error in result.get("errors", PackedStringArray()):
		errors.append(str(error))

func _build_prepare_result(ok: bool, errors: PackedStringArray, count: int) -> Dictionary:
	return {
		"ok": ok,
		"errors": errors,
		"count": count,
	}

# Return mecha autosave data, will be called in Start menu.
func read_autosave_mecha_data(id : String) -> Dictionary:
	if save_data == null:
		load_game()
	var mecha_id := str(id)
	if save_data.mechas.has(mecha_id):
		return save_data.mechas[mecha_id]
	# Fallback prevents crashes when requesting an unknown mecha id.
	return {"current_exp": "0", "current_level": "1"}

func save_game(_data : SaveData = save_data, _file_path: String = "res://data/savedata/autosave.tres") -> void:
	InventoryData.save_runtime_state()
	CellEffectRuntime.save_runtime_state()
	RewardDraftRuntime.save_runtime_state()
	return

func new_save(_file_path: String = "res://data/savedata/autosave.tres") -> void:
	save_data = _create_fresh_runtime_save()
	RewardDraftRuntime.reset_runtime_state(false)
	BattleContractManager.reset_persistent_state()
	return
	

func load_game(_file_path: String = "res://data/savedata/autosave.tres") -> void:
	# Persistent save loading is disabled: always start from a fresh runtime state.
	save_data = _create_fresh_runtime_save()

func _create_fresh_runtime_save() -> SaveData:
	var runtime_save := SaveData.new()
	# Keep this explicit so the initial mecha selection is deterministic.
	runtime_save.last_mecha_selected = "1"
	return runtime_save
