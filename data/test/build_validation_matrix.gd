extends Resource
class_name BuildValidationMatrix

@export var version: String = "1.0"
@export var encounter_types: Array[Dictionary] = []
@export var build_cases: Array[Dictionary] = []

func get_encounter_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for encounter in encounter_types:
		var encounter_id := str(encounter.get("id", "")).strip_edges()
		if encounter_id != "":
			ids.append(encounter_id)
	return ids

func get_build_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for build_case in build_cases:
		var build_id := str(build_case.get("id", "")).strip_edges()
		if build_id != "":
			ids.append(build_id)
	return ids
