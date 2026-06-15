extends Node

var save_data : SaveData
const WEAPON_RESOURCE_PATHS := [
	"res://data/weapons/machine_gun.tres",
	"res://data/weapons/charged_blaster.tres",
	"res://data/weapons/Spear.tres",
	"res://data/weapons/shotgun.tres",
	"res://data/weapons/pistol.tres",
	"res://data/weapons/orbit.tres",
	"res://data/weapons/rocket_luncher.tres",
	"res://data/weapons/laser.tres",
	"res://data/weapons/chainsaw_luncher.tres",
	"res://data/weapons/dash_blade.tres",
	"res://data/weapons/flamethrower.tres",
	"res://data/weapons/plasma_lance.tres",
	"res://data/weapons/glacier_projector.tres",
	"res://data/weapons/cannon.tres",
]
const MECHA_RESOURCE_PATHS := [
	"res://data/mechas/HeavyAssault.tres",
	"res://data/mechas/Ranger.tres",
	"res://data/mechas/Melee.tres",
	"res://data/mechas/Collector.tres",
	"res://data/mechas/Turret.tres",
]
const WEAPON_BRANCH_RESOURCE_PATHS := [
	"res://data/weapon_branches/machine_gun_shield.tres",
]
const WEAPON_PASSIVE_BRANCH_RESOURCE_PATHS := []
const ECONOMY_RESOURCE_PATH := "res://data/economy/economy_config.tres"
const WEAPON_BRANCH_ID_ALIASES := {
	"twin_mg": "gatling_mg",
	"gatling_mg": "gatling_mg",
}

func _ready():
	load_game()

func prepare_world_data() -> void:
	if GlobalVariables.weapon_list.is_empty():
		load_weapon_data()
	if GlobalVariables.weapon_branch_list.is_empty():
		load_weapon_branch_data()
	if GlobalVariables.weapon_passive_branch_list.is_empty():
		load_weapon_passive_branch_data()
	if GlobalVariables.mecha_list.is_empty():
		load_mecha_data()
	if GlobalVariables.economy_data == null:
		load_economy_data()

# This function is used for locate weapon file location which stored in data/weapons.
func load_weapon_data():
	var dir := DirAccess.open("res://data/weapons/")
	GlobalVariables.weapon_list = {}
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				_register_weapon_resource(load("res://data/weapons/%s" % file_name), "res://data/weapons/%s" % file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	if GlobalVariables.weapon_list.is_empty():
		for path: String in WEAPON_RESOURCE_PATHS:
			_register_weapon_resource(load(path), path)
	if GlobalVariables.weapon_list.is_empty():
		push_warning("No weapon data loaded. Check exported resources and script paths in data/weapons/*.tres.")

func load_mecha_data():
	GlobalVariables.mecha_list = {}
	var dir := DirAccess.open("res://data/mechas/")
	if dir:
		dir.list_dir_begin()
		var mecha_name = dir.get_next()
		while mecha_name != "":
			if mecha_name.ends_with(".tres"):
				_register_mecha_resource(load("res://data/mechas/%s" % mecha_name), "res://data/mechas/%s" % mecha_name)
			mecha_name = dir.get_next()
		dir.list_dir_end()
	if GlobalVariables.mecha_list.is_empty():
		for path: String in MECHA_RESOURCE_PATHS:
			_register_mecha_resource(load(path), path)
	if GlobalVariables.mecha_list.is_empty():
		push_warning("No mecha data loaded. Check exported resources and script paths in data/mechas/*.tres.")

func load_weapon_branch_data() -> void:
	GlobalVariables.weapon_branch_list = {}
	var dir := DirAccess.open("res://data/weapon_branches/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				_register_weapon_branch_resource(load("res://data/weapon_branches/%s" % file_name), "res://data/weapon_branches/%s" % file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	if GlobalVariables.weapon_branch_list.is_empty():
		for path: String in WEAPON_BRANCH_RESOURCE_PATHS:
			_register_weapon_branch_resource(load(path), path)
	if GlobalVariables.weapon_branch_list.is_empty():
		push_warning("No weapon branch data loaded. Check resources in data/weapon_branches/*.tres.")

func load_weapon_passive_branch_data() -> void:
	GlobalVariables.weapon_passive_branch_list = {}
	var dir := DirAccess.open("res://data/weapon_passives/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				_register_weapon_passive_branch_resource(load("res://data/weapon_passives/%s" % file_name), "res://data/weapon_passives/%s" % file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	if GlobalVariables.weapon_passive_branch_list.is_empty():
		for path: String in WEAPON_PASSIVE_BRANCH_RESOURCE_PATHS:
			_register_weapon_passive_branch_resource(load(path), path)

func load_economy_data() -> void:
	GlobalVariables.economy_data = null
	var resource := load(ECONOMY_RESOURCE_PATH)
	if resource == null:
		push_warning("Failed to load economy config: %s" % ECONOMY_RESOURCE_PATH)
		return
	var economy := resource as EconomyConfig
	if economy == null:
		push_warning("Economy config has invalid type: %s" % ECONOMY_RESOURCE_PATH)
		return
	GlobalVariables.economy_data = economy

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
	for key_variant in GlobalVariables.weapon_list.keys():
		var weapon_id := str(key_variant)
		var weapon_def := read_weapon_data(weapon_id) as WeaponDefinition
		if weapon_def == null:
			continue
		if weapon_def.scene_path == normalized_path:
			return weapon_id
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
	return weapon

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

func _register_weapon_resource(resource: Resource, source_path: String) -> void:
	if resource == null:
		push_warning("Failed to load weapon resource: %s" % source_path)
		return
	var weapon_id_value = resource.get("weapon_id")
	if weapon_id_value == null:
		push_warning("Weapon resource missing weapon_id: %s" % source_path)
		return
	var weapon_id := str(weapon_id_value)
	if weapon_id == "":
		push_warning("Weapon resource has empty weapon_id: %s" % source_path)
		return
	GlobalVariables.weapon_list[weapon_id] = resource

func _register_mecha_resource(resource: Resource, source_path: String) -> void:
	if resource == null:
		push_warning("Failed to load mecha resource: %s" % source_path)
		return
	var mecha_id_value = resource.get("mecha_id")
	if mecha_id_value == null:
		push_warning("Mecha resource missing mecha_id: %s" % source_path)
		return
	var mecha_id := str(mecha_id_value)
	if mecha_id == "":
		push_warning("Mecha resource has empty mecha_id: %s" % source_path)
		return
	GlobalVariables.mecha_list[mecha_id] = resource

func _register_weapon_branch_resource(resource: Resource, source_path: String) -> void:
	var branch_def := resource as WeaponBranchDefinition
	if branch_def == null:
		push_warning("Failed to load weapon branch resource: %s" % source_path)
		return
	if branch_def.branch_id == "":
		push_warning("Weapon branch resource has empty branch_id: %s" % source_path)
		return
	var scene_path := branch_def.weapon_scene_path
	if scene_path == "":
		push_warning("Weapon branch resource missing weapon_scene_path: %s" % source_path)
		return
	if not GlobalVariables.weapon_branch_list.has(scene_path):
		GlobalVariables.weapon_branch_list[scene_path] = []
	var branch_list: Array = GlobalVariables.weapon_branch_list[scene_path]
	branch_list.append(branch_def)
	GlobalVariables.weapon_branch_list[scene_path] = branch_list

func _register_weapon_passive_branch_resource(resource: Resource, source_path: String) -> void:
	if resource == null:
		push_warning("Failed to load weapon passive resource: %s" % source_path)
		return
	var passive_id_value: Variant = resource.get("passive_id")
	if passive_id_value == null:
		push_warning("Weapon passive resource missing passive_id: %s" % source_path)
		return
	var passive_id := str(passive_id_value)
	if passive_id == "":
		push_warning("Weapon passive resource has empty passive_id: %s" % source_path)
		return
	GlobalVariables.weapon_passive_branch_list[passive_id] = resource

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
	return

func new_save(_file_path: String = "res://data/savedata/autosave.tres") -> void:
	save_data = _create_fresh_runtime_save()
	return
	

func load_game(_file_path: String = "res://data/savedata/autosave.tres") -> void:
	# Persistent save loading is disabled: always start from a fresh runtime state.
	save_data = _create_fresh_runtime_save()

func _create_fresh_runtime_save() -> SaveData:
	var runtime_save := SaveData.new()
	# Keep this explicit so the initial mecha selection is deterministic.
	runtime_save.last_mecha_selected = "1"
	return runtime_save
