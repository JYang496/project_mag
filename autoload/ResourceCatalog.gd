extends RefCounted
class_name ResourceCatalog

const STARTUP_MANIFEST_PATH := "res://data/startup/startup_resource_manifest.json"

static func collect_resource_paths(
	directory_path: String,
	extension: String,
	fallback_paths: Array = [],
	warn_missing_directory: bool = false,
	context: String = "ResourceCatalog"
) -> PackedStringArray:
	var paths := PackedStringArray()
	var normalized_extension := extension.strip_edges().to_lower()
	if normalized_extension == "":
		return paths
	var dir := DirAccess.open(directory_path)
	if dir == null:
		if warn_missing_directory:
			push_warning("%s: missing resource directory: %s" % [context, directory_path])
	else:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(normalized_extension):
				paths.append(_join_resource_path(directory_path, file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
		paths.sort()
	if paths.is_empty():
		for fallback_path in fallback_paths:
			var path := str(fallback_path).strip_edges()
			if path != "":
				paths.append(path)
	return paths

static func collect_startup_catalog_paths(
	domain: String,
	expected_directory: String,
	expected_extension: String,
	manifest_path: String = STARTUP_MANIFEST_PATH
) -> Dictionary:
	var errors := PackedStringArray()
	var paths := PackedStringArray()
	var manifest := _read_startup_manifest(manifest_path, errors)
	if manifest.is_empty():
		return _catalog_result(false, paths, errors)
	if int(manifest.get("schema_version", 0)) != 1:
		errors.append("unsupported startup manifest schema_version")
	if not bool(manifest.get("runtime_consumed", false)):
		errors.append("startup manifest is not marked runtime_consumed")
	var catalog := _find_startup_catalog(manifest, domain)
	if catalog.is_empty():
		errors.append("missing startup manifest catalog: %s" % domain)
		return _catalog_result(false, paths, errors)
	var directory := str(catalog.get("directory", "")).strip_edges()
	var extension := str(catalog.get("extension", "")).strip_edges().to_lower()
	if directory != expected_directory:
		errors.append("%s directory mismatch: expected %s got %s" % [domain, expected_directory, directory])
	if extension != expected_extension.strip_edges().to_lower():
		errors.append("%s extension mismatch: expected %s got %s" % [domain, expected_extension, extension])
	var seen_paths := {}
	for path_variant in catalog.get("paths", []):
		var path := str(path_variant).strip_edges()
		if path == "":
			errors.append("%s contains an empty path" % domain)
			continue
		if seen_paths.has(path):
			errors.append("%s contains duplicate path: %s" % [domain, path])
			continue
		seen_paths[path] = true
		if not path.begins_with(directory):
			errors.append("%s path is outside directory: %s" % [domain, path])
			continue
		if not path.to_lower().ends_with(extension):
			errors.append("%s path has unexpected extension: %s" % [domain, path])
			continue
		if not ResourceLoader.exists(path):
			errors.append("%s missing resource: %s" % [domain, path])
			continue
		paths.append(path)
	if paths.is_empty():
		errors.append("%s catalog has no usable paths" % domain)
	return _catalog_result(errors.is_empty(), paths, errors)

static func _join_resource_path(directory_path: String, file_name: String) -> String:
	if directory_path.ends_with("/"):
		return directory_path + file_name
	return "%s/%s" % [directory_path, file_name]

static func _read_startup_manifest(manifest_path: String, errors: PackedStringArray) -> Dictionary:
	if not FileAccess.file_exists(manifest_path):
		errors.append("missing startup manifest: %s" % manifest_path)
		return {}
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		errors.append("cannot open startup manifest: %s" % manifest_path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		errors.append("startup manifest is not a JSON object")
		return {}
	return parsed as Dictionary

static func _find_startup_catalog(manifest: Dictionary, domain: String) -> Dictionary:
	for catalog_variant in manifest.get("catalogs", []):
		if not (catalog_variant is Dictionary):
			continue
		var catalog := catalog_variant as Dictionary
		if str(catalog.get("domain", "")).strip_edges() == domain:
			return catalog
	return {}

static func _catalog_result(ok: bool, paths: PackedStringArray, errors: PackedStringArray) -> Dictionary:
	return {
		"ok": ok,
		"paths": paths,
		"errors": errors,
	}
