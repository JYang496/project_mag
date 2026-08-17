extends RefCounted
class_name ModuleOfferCatalog

const MODULE_DIRECTORY_PATH := "res://Player/Weapons/Modules/"
const PROFILE := preload("res://data/module_progression/default_weapon_module_progression.tres")

static func get_profile() -> Resource:
	return PROFILE

static func get_module_id_from_path(scene_path: String) -> StringName:
	return StringName(scene_path.get_file().get_basename())

static func is_scene_unlocked(
	scene_path: String,
	level_index: int = -1,
	endless_mode_override: Variant = null
) -> bool:
	var resolved_level := PhaseManager.current_level if level_index < 0 else level_index
	var resolved_endless := PhaseManager.endless_mode if endless_mode_override == null else bool(endless_mode_override)
	return PROFILE.is_unlocked(get_module_id_from_path(scene_path), resolved_level, resolved_endless)

static func get_offer_weight_multiplier(scene_path: String, level_index: int = -1) -> float:
	var resolved_level := PhaseManager.current_level if level_index < 0 else level_index
	if PROFILE.is_newly_unlocked(get_module_id_from_path(scene_path), resolved_level):
		return maxf(PROFILE.newly_unlocked_weight_multiplier, 1.0)
	return 1.0

static func is_new_tier_scene(scene_path: String, level_index: int = -1) -> bool:
	var resolved_level := PhaseManager.current_level if level_index < 0 else level_index
	return PROFILE.get_tier_ids_for_level(resolved_level).has(str(get_module_id_from_path(scene_path)))

static func has_new_tier_for_level(level_index: int = -1) -> bool:
	var resolved_level := PhaseManager.current_level if level_index < 0 else level_index
	return not PROFILE.get_tier_ids_for_level(resolved_level).is_empty()

static func get_all_scene_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	var dir := DirAccess.open(MODULE_DIRECTORY_PATH)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn") and file_name != "wmod_base.tscn":
			paths.append(MODULE_DIRECTORY_PATH + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths

static func get_unlocked_scene_paths(level_index: int = -1, endless_mode_override: Variant = null) -> PackedStringArray:
	var paths := PackedStringArray()
	for scene_path in get_all_scene_paths():
		if is_scene_unlocked(scene_path, level_index, endless_mode_override):
			paths.append(scene_path)
	return paths

static func validate_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	var scene_ids := PackedStringArray()
	for scene_path in get_all_scene_paths():
		var module_id := str(get_module_id_from_path(scene_path))
		if scene_ids.has(module_id):
			errors.append("Duplicate module scene id: %s" % module_id)
		else:
			scene_ids.append(module_id)
		var scene := load(scene_path) as PackedScene
		if scene == null:
			errors.append("Failed to load module scene: %s" % scene_path)
			continue
		var instance := scene.instantiate() as Module
		if instance == null:
			errors.append("Module scene does not instantiate Module: %s" % scene_path)
		else:
			instance.free()
	var configured_ids: PackedStringArray = PROFILE.get_all_ids()
	var seen_configured := PackedStringArray()
	for module_id in configured_ids:
		if seen_configured.has(module_id):
			errors.append("Duplicate module progression id: %s" % module_id)
		else:
			seen_configured.append(module_id)
		if not scene_ids.has(module_id):
			errors.append("Progression id has no module scene: %s" % module_id)
	for module_id in scene_ids:
		if not configured_ids.has(module_id):
			errors.append("Module scene is missing progression tier: %s" % module_id)
	return errors
