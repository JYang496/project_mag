extends Node

signal inventory_changed
signal deployment_changed
signal active_tasks_changed
signal completed_tasks_changed

const TASK_MODULE_DIRECTORY_PATH := "res://data/task_modules/"
const INVENTORY_LIMIT := 2
const ACTIVE_LIMIT := 2
const REWARD_KIND_TASK_MODULE: StringName = &"task_module"

var _definitions_by_id: Dictionary = {}
var _inventory: PackedStringArray = PackedStringArray()
var _deployments: Dictionary = {}
var _active_tasks: Dictionary = {}
var _completed_cells: Dictionary = {}
var _last_completed_count: int = 0
var _special_shop_offer_module_id := ""
var _special_shop_offer_checks: int = 0

func _ready() -> void:
	load_definitions()
	if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.connect(_on_phase_changed)

func load_definitions() -> void:
	_definitions_by_id.clear()
	var dir := DirAccess.open(TASK_MODULE_DIRECTORY_PATH)
	if dir == null:
		push_warning("CellTaskModuleRuntime: missing task module directory: %s" % TASK_MODULE_DIRECTORY_PATH)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := TASK_MODULE_DIRECTORY_PATH + file_name
			var definition := load(path) as TaskModuleDefinition
			if definition != null and definition.module_id.strip_edges() != "":
				_definitions_by_id[definition.module_id.strip_edges()] = definition
		file_name = dir.get_next()
	dir.list_dir_end()

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
	if _inventory.size() >= INVENTORY_LIMIT:
		return {"ok": false, "reason": "Task module inventory is full.", "needs_replace": true}
	_inventory.append(definition.module_id)
	inventory_changed.emit()
	return {"ok": true, "reason": ""}

func replace_inventory_module(index: int, module_id: String) -> Dictionary:
	var definition := get_definition(module_id)
	if definition == null:
		return {"ok": false, "reason": "Missing task module."}
	if index < 0 or index >= _inventory.size():
		return {"ok": false, "reason": "Invalid task module slot."}
	_inventory[index] = definition.module_id
	inventory_changed.emit()
	return {"ok": true, "reason": ""}

func discard_inventory_module(index: int) -> Dictionary:
	if index < 0 or index >= _inventory.size():
		return {"ok": false, "reason": "Invalid task module slot."}
	_inventory.remove_at(index)
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
	inventory_changed.emit()
	deployment_changed.emit()
	return {"ok": true, "reason": ""}

func cancel_deployment(cell_id: int) -> Dictionary:
	var key := str(cell_id)
	if not _deployments.has(key):
		return {"ok": false, "reason": "No deployed task on this cell."}
	if _inventory.size() >= INVENTORY_LIMIT:
		return {"ok": false, "reason": "Task module inventory is full."}
	_inventory.append(str(_deployments[key]))
	_deployments.erase(key)
	inventory_changed.emit()
	deployment_changed.emit()
	return {"ok": true, "reason": ""}

func clear_unassigned_modules() -> int:
	var count := _inventory.size()
	if count <= 0:
		return 0
	_inventory.clear()
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
	deployment_changed.emit()
	active_tasks_changed.emit()
	completed_tasks_changed.emit()
	if board != null and board.has_method("apply_task_module_runtime_state"):
		board.call("apply_task_module_runtime_state")
	return {"ok": true, "reason": "", "active_count": _active_tasks.size()}

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
	completed_tasks_changed.emit()

func clear_active_tasks(board: BoardCellGenerator = null) -> void:
	if _active_tasks.is_empty() and _completed_cells.is_empty():
		return
	_active_tasks.clear()
	_completed_cells.clear()
	active_tasks_changed.emit()
	completed_tasks_changed.emit()
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
		return ""
	var reward := build_reward_option(PhaseManager.current_level)
	if reward == null:
		return ""
	_special_shop_offer_module_id = reward.task_module_id
	deployment_changed.emit()
	return _special_shop_offer_module_id

func clear_special_shop_offer() -> void:
	if _special_shop_offer_module_id == "" and _special_shop_offer_checks <= 0:
		return
	_special_shop_offer_module_id = ""
	_special_shop_offer_checks = 0
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
	if _inventory.size() >= INVENTORY_LIMIT:
		return {"ok": false, "reason": "Task module inventory is full.", "needs_replace": true}
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
	inventory_changed.emit()
	deployment_changed.emit()
	active_tasks_changed.emit()
	completed_tasks_changed.emit()

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
