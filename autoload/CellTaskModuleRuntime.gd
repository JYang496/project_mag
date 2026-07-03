extends Node

signal inventory_changed
signal deployment_changed
signal active_tasks_changed
signal completed_tasks_changed
signal active_task_status_changed(cell_id: int)

const RESOURCE_CATALOG := preload("res://autoload/ResourceCatalog.gd")
const TASK_MODULE_DIRECTORY_PATH := "res://data/task_modules/"
const STATE_PATH := "user://cell_task_module_runtime_state.json"
const ACTIVE_LIMIT := 2
const REWARD_KIND_TASK_MODULE: StringName = &"task_module"
const STARTING_TASK_CELL_ID := 5
const STARTING_CELL_EFFECT_COUNT := 2
const STARTING_TASK_MODULE_IDS := [
	"task_kill_common",
	"task_hold_common",
	"task_clear_rare",
]

var _definitions_by_id: Dictionary = {}
var _inventory: PackedStringArray = PackedStringArray()
var _deployments: Dictionary = {}
var _active_tasks: Dictionary = {}
var _completed_cells: Dictionary = {}
var _last_completed_count: int = 0
var _special_shop_offer_module_id := ""
var _special_shop_offer_checks: int = 0
var _granted_reward_ids: Dictionary = {}
var _definition_prepare_result: Dictionary = {"ok": false, "errors": PackedStringArray(), "count": 0}
var _runtime_state_loaded := false

func _ready() -> void:
	if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.connect(_on_phase_changed)

func load_definitions() -> void:
	prepare_definitions(true)

func prepare_definitions(force: bool = false) -> Dictionary:
	if not force and bool(_definition_prepare_result.get("ok", false)):
		return _definition_prepare_result.duplicate(true)
	var catalog_result: Dictionary = RESOURCE_CATALOG.collect_startup_catalog_paths(
		"task_modules",
		TASK_MODULE_DIRECTORY_PATH,
		".tres"
	)
	var errors := PackedStringArray()
	if not bool(catalog_result.get("ok", false)):
		errors.append_array(catalog_result.get("errors", PackedStringArray()))
	var loaded_definitions := {}
	for path in catalog_result.get("paths", PackedStringArray()):
		var definition := load(str(path)) as TaskModuleDefinition
		if definition == null:
			errors.append("invalid task module resource: %s" % str(path))
			continue
		var module_id := definition.module_id.strip_edges()
		if module_id == "":
			errors.append("task module resource missing module_id: %s" % str(path))
			continue
		if loaded_definitions.has(module_id):
			errors.append("duplicate module_id '%s': %s" % [module_id, str(path)])
			continue
		loaded_definitions[module_id] = definition
	if loaded_definitions.is_empty():
		errors.append("no task module definitions were prepared")
	if not errors.is_empty():
		_definition_prepare_result = _build_prepare_result(false, errors, 0)
		push_error("CellTaskModuleRuntime: failed to prepare definitions: %s" % "; ".join(errors))
		return _definition_prepare_result.duplicate(true)
	_definitions_by_id = loaded_definitions
	_definition_prepare_result = _build_prepare_result(true, errors, _definitions_by_id.size())
	_ensure_runtime_state_loaded()
	return _definition_prepare_result.duplicate(true)

func get_definition_prepare_result() -> Dictionary:
	return _definition_prepare_result.duplicate(true)

func get_definition(module_id: String) -> TaskModuleDefinition:
	return _definitions_by_id.get(module_id.strip_edges(), null) as TaskModuleDefinition

func get_all_definitions() -> Array[TaskModuleDefinition]:
	var output: Array[TaskModuleDefinition] = []
	for value in _definitions_by_id.values():
		if value is TaskModuleDefinition:
			output.append(value as TaskModuleDefinition)
	return output

func get_inventory_snapshot() -> PackedStringArray:
	return _inventory.duplicate()

func get_deployment_snapshot() -> Dictionary:
	return _deployments.duplicate(true)

func get_active_tasks_snapshot() -> Dictionary:
	return _active_tasks.duplicate(true)

func get_completed_cells_snapshot() -> Dictionary:
	return _completed_cells.duplicate(true)

func get_last_completed_count() -> int:
	return _last_completed_count

func get_special_shop_offer_module_id() -> String:
	return _special_shop_offer_module_id

func get_special_shop_offer_definition() -> TaskModuleDefinition:
	return get_definition(_special_shop_offer_module_id)

func has_unassigned_modules() -> bool:
	return not _inventory.is_empty()

func get_inventory_size() -> int:
	return _inventory.size()

func grant_module(module_id: String) -> Dictionary:
	var definition := get_definition(module_id)
	if definition == null:
		return {"ok": false, "reason": "Missing task module."}
	_inventory.append(definition.module_id)
	save_runtime_state()
	inventory_changed.emit()
	return {"ok": true, "reason": ""}

func grant_module_once(reward_entry_id: String, module_id: String) -> Dictionary:
	var entry_id := reward_entry_id.strip_edges()
	if entry_id != "" and _granted_reward_ids.has(entry_id):
		return {"ok": true, "reason": "", "already_granted": true}
	var definition := get_definition(module_id)
	if definition == null:
		return {"ok": false, "reason": "Missing task module."}
	_inventory.append(definition.module_id)
	if entry_id != "":
		_granted_reward_ids[entry_id] = true
	save_runtime_state()
	inventory_changed.emit()
	return {"ok": true, "reason": ""}

func grant_random_unlocked_module(level_index: int = 0) -> String:
	var reward := build_reward_option(level_index)
	if reward == null or reward.task_module_id.strip_edges() == "":
		push_warning("CellTaskModuleRuntime: no unlocked task module available to grant.")
		return ""
	var module_id := reward.task_module_id.strip_edges()
	var result := grant_module(module_id)
	if not bool(result.get("ok", false)):
		push_warning("CellTaskModuleRuntime: failed to grant random task module '%s': %s" % [module_id, str(result.get("reason", ""))])
		return ""
	return module_id

func grant_starting_cell_loadout(level_index: int = 0) -> void:
	CellEffectRuntime.reset_runtime_state()
	reset_runtime_state()

	var first_effect_id := ""
	for index in range(STARTING_CELL_EFFECT_COUNT):
		var effect_id := CellEffectRuntime.grant_random_unlocked_effect(level_index, 1)
		if index == 0:
			first_effect_id = effect_id

	if first_effect_id.strip_edges() != "":
		CellEffectRuntime.set_pending_effect(STARTING_TASK_CELL_ID, first_effect_id)

	for module_id in STARTING_TASK_MODULE_IDS:
		var result := grant_module(str(module_id))
		if not bool(result.get("ok", false)):
			push_warning("CellTaskModuleRuntime: failed to grant starting task module '%s': %s" % [str(module_id), str(result.get("reason", ""))])

func replace_inventory_module(index: int, module_id: String) -> Dictionary:
	var definition := get_definition(module_id)
	if definition == null:
		return {"ok": false, "reason": "Missing task module."}
	if index < 0 or index >= _inventory.size():
		return {"ok": false, "reason": "Invalid task module slot."}
	_inventory[index] = definition.module_id
	save_runtime_state()
	inventory_changed.emit()
	return {"ok": true, "reason": ""}

func discard_inventory_module(index: int) -> Dictionary:
	if index < 0 or index >= _inventory.size():
		return {"ok": false, "reason": "Invalid task module slot."}
	_inventory.remove_at(index)
	save_runtime_state()
	inventory_changed.emit()
	return {"ok": true, "reason": ""}

func can_deploy_inventory_module(index: int, cell_id: int, board: BoardCellGenerator = null) -> Dictionary:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return {"ok": false, "reason": "Task modules can only be deployed during prepare."}
	if index < 0 or index >= _inventory.size():
		return {"ok": false, "reason": "Invalid task module slot."}
	if cell_id <= 0:
		return {"ok": false, "reason": "Invalid cell."}
	if _deployments.has(str(cell_id)):
		return {"ok": false, "reason": "Cell already has a deployed task."}
	if _deployments.size() >= ACTIVE_LIMIT:
		return {"ok": false, "reason": "Maximum deployed tasks reached."}
	if board != null and not board.is_cell_active_by_id(cell_id):
		return {"ok": false, "reason": "Task modules can only target active cells."}
	var definition := get_definition(_inventory[index])
	if definition == null:
		return {"ok": false, "reason": "Missing task module."}
	return {"ok": true, "reason": ""}

func deploy_inventory_module(index: int, cell_id: int, board: BoardCellGenerator = null) -> Dictionary:
	var validation := can_deploy_inventory_module(index, cell_id, board)
	if not bool(validation.get("ok", false)):
		return validation
	var module_id := str(_inventory[index])
	_inventory.remove_at(index)
	_deployments[str(cell_id)] = module_id
	save_runtime_state()
	inventory_changed.emit()
	deployment_changed.emit()
	return {"ok": true, "reason": ""}

func can_replace_deployment_with_inventory_module(index: int, cell_id: int, board: BoardCellGenerator = null) -> Dictionary:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return {"ok": false, "reason": "Task modules can only be deployed during prepare."}
	if index < 0 or index >= _inventory.size():
		return {"ok": false, "reason": "Invalid task module slot."}
	if cell_id <= 0:
		return {"ok": false, "reason": "Invalid cell."}
	var key := str(cell_id)
	if not _deployments.has(key):
		return {"ok": false, "reason": "No deployed task on this cell."}
	if board != null and not board.is_cell_active_by_id(cell_id):
		return {"ok": false, "reason": "Task modules can only target active cells."}
	var definition := get_definition(_inventory[index])
	if definition == null:
		return {"ok": false, "reason": "Missing task module."}
	return {"ok": true, "reason": ""}

func replace_deployment_with_inventory_module(index: int, cell_id: int, board: BoardCellGenerator = null) -> Dictionary:
	var validation := can_replace_deployment_with_inventory_module(index, cell_id, board)
	if not bool(validation.get("ok", false)):
		return validation
	var key := str(cell_id)
	var previous_module_id := str(_deployments[key])
	var module_id := str(_inventory[index])
	_inventory.remove_at(index)
	_deployments[key] = module_id
	save_runtime_state()
	inventory_changed.emit()
	deployment_changed.emit()
	return {"ok": true, "reason": "", "replaced_module_id": previous_module_id}

func cancel_deployment(cell_id: int) -> Dictionary:
	var key := str(cell_id)
	if not _deployments.has(key):
		return {"ok": false, "reason": "No deployed task on this cell."}
	return {"ok": false, "reason": "Deployed task modules cannot be removed."}

func clear_unassigned_modules() -> int:
	var count := _inventory.size()
	if count <= 0:
		return 0
	_inventory.clear()
	save_runtime_state()
	inventory_changed.emit()
	return count

func commit_deployments_for_battle(board: BoardCellGenerator = null, clear_unassigned: bool = true) -> Dictionary:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return {"ok": false, "reason": "Can only commit task modules from prepare."}
	if clear_unassigned:
		clear_unassigned_modules()
	_active_tasks.clear()
	for cell_key in _deployments.keys():
		if _active_tasks.size() >= ACTIVE_LIMIT:
			break
		var cell_id := int(str(cell_key))
		if cell_id <= 0:
			continue
		if board != null and not board.is_cell_active_by_id(cell_id):
			continue
		var module_id := str(_deployments[cell_key])
		if get_definition(module_id) == null:
			continue
		_active_tasks[str(cell_id)] = module_id
	_deployments.clear()
	_completed_cells.clear()
	save_runtime_state()
	deployment_changed.emit()
	active_tasks_changed.emit()
	completed_tasks_changed.emit()
	active_task_status_changed.emit(0)
	if board != null and board.has_method("apply_task_module_runtime_state"):
		board.call("apply_task_module_runtime_state")
	return {"ok": true, "reason": "", "active_count": _active_tasks.size()}

func get_active_task_statuses(board: BoardCellGenerator = null) -> Array[Dictionary]:
	var statuses: Array[Dictionary] = []
	for cell_id in _get_sorted_active_task_cell_ids():
		if statuses.size() >= ACTIVE_LIMIT:
			break
		var module_id := get_active_task_module_id(cell_id)
		if module_id.strip_edges() == "":
			continue
		var status := _build_status_for_active_task(cell_id, module_id, board)
		statuses.append(_normalize_task_status(status, cell_id, module_id))
	return statuses

func get_active_task_module_id(cell_id: int) -> String:
	return str(_active_tasks.get(str(cell_id), ""))

func get_active_task_definition(cell_id: int) -> TaskModuleDefinition:
	return get_definition(get_active_task_module_id(cell_id))

func has_active_task_for_cell(cell_id: int) -> bool:
	return get_active_task_definition(cell_id) != null

func record_objective_completed(cell_id_text: String) -> void:
	var cell_id := _extract_cell_id(cell_id_text)
	if cell_id <= 0:
		return
	var key := str(cell_id)
	if not _active_tasks.has(key):
		return
	if _completed_cells.has(key):
		return
	_completed_cells[key] = _active_tasks[key]
	_last_completed_count += 1
	save_runtime_state()
	completed_tasks_changed.emit()
	active_task_status_changed.emit(cell_id)

func clear_active_tasks(board: BoardCellGenerator = null) -> void:
	if _active_tasks.is_empty() and _completed_cells.is_empty():
		return
	_active_tasks.clear()
	_completed_cells.clear()
	save_runtime_state()
	active_tasks_changed.emit()
	completed_tasks_changed.emit()
	active_task_status_changed.emit(0)
	if board != null and board.has_method("apply_task_module_runtime_state"):
		board.call("apply_task_module_runtime_state")

func prepare_special_shop_offer(force: bool = false) -> String:
	if _special_shop_offer_module_id != "":
		return _special_shop_offer_module_id
	if _last_completed_count <= 0 and not force:
		return ""
	var should_offer := force
	var checks := maxi(_last_completed_count, 1)
	_last_completed_count = 0
	for _i in range(checks):
		if randf() <= 0.45:
			should_offer = true
			break
	_special_shop_offer_checks = checks
	if not should_offer:
		save_runtime_state()
		return ""
	var reward := build_reward_option(PhaseManager.current_level)
	if reward == null:
		save_runtime_state()
		return ""
	_special_shop_offer_module_id = reward.task_module_id
	save_runtime_state()
	deployment_changed.emit()
	return _special_shop_offer_module_id

func clear_special_shop_offer() -> void:
	if _special_shop_offer_module_id == "" and _special_shop_offer_checks <= 0:
		return
	_special_shop_offer_module_id = ""
	_special_shop_offer_checks = 0
	save_runtime_state()
	deployment_changed.emit()

func get_special_shop_cost_count(module_id: String = "") -> int:
	var definition := get_definition(module_id if module_id != "" else _special_shop_offer_module_id)
	if definition == null:
		return 0
	return 2 if definition.get_rarity() == "common" else 1

func can_purchase_special_shop_offer() -> Dictionary:
	var definition := get_special_shop_offer_definition()
	if definition == null:
		return {"ok": false, "reason": "No task module offer."}
	var cost := get_special_shop_cost_count(definition.module_id)
	var available := CellEffectRuntime.get_available_effect_ids_by_rarity(definition.get_rarity())
	if available.size() < cost:
		return {"ok": false, "reason": "Not enough %s cell effects." % definition.get_rarity()}
	return {"ok": true, "reason": ""}

func purchase_special_shop_offer() -> Dictionary:
	var validation := can_purchase_special_shop_offer()
	if not bool(validation.get("ok", false)):
		return validation
	var definition := get_special_shop_offer_definition()
	var cost := get_special_shop_cost_count(definition.module_id)
	var consume_result := CellEffectRuntime.consume_available_effects_by_rarity(definition.get_rarity(), cost)
	if not bool(consume_result.get("ok", false)):
		return consume_result
	var grant_result := grant_module(definition.module_id)
	if not bool(grant_result.get("ok", false)):
		return grant_result
	clear_special_shop_offer()
	return {"ok": true, "reason": ""}

func reset_runtime_state() -> void:
	_inventory.clear()
	_deployments.clear()
	_active_tasks.clear()
	_completed_cells.clear()
	_last_completed_count = 0
	_special_shop_offer_module_id = ""
	_special_shop_offer_checks = 0
	_granted_reward_ids.clear()
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
	_runtime_state_loaded = true
	inventory_changed.emit()
	deployment_changed.emit()
	active_tasks_changed.emit()
	completed_tasks_changed.emit()
	active_task_status_changed.emit(0)

func save_runtime_state() -> void:
	var payload := {
		"inventory": _inventory,
		"deployments": _deployments,
		"active_tasks": _active_tasks,
		"completed_cells": _completed_cells,
		"last_completed_count": _last_completed_count,
		"special_shop_offer_module_id": _special_shop_offer_module_id,
		"special_shop_offer_checks": _special_shop_offer_checks,
		"granted_reward_ids": _granted_reward_ids,
	}
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))

func load_runtime_state() -> void:
	var payload := _read_json_dictionary(STATE_PATH)
	if payload.is_empty():
		_runtime_state_loaded = true
		return
	_inventory = _sanitize_inventory(payload.get("inventory", []))
	_deployments = _sanitize_module_dictionary(payload.get("deployments", {}))
	_active_tasks = _sanitize_module_dictionary(payload.get("active_tasks", {}))
	_completed_cells = _sanitize_module_dictionary(payload.get("completed_cells", {}))
	_last_completed_count = maxi(int(payload.get("last_completed_count", 0)), 0)
	_special_shop_offer_module_id = str(payload.get("special_shop_offer_module_id", ""))
	if get_definition(_special_shop_offer_module_id) == null:
		_special_shop_offer_module_id = ""
	_special_shop_offer_checks = maxi(int(payload.get("special_shop_offer_checks", 0)), 0)
	_granted_reward_ids = (payload.get("granted_reward_ids", {}) as Dictionary).duplicate(true) \
		if payload.get("granted_reward_ids", {}) is Dictionary else {}
	_runtime_state_loaded = true
	inventory_changed.emit()
	deployment_changed.emit()
	active_tasks_changed.emit()
	completed_tasks_changed.emit()

func _ensure_runtime_state_loaded() -> void:
	if not _runtime_state_loaded:
		load_runtime_state()

func _sanitize_inventory(raw: Variant) -> PackedStringArray:
	var output := PackedStringArray()
	if raw is Array:
		for value in raw:
			var module_id := str(value)
			if get_definition(module_id) != null:
				output.append(module_id)
	return output

func _sanitize_module_dictionary(raw: Variant) -> Dictionary:
	var output := {}
	if not (raw is Dictionary):
		return output
	for key in (raw as Dictionary).keys():
		var module_id := str((raw as Dictionary)[key])
		if get_definition(module_id) != null:
			output[str(key)] = module_id
	return output

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

func notify_active_task_status_changed(cell_id: int) -> void:
	if cell_id <= 0:
		return
	if not _active_tasks.has(str(cell_id)):
		return
	active_task_status_changed.emit(cell_id)

func build_reward_option(level_index: int = 0, rarity_filter: String = "") -> RewardInfo:
	var candidates: Array[TaskModuleDefinition] = []
	var level_one_based := maxi(level_index + 1, 1)
	for definition in get_all_definitions():
		if int(definition.unlock_level) > level_one_based:
			continue
		if definition.get_reward_weight() <= 0.0:
			continue
		if rarity_filter.strip_edges() != "" and definition.get_rarity() != rarity_filter.strip_edges():
			continue
		candidates.append(definition)
	var selected := _pick_weighted_definition(candidates)
	if selected == null:
		return null
	var reward := RewardInfo.new()
	reward.reward_kind = REWARD_KIND_TASK_MODULE
	reward.task_module_id = selected.module_id
	reward.rarity = selected.get_rarity()
	reward.reward_key_override = "task_module:%s" % selected.module_id
	return reward

func _pick_weighted_definition(definitions: Array[TaskModuleDefinition]) -> TaskModuleDefinition:
	var total := 0.0
	for definition in definitions:
		if definition != null:
			total += definition.get_reward_weight()
	if total <= 0.0:
		return null
	var roll := randf() * total
	for definition in definitions:
		if definition == null:
			continue
		roll -= definition.get_reward_weight()
		if roll <= 0.0:
			return definition
	return definitions[0] if not definitions.is_empty() else null

func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.GAMEOVER:
		reset_runtime_state()
		return
	if new_phase == PhaseManager.PREPARE:
		clear_active_tasks()
		prepare_special_shop_offer(false)

func _extract_cell_id(cell_id_text: String) -> int:
	var text := cell_id_text.strip_edges()
	if text.is_valid_int():
		return int(text)
	var digits := ""
	for index in range(text.length()):
		var character := text[index]
		if character >= "0" and character <= "9":
			digits += character
	return int(digits) if digits != "" else 0

func _get_sorted_active_task_cell_ids() -> Array[int]:
	var cell_ids: Array[int] = []
	for cell_key in _active_tasks.keys():
		var cell_id := int(str(cell_key))
		if cell_id > 0:
			cell_ids.append(cell_id)
	cell_ids.sort()
	return cell_ids

func _build_status_for_active_task(cell_id: int, module_id: String, board: BoardCellGenerator) -> Dictionary:
	var cell := _get_status_cell(cell_id, board)
	var objective := _get_cell_objective_module(cell)
	if objective != null and objective.has_method("get_combat_task_status"):
		var status: Variant = objective.call("get_combat_task_status")
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return _build_fallback_task_status(cell_id, module_id, cell)

func _get_status_cell(cell_id: int, board: BoardCellGenerator) -> Cell:
	if board == null:
		return null
	if not board.has_method("get_cell_by_logical_id"):
		return null
	return board.get_cell_by_logical_id(cell_id)

func _get_cell_objective_module(cell: Cell) -> CellObjectiveModule:
	if cell == null:
		return null
	var module_root := cell.get_node_or_null("Modules")
	if module_root == null:
		return null
	for child in module_root.get_children():
		if child is CellObjectiveModule:
			return child as CellObjectiveModule
	return null

func _build_fallback_task_status(cell_id: int, module_id: String, cell: Cell) -> Dictionary:
	var definition := get_definition(module_id)
	var icon_key := "fallback"
	var label := ""
	if definition != null:
		icon_key = _task_type_to_status_key(definition.task_type)
		label = _task_type_to_status_label(definition.task_type)
	var state := "waiting"
	if cell != null and (not cell.board_enabled or cell.state == Cell.CellState.LOCKED):
		state = "blocked"
	return {
		"cell_id": cell_id,
		"module_id": module_id,
		"type": icon_key,
		"icon_key": icon_key,
		"label": label,
		"instruction_key": _status_type_to_instruction_key(icon_key),
		"instruction": _status_type_to_instruction(icon_key),
		"progress": 0.0,
		"value_text": _default_status_value_text(icon_key),
		"state": state
	}

func _normalize_task_status(status: Dictionary, cell_id: int, module_id: String) -> Dictionary:
	var normalized := status.duplicate(true)
	normalized["cell_id"] = int(normalized.get("cell_id", cell_id))
	if int(normalized["cell_id"]) <= 0:
		normalized["cell_id"] = cell_id
	normalized["module_id"] = str(normalized.get("module_id", module_id))
	if str(normalized["module_id"]).strip_edges() == "":
		normalized["module_id"] = module_id
	var type_text := str(normalized.get("type", "fallback"))
	if type_text.strip_edges() == "":
		type_text = "fallback"
	normalized["type"] = type_text
	var icon_key := str(normalized.get("icon_key", type_text))
	normalized["icon_key"] = icon_key if icon_key.strip_edges() != "" else "fallback"
	normalized["label"] = _localized_status_label(type_text, str(normalized.get("label", "")).strip_edges())
	var instruction_key := str(normalized.get("instruction_key", "")).strip_edges()
	if instruction_key == "":
		instruction_key = _status_type_to_instruction_key(type_text)
	normalized["instruction_key"] = instruction_key
	var instruction_text := str(normalized.get("instruction", "")).strip_edges()
	if instruction_text == "":
		instruction_text = _status_type_to_instruction(type_text, instruction_key)
	normalized["instruction"] = instruction_text
	normalized["progress"] = clampf(float(normalized.get("progress", 0.0)), 0.0, 1.0)
	normalized["value_text"] = str(normalized.get("value_text", "")).strip_edges()
	var state := str(normalized.get("state", "waiting"))
	if not ["waiting", "active", "complete", "blocked"].has(state):
		state = "waiting"
	if _completed_cells.has(str(cell_id)):
		state = "complete"
		normalized["progress"] = 1.0
		normalized["value_text"] = LocalizationManager.tr_key("ui.task_objective.complete", "Complete")
	elif str(normalized["value_text"]) == "":
		normalized["value_text"] = _default_status_value_text(type_text)
	else:
		normalized["value_text"] = _localized_status_value_text(str(normalized["value_text"]))
	normalized["state"] = state
	return normalized

func _task_type_to_status_key(task_type: int) -> String:
	match task_type:
		Cell.TaskType.OFFENSE:
			return "kill"
		Cell.TaskType.DEFENSE:
			return "hold"
		Cell.TaskType.CLEAR:
			return "clear"
		Cell.TaskType.HUNT:
			return "hunt"
		Cell.TaskType.DODGE:
			return "dodge"
		_:
			return "fallback"

func _task_type_to_status_label(task_type: int) -> String:
	return _status_type_to_label(_task_type_to_status_key(task_type))

func _status_type_to_label(status_type: String) -> String:
	match status_type:
		"kill":
			return LocalizationManager.tr_key("ui.task_type.kill", "Kill")
		"hold":
			return LocalizationManager.tr_key("ui.task_type.hold", "Hold")
		"clear":
			return LocalizationManager.tr_key("ui.task_type.clear", "Clear")
		"hunt":
			return LocalizationManager.tr_key("ui.task_type.hunt", "Hunt")
		"dodge":
			return LocalizationManager.tr_key("ui.task_type.dodge", "Dodge")
		_:
			return LocalizationManager.tr_key("ui.task_type.task", "Task")

func _localized_status_label(status_type: String, raw_label: String) -> String:
	if raw_label == "占领" or raw_label == "Capture":
		return LocalizationManager.tr_key("ui.task_type.capture", "Capture")
	return _status_type_to_label(status_type)

func _status_type_to_instruction_key(status_type: String) -> String:
	match status_type:
		"kill":
			return "ui.task_objective.instruction.kill"
		"hold":
			return "ui.task_objective.instruction.hold"
		"clear":
			return "ui.task_objective.instruction.clear"
		"hunt":
			return "ui.task_objective.instruction.hunt"
		"dodge":
			return "ui.task_objective.instruction.dodge"
		_:
			return ""

func _status_type_to_instruction(status_type: String, instruction_key: String = "") -> String:
	var fallback := _status_type_to_instruction_fallback(status_type)
	var key := instruction_key.strip_edges()
	if key == "":
		key = _status_type_to_instruction_key(status_type)
	if key == "":
		return fallback
	return LocalizationManager.tr_key(key, fallback)

func _status_type_to_instruction_fallback(status_type: String) -> String:
	match status_type:
		"kill":
			return "Kill enemies"
		"hold":
			return "Stay inside the marked cell"
		"clear":
			return "Clear enemies near this cell"
		"hunt":
			return "Defeat the marked elite"
		"dodge":
			return "Avoid damage until timer ends"
		_:
			return ""

func _default_status_value_text(status_type: String) -> String:
	match status_type:
		"hold":
			return "0/100%"
		"dodge":
			return "0/1%s" % LocalizationManager.tr_key("ui.task_objective.unit.second", "s")
		_:
			return "0/1"

func _localized_status_value_text(value_text: String) -> String:
	if value_text.ends_with("秒"):
		return value_text.trim_suffix("秒") + LocalizationManager.tr_key("ui.task_objective.unit.second", "s")
	return value_text

func _build_prepare_result(ok: bool, errors: PackedStringArray, count: int) -> Dictionary:
	return {
		"ok": ok,
		"errors": errors,
		"count": count,
	}
