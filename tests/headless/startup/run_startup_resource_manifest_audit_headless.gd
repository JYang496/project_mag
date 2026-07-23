extends SceneTree

const MANIFEST_PATH := "res://data/startup/startup_resource_manifest.json"
const ALLOWED_PREPARE_PHASES := [&"world", &"world_deferred"]


func _initialize() -> void:
	var requested_domains := _read_requested_domains(OS.get_cmdline_user_args())
	var errors := _audit_manifest(requested_domains)
	if errors.is_empty():
		print("STARTUP_MANIFEST_AUDIT: PASS")
		quit(0)
		return
	print("STARTUP_MANIFEST_AUDIT: FAIL (%d)" % errors.size())
	for error in errors:
		push_error(error)
	quit(1)


func _audit_manifest(requested_domains: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		errors.append("cannot open startup manifest: %s" % MANIFEST_PATH)
		return errors
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		errors.append("startup manifest is not a JSON object")
		return errors
	var manifest := parsed as Dictionary
	var seen_domains := {}
	for catalog_variant in manifest.get("catalogs", []):
		if not (catalog_variant is Dictionary):
			errors.append("startup manifest contains a non-object catalog")
			continue
		var catalog := catalog_variant as Dictionary
		var domain := str(catalog.get("domain", "")).strip_edges()
		seen_domains[domain] = true
		if not requested_domains.is_empty() and not requested_domains.has(domain):
			continue
		_audit_catalog(catalog, errors)
	for domain in requested_domains:
		if not seen_domains.has(domain):
			errors.append("requested domain is not present in manifest: %s" % domain)
	return errors


func _audit_catalog(catalog: Dictionary, errors: PackedStringArray) -> void:
	var domain := str(catalog.get("domain", "")).strip_edges()
	var expected_type := str(catalog.get("expected_type", "")).strip_edges()
	var id_property := str(catalog.get("id_property", "")).strip_edges()
	var prepare_phase := StringName(str(catalog.get("prepare_phase", "")).strip_edges())
	if not ALLOWED_PREPARE_PHASES.has(prepare_phase):
		errors.append("%s has unsupported prepare_phase: %s" % [domain, prepare_phase])
	var seen_ids := {}
	var paths: Array = catalog.get("paths", [])
	for path_variant in paths:
		var path := str(path_variant)
		var resource := ResourceLoader.load(path)
		if resource == null:
			errors.append("%s failed to load resource: %s" % [domain, path])
			continue
		var actual_type := _resource_script_class(resource)
		if actual_type != expected_type:
			errors.append(
				"%s resource has invalid type at %s: expected %s got %s" % [
					domain, path, expected_type, actual_type
				]
			)
			continue
		if id_property.is_empty():
			continue
		if not _has_property(resource, id_property):
			errors.append("%s resource lacks id property '%s': %s" % [domain, id_property, path])
			continue
		var resource_id := str(resource.get(id_property)).strip_edges()
		if resource_id.is_empty():
			errors.append("%s resource has empty %s: %s" % [domain, id_property, path])
			continue
		if seen_ids.has(resource_id):
			errors.append(
				"%s has duplicate %s '%s': %s and %s" % [
					domain, id_property, resource_id, seen_ids[resource_id], path
				]
			)
			continue
		seen_ids[resource_id] = path
	if domain == "economy" and paths.size() != 1:
		errors.append("economy catalog must contain exactly one resource; got %d" % paths.size())


func _resource_script_class(resource: Resource) -> String:
	var script := resource.get_script() as Script
	if script != null:
		var global_name := str(script.get_global_name()).strip_edges()
		if not global_name.is_empty():
			return global_name
	return resource.get_class()


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _read_requested_domains(arguments: PackedStringArray) -> PackedStringArray:
	var domains := PackedStringArray()
	var index := 0
	while index < arguments.size():
		if arguments[index] == "--domain" and index + 1 < arguments.size():
			domains.append(arguments[index + 1])
			index += 2
			continue
		index += 1
	return domains
