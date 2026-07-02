extends Node

const WORLD_ENTRY_PREPARE_GATE_SCRIPT := preload("res://World/world_entry_prepare_gate.gd")

var _failures := PackedStringArray()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_assert_menu_phase_has_not_prepared_world_resources()
	_reset_runtime_state()
	var success_result: Dictionary = WORLD_ENTRY_PREPARE_GATE_SCRIPT.prepare_world_entry()
	if not bool(success_result.get("ok", false)):
		_record("real world entry prepare failed: %s" % WORLD_ENTRY_PREPARE_GATE_SCRIPT.format_errors(success_result))
	var steps: Dictionary = success_result.get("steps", {})
	for required_step in ["data", "routes", "cell_effects", "task_modules"]:
		if not steps.has(required_step):
			_record("world entry prepare omitted step: %s" % required_step)

	var failure_result: Dictionary = WORLD_ENTRY_PREPARE_GATE_SCRIPT.aggregate_prepare_results([
		{"name": "good", "result": {"ok": true, "errors": PackedStringArray(), "count": 1}},
		{"name": "bad", "result": {"ok": false, "errors": PackedStringArray(["missing weapon"]), "count": 0}},
	])
	if bool(failure_result.get("ok", true)):
		_record("aggregate prepare result did not fail when a step failed")
	var failure_errors: PackedStringArray = failure_result.get("errors", PackedStringArray())
	if failure_errors.size() != 1 or not str(failure_errors[0]).contains("bad: missing weapon"):
		_record("aggregate prepare failure details were not preserved: %s" % str(failure_errors))

	var empty_failure: Dictionary = WORLD_ENTRY_PREPARE_GATE_SCRIPT.aggregate_prepare_results([
		{"name": "empty", "result": {"ok": false, "errors": PackedStringArray(), "count": 0}},
	])
	if bool(empty_failure.get("ok", true)):
		_record("empty failed step did not make aggregate fail")
	if not WORLD_ENTRY_PREPARE_GATE_SCRIPT.format_errors(empty_failure).contains("empty: prepare failed without details"):
		_record("empty failed step did not receive fallback error text")

	_finish()

func _record(message: String) -> void:
	_failures.append(message)
	push_error("WorldEntryPrepareGateTest: " + message)

func _assert_menu_phase_has_not_prepared_world_resources() -> void:
	if bool(RunRouteManager.get_route_prepare_result().get("ok", false)):
		_record("routes were prepared before explicit world entry")
	if bool(CellEffectRuntime.get_definition_prepare_result().get("ok", false)):
		_record("cell effects were prepared before explicit world entry")
	if bool(CellTaskModuleRuntime.get_definition_prepare_result().get("ok", false)):
		_record("task modules were prepared before explicit world entry")

func _finish() -> void:
	_reset_runtime_state()
	if _failures.is_empty():
		print("WorldEntryPrepareGateTest: PASS")
		get_tree().quit(0)
		return
	print("WorldEntryPrepareGateTest: FAIL count=%d" % _failures.size())
	for failure in _failures:
		print(" - " + failure)
	get_tree().quit(1)

func _reset_runtime_state() -> void:
	RunRouteManager.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	GlobalVariables.weapon_list = {}
	GlobalVariables.mecha_list = {}
	GlobalVariables.weapon_branch_list = {}
	GlobalVariables.weapon_passive_branch_list = {}
	GlobalVariables.economy_data = null
