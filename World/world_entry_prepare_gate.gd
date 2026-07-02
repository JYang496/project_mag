extends RefCounted
class_name WorldEntryPrepareGate

const STEP_DATA := "data"
const STEP_ROUTES := "routes"
const STEP_CELL_EFFECTS := "cell_effects"
const STEP_TASK_MODULES := "task_modules"

static func prepare_world_entry() -> Dictionary:
	return aggregate_prepare_results([
		_build_step_result(STEP_DATA, DataHandler.prepare_world_data(false)),
		_build_step_result(STEP_ROUTES, RunRouteManager.prepare_route_definitions()),
		_build_step_result(STEP_CELL_EFFECTS, CellEffectRuntime.prepare_definitions()),
		_build_step_result(STEP_TASK_MODULES, CellTaskModuleRuntime.prepare_definitions()),
	])

static func aggregate_prepare_results(step_results: Array) -> Dictionary:
	var errors := PackedStringArray()
	var steps := {}
	for step_variant in step_results:
		var step := step_variant as Dictionary
		var name := str(step.get("name", "unknown")).strip_edges()
		if name.is_empty():
			name = "unknown"
		var result := step.get("result", {}) as Dictionary
		steps[name] = result.duplicate(true)
		if bool(result.get("ok", false)):
			continue
		var step_errors: PackedStringArray = result.get("errors", PackedStringArray())
		if step_errors.is_empty():
			errors.append("%s: prepare failed without details" % name)
			continue
		for error in step_errors:
			errors.append("%s: %s" % [name, str(error)])
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"steps": steps,
	}

static func format_errors(result: Dictionary) -> String:
	var errors: PackedStringArray = result.get("errors", PackedStringArray())
	if errors.is_empty():
		return ""
	return "; ".join(errors)

static func _build_step_result(name: String, result: Dictionary) -> Dictionary:
	return {
		"name": name,
		"result": result,
	}
