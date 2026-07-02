extends Node

const MANIFEST_PATH := "res://data/startup/startup_resource_manifest.json"

var _failures := PackedStringArray()
var _resource_count := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := _read_manifest()
	if manifest.is_empty():
		_finish()
		return
	if int(manifest.get("schema_version", 0)) != 1:
		_record("unsupported schema_version")
	if str(manifest.get("status", "")) != "runtime_full":
		_record("Startup manifest must describe full runtime consumption")
	if not bool(manifest.get("runtime_consumed", false)):
		_record("Startup manifest must declare runtime consumption")
	var runtime_domains := PackedStringArray()
	for domain_variant in manifest.get("runtime_consumed_domains", []):
		runtime_domains.append(str(domain_variant))
	runtime_domains.sort()
	if runtime_domains != PackedStringArray([
		"cell_effects",
		"economy",
		"mechas",
		"routes",
		"task_modules",
		"weapon_branches",
		"weapon_passives",
		"weapons",
	]):
		_record("Startup runtime domains mismatch: %s" % str(runtime_domains))
	var catalogs: Array = manifest.get("catalogs", [])
	if catalogs.is_empty():
		_record("manifest has no catalogs")
	for catalog_variant in catalogs:
		if not (catalog_variant is Dictionary):
			_record("catalog entry is not a Dictionary")
			continue
		_audit_catalog(catalog_variant as Dictionary)
	_finish()

func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_record("missing manifest: %s" % MANIFEST_PATH)
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_record("cannot open manifest: %s" % MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_record("manifest is not valid JSON object")
		return {}
	return parsed as Dictionary

func _audit_catalog(catalog: Dictionary) -> void:
	var domain := str(catalog.get("domain", "")).strip_edges()
	var directory := str(catalog.get("directory", "")).strip_edges()
	var extension := str(catalog.get("extension", "")).strip_edges().to_lower()
	var expected_type := str(catalog.get("expected_type", "")).strip_edges()
	var id_property := str(catalog.get("id_property", "")).strip_edges()
	var phase := str(catalog.get("prepare_phase", "")).strip_edges()
	var paths := PackedStringArray()
	for path_variant in catalog.get("paths", []):
		var path := str(path_variant).strip_edges()
		if path != "":
			paths.append(path)
	if domain == "" or directory == "" or extension == "" or expected_type == "":
		_record("catalog has missing contract fields: %s" % str(catalog))
		return
	if not ["world", "world_deferred"].has(phase):
		_record("%s has unsupported prepare phase '%s'" % [domain, phase])
	if paths.is_empty():
		_record("%s has no paths" % domain)
		return
	var expected_paths := paths.duplicate()
	expected_paths.sort()
	var actual_paths := _collect_directory_paths(directory, extension)
	if actual_paths != expected_paths:
		_record("%s manifest/directory mismatch expected=%s actual=%s" % [domain, expected_paths, actual_paths])
	var seen_paths := {}
	var seen_ids := {}
	for path in paths:
		if seen_paths.has(path):
			_record("%s has duplicate path '%s'" % [domain, path])
			continue
		seen_paths[path] = true
		if not FileAccess.file_exists(path):
			_record("%s missing resource '%s'" % [domain, path])
			continue
		var resource := load(path)
		if resource == null:
			_record("%s failed to load '%s'" % [domain, path])
			continue
		if not _matches_expected_type(resource, expected_type):
			_record("%s invalid type for '%s'; expected %s" % [domain, path, expected_type])
			continue
		_resource_count += 1
		if id_property == "":
			continue
		var id_value: Variant = resource.get(id_property)
		var normalized_id := str(id_value).strip_edges()
		if normalized_id == "":
			_record("%s resource '%s' has empty %s" % [domain, path, id_property])
		elif seen_ids.has(normalized_id):
			_record("%s duplicate %s '%s' in '%s' and '%s'" % [
				domain,
				id_property,
				normalized_id,
				str(seen_ids[normalized_id]),
				path,
			])
		else:
			seen_ids[normalized_id] = path

func _collect_directory_paths(directory: String, extension: String) -> PackedStringArray:
	var output := PackedStringArray()
	var dir := DirAccess.open(directory)
	if dir == null:
		_record("missing catalog directory '%s'" % directory)
		return output
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(extension):
			output.append(directory.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	output.sort()
	return output

func _matches_expected_type(resource: Resource, expected_type: String) -> bool:
	match expected_type:
		"WeaponDefinition":
			return resource is WeaponDefinition
		"MechaDefinition":
			return resource is MechaDefinition
		"EconomyConfig":
			return resource is EconomyConfig
		"RunRouteDefinition":
			return resource is RunRouteDefinition
		"CellEffectDefinition":
			return resource is CellEffectDefinition
		"TaskModuleDefinition":
			return resource is TaskModuleDefinition
		"WeaponBranchDefinition":
			return resource is WeaponBranchDefinition
		"WeaponPassiveBranchDefinition":
			return resource is WeaponPassiveBranchDefinition
		_:
			return false

func _record(message: String) -> void:
	_failures.append(message)
	push_error("StartupResourceManifestAudit: " + message)

func _finish() -> void:
	if _failures.is_empty():
		print("StartupResourceManifestAudit: PASS catalogs=8 resources=%d" % _resource_count)
		get_tree().quit(0)
		return
	print("StartupResourceManifestAudit: FAIL count=%d" % _failures.size())
	for failure in _failures:
		print(" - " + failure)
	get_tree().quit(1)
