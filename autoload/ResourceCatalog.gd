extends RefCounted
class_name ResourceCatalog

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

static func _join_resource_path(directory_path: String, file_name: String) -> String:
	if directory_path.ends_with("/"):
		return directory_path + file_name
	return "%s/%s" % [directory_path, file_name]
