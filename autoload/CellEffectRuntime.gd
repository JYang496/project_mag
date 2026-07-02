extends Node

signal inventory_changed
signal pending_changed
signal installed_changed

const RESOURCE_CATALOG := preload("res://autoload/ResourceCatalog.gd")
const EFFECT_DIRECTORY_PATH := "res://data/cell_effects/"
const STATE_PATH := "user://cell_effect_runtime_state.json"
const REWARD_KIND_CELL_EFFECT: StringName = &"cell_effect"

var _definitions_by_id: Dictionary = {}
var _inventory: Dictionary = {}
var _installed: Dictionary = {}
var _pending: Dictionary = {}
var _definition_prepare_result: Dictionary = {"ok": false, "errors": PackedStringArray(), "count": 0}
var _runtime_state_loaded := false

func _ready() -> void:
	if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.connect(_on_phase_changed)

func load_definitions() -> void:
	prepare_definitions(true)

func prepare_definitions(force: bool = false) -> Dictionary:
	if not force and bool(_definition_prepare_result.get("ok", false)):
		_ensure_runtime_state_loaded()
		return _definition_prepare_result.duplicate(true)
	var catalog_result: Dictionary = RESOURCE_CATALOG.collect_startup_catalog_paths(
		"cell_effects",
		EFFECT_DIRECTORY_PATH,
		".tres"
	)
	var errors := PackedStringArray()
	if not bool(catalog_result.get("ok", false)):
		errors.append_array(catalog_result.get("errors", PackedStringArray()))
	var loaded_definitions := {}
	for path in catalog_result.get("paths", PackedStringArray()):
		var definition := load(str(path)) as CellEffectDefinition
		if definition == null:
			errors.append("invalid cell effect resource: %s" % str(path))
			continue
		var effect_id := definition.effect_id.strip_edges()
		if effect_id == "":
			errors.append("cell effect resource missing effect_id: %s" % str(path))
			continue
		if loaded_definitions.has(effect_id):
			errors.append("duplicate effect_id '%s': %s" % [effect_id, str(path)])
			continue
		loaded_definitions[effect_id] = definition
	if loaded_definitions.is_empty():
		errors.append("no cell effect definitions were prepared")
	if not errors.is_empty():
		_definition_prepare_result = _build_prepare_result(false, errors, 0)
		push_error("CellEffectRuntime: failed to prepare definitions: %s" % "; ".join(errors))
		return _definition_prepare_result.duplicate(true)
	_definitions_by_id = loaded_definitions
	_definition_prepare_result = _build_prepare_result(true, errors, _definitions_by_id.size())
	_ensure_runtime_state_loaded()
	return _definition_prepare_result.duplicate(true)

func get_definition_prepare_result() -> Dictionary:
	return _definition_prepare_result.duplicate(true)

func get_definition(effect_id: String) -> CellEffectDefinition:
	var normalized := effect_id.strip_edges()
	return _definitions_by_id.get(normalized, null) as CellEffectDefinition

func get_all_definitions() -> Array[CellEffectDefinition]:
	var output: Array[CellEffectDefinition] = []
	for definition in _definitions_by_id.values():
		if definition is CellEffectDefinition:
			output.append(definition as CellEffectDefinition)
	return output

func get_inventory_snapshot() -> Dictionary:
	return _inventory.duplicate(true)

func get_pending_snapshot() -> Dictionary:
	return _pending.duplicate(true)

func get_installed_snapshot() -> Dictionary:
	return _installed.duplicate(true)

func get_owned_count(effect_id: String) -> int:
	return maxi(int(_inventory.get(effect_id.strip_edges(), 0)), 0)

func get_pending_count(effect_id: String) -> int:
	var count := 0
	var normalized := effect_id.strip_edges()
	for value in _pending.values():
		if str(value) == normalized:
			count += 1
	return count

func get_available_count(effect_id: String) -> int:
	return maxi(get_owned_count(effect_id) - get_pending_count(effect_id), 0)

func get_available_effect_ids_by_rarity(rarity: String) -> PackedStringArray:
	var output := PackedStringArray()
	var normalized_rarity := rarity.strip_edges()
	for effect_id_variant in _inventory.keys():
		var effect_id := str(effect_id_variant)
		var definition := get_definition(effect_id)
		if definition == null or definition.rarity != normalized_rarity:
			continue
		var count := get_available_count(effect_id)
		for _i in range(count):
			output.append(effect_id)
	return output

func consume_available_effects(effect_ids: PackedStringArray) -> Dictionary:
	var required: Dictionary = {}
	for effect_id in effect_ids:
		var normalized := effect_id.strip_edges()
		if get_definition(normalized) == null:
			return {"ok": false, "reason": "Missing cell effect."}
		required[normalized] = int(required.get(normalized, 0)) + 1
	for effect_id in required.keys():
		if get_available_count(str(effect_id)) < int(required[effect_id]):
			return {"ok": false, "reason": "Not enough available cell effects."}
	for effect_id in required.keys():
		var remaining := maxi(int(_inventory.get(str(effect_id), 0)) - int(required[effect_id]), 0)
		if remaining <= 0:
			_inventory.erase(str(effect_id))
		else:
			_inventory[str(effect_id)] = remaining
	save_runtime_state()
	inventory_changed.emit()
	return {"ok": true, "reason": ""}

func consume_available_effects_by_rarity(rarity: String, count: int) -> Dictionary:
	var available := get_available_effect_ids_by_rarity(rarity)
	if available.size() < count:
		return {"ok": false, "reason": "Not enough %s cell effects." % rarity}
	var selected := PackedStringArray()
	for index in range(count):
		selected.append(available[index])
	return consume_available_effects(selected)

func has_pending_edits() -> bool:
	return not _pending.is_empty()

func grant_effect(effect_id: String, amount: int = 1) -> bool:
	var definition := get_definition(effect_id)
	if definition == null:
		push_warning("CellEffectRuntime: cannot grant missing effect '%s'." % effect_id)
		return false
	var normalized := definition.effect_id
	_inventory[normalized] = maxi(int(_inventory.get(normalized, 0)), 0) + maxi(amount, 1)
	save_runtime_state()
	inventory_changed.emit()
	return true

func grant_random_unlocked_effect(level_index: int = 0, amount: int = 1) -> String:
	var rewards := build_reward_options(level_index, 1)
	if rewards.is_empty():
		push_warning("CellEffectRuntime: no unlocked effect available to grant.")
		return ""
	var reward := rewards[0] as RewardInfo
	if reward == null or reward.cell_effect_id.strip_edges() == "":
		push_warning("CellEffectRuntime: random effect reward is invalid.")
		return ""
	var effect_id := reward.cell_effect_id.strip_edges()
	return effect_id if grant_effect(effect_id, amount) else ""

func set_pending_effect(cell_id: int, effect_id: String) -> Dictionary:
	if cell_id <= 0:
		return {"ok": false, "reason": "Invalid cell."}
	var definition := get_definition(effect_id)
	if definition == null:
		return {"ok": false, "reason": "Missing cell effect."}
	var previous_effect := str(_pending.get(str(cell_id), ""))
	if previous_effect == definition.effect_id:
		return {"ok": true, "reason": ""}
	if get_available_count(definition.effect_id) <= 0:
		return {"ok": false, "reason": "No available copies."}
	_pending[str(cell_id)] = definition.effect_id
	save_runtime_state()
	pending_changed.emit()
	return {"ok": true, "reason": ""}

func can_swap_installed_effects(from_cell_id: int, to_cell_id: int) -> Dictionary:
	if from_cell_id <= 0 or to_cell_id <= 0:
		return {"ok": false, "reason": "Invalid cell."}
	if from_cell_id == to_cell_id:
		return {"ok": false, "reason": "Same cell."}
	var from_key := str(from_cell_id)
	var to_key := str(to_cell_id)
	if _pending.has(from_key) or _pending.has(to_key):
		return {"ok": false, "reason": "Finish or cancel pending edits on these cells first."}
	var from_effect_id := str(_installed.get(from_key, ""))
	if from_effect_id == "":
		return {"ok": false, "reason": "Source cell has no installed effect."}
	var from_definition := get_definition(from_effect_id)
	if from_definition == null:
		return {"ok": false, "reason": "Source effect is missing."}
	if not from_definition.can_swap_installed:
		return {"ok": false, "reason": "This effect cannot be swapped."}
	var to_effect_id := str(_installed.get(to_key, ""))
	if to_effect_id != "":
		var to_definition := get_definition(to_effect_id)
		if to_definition == null:
			return {"ok": false, "reason": "Target effect is missing."}
		if not to_definition.can_swap_installed:
			return {"ok": false, "reason": "Target effect cannot be swapped."}
	return {"ok": true, "reason": ""}

func swap_installed_effects(from_cell_id: int, to_cell_id: int) -> Dictionary:
	var validation := can_swap_installed_effects(from_cell_id, to_cell_id)
	if not bool(validation.get("ok", false)):
		return validation
	var from_key := str(from_cell_id)
	var to_key := str(to_cell_id)
	var from_effect_id := str(_installed.get(from_key, ""))
	var to_effect_id := str(_installed.get(to_key, ""))
	if to_effect_id == "":
		_installed.erase(from_key)
	else:
		_installed[from_key] = to_effect_id
	_installed[to_key] = from_effect_id
	save_runtime_state()
	installed_changed.emit()
	return {"ok": true, "reason": ""}

func remove_pending_for_cell(cell_id: int) -> void:
	if _pending.erase(str(cell_id)):
		save_runtime_state()
		pending_changed.emit()

func clear_pending() -> void:
	if _pending.is_empty():
		return
	_pending.clear()
	save_runtime_state()
	pending_changed.emit()

func get_effect_for_cell(cell_id: int, include_pending: bool = true) -> String:
	var key := str(cell_id)
	if include_pending and _pending.has(key):
		return str(_pending[key])
	return str(_installed.get(key, ""))

func commit_pending(board: Node = null) -> bool:
	if _pending.is_empty():
		return true
	for cell_key in _pending.keys():
		var effect_id := str(_pending[cell_key])
		if get_definition(effect_id) == null:
			continue
		if get_owned_count(effect_id) <= 0:
			push_warning("CellEffectRuntime: skipping commit without inventory for '%s'." % effect_id)
			continue
		_inventory[effect_id] = maxi(int(_inventory.get(effect_id, 0)) - 1, 0)
		if int(_inventory[effect_id]) <= 0:
			_inventory.erase(effect_id)
		_installed[str(cell_key)] = effect_id
	_pending.clear()
	save_runtime_state()
	inventory_changed.emit()
	pending_changed.emit()
	installed_changed.emit()
	if board != null and board.has_method("apply_cell_effect_runtime_state"):
		board.call("apply_cell_effect_runtime_state", false)
	return true

func build_pending_commit_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for cell_key in _pending.keys():
		var new_effect := get_definition(str(_pending[cell_key]))
		if new_effect == null:
			continue
		var old_effect := get_definition(str(_installed.get(str(cell_key), "")))
		var line := "Cell %s: install %s" % [str(cell_key), new_effect.get_display_name()]
		if old_effect != null:
			line += " over %s" % old_effect.get_display_name()
			if old_effect.get_family_id() == new_effect.get_family_id() and int(new_effect.tier) < int(old_effect.tier):
				line += " (downgrade)"
		lines.append(line)
	return lines

func build_reward_options(level_index: int, option_count: int = 3) -> Array[RewardInfo]:
	var available_families: Dictionary = {}
	var level_one_based := maxi(level_index + 1, 1)
	for definition in get_all_definitions():
		if int(definition.unlock_level) > level_one_based:
			continue
		if definition.get_reward_weight() <= 0.0:
			continue
		var family := definition.get_family_id()
		if not available_families.has(family):
			available_families[family] = []
		var family_defs: Array = available_families[family]
		family_defs.append(definition)
		available_families[family] = family_defs
	var selected_families := _pick_weighted_families(available_families, option_count)
	var rewards: Array[RewardInfo] = []
	for family_id in selected_families:
		var defs: Array = available_families.get(family_id, [])
		var definition := _pick_weighted_definition(defs)
		if definition == null:
			continue
		var reward := RewardInfo.new()
		reward.reward_kind = REWARD_KIND_CELL_EFFECT
		reward.cell_effect_id = definition.effect_id
		reward.rarity = definition.rarity
		reward.reward_key_override = "cell_effect:%s" % definition.effect_id
		rewards.append(reward)
	return rewards

func apply_to_board(board: Node, include_pending_preview: bool = true) -> void:
	if board != null and board.has_method("apply_cell_effect_runtime_state"):
		board.call("apply_cell_effect_runtime_state", include_pending_preview)

func save_runtime_state() -> void:
	var payload := {
		"inventory": _inventory,
		"installed": _installed,
		"pending": _pending,
	}
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))

func load_runtime_state() -> void:
	var payload := _read_json_dictionary(STATE_PATH)
	if payload.is_empty():
		_runtime_state_loaded = true
		return
	_inventory = _sanitize_effect_count_dictionary(payload.get("inventory", {}))
	_installed = _sanitize_cell_effect_dictionary(payload.get("installed", {}))
	_pending = _sanitize_cell_effect_dictionary(payload.get("pending", {}))
	_runtime_state_loaded = true
	inventory_changed.emit()
	pending_changed.emit()
	installed_changed.emit()

func reset_runtime_state() -> void:
	_inventory.clear()
	_installed.clear()
	_pending.clear()
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
	_runtime_state_loaded = true
	inventory_changed.emit()
	pending_changed.emit()
	installed_changed.emit()

func _ensure_runtime_state_loaded() -> void:
	if _runtime_state_loaded:
		return
	load_runtime_state()

func _pick_weighted_families(families: Dictionary, option_count: int) -> PackedStringArray:
	var remaining := families.keys()
	var selected := PackedStringArray()
	while selected.size() < option_count and not remaining.is_empty():
		var total_weight := 0.0
		for family in remaining:
			total_weight += _get_family_weight(families.get(family, []))
		if total_weight <= 0.0:
			break
		var roll := randf() * total_weight
		var selected_family := str(remaining[0])
		for family in remaining:
			roll -= _get_family_weight(families.get(family, []))
			if roll <= 0.0:
				selected_family = str(family)
				break
		selected.append(selected_family)
		remaining.erase(selected_family)
	return selected

func _get_family_weight(definitions: Array) -> float:
	var total := 0.0
	for definition in definitions:
		var effect_def := definition as CellEffectDefinition
		if effect_def:
			total += effect_def.get_reward_weight()
	return total

func _pick_weighted_definition(definitions: Array) -> CellEffectDefinition:
	var total_weight := _get_family_weight(definitions)
	if total_weight <= 0.0:
		return null
	var roll := randf() * total_weight
	for definition in definitions:
		var effect_def := definition as CellEffectDefinition
		if effect_def == null:
			continue
		roll -= effect_def.get_reward_weight()
		if roll <= 0.0:
			return effect_def
	return definitions[0] as CellEffectDefinition if not definitions.is_empty() else null

func _sanitize_effect_count_dictionary(raw: Variant) -> Dictionary:
	var output := {}
	if not (raw is Dictionary):
		return output
	for key in (raw as Dictionary).keys():
		var effect_id := str(key)
		if get_definition(effect_id) == null:
			push_warning("CellEffectRuntime: dropping missing saved effect '%s'." % effect_id)
			continue
		var count := maxi(int((raw as Dictionary)[key]), 0)
		if count > 0:
			output[effect_id] = count
	return output

func _sanitize_cell_effect_dictionary(raw: Variant) -> Dictionary:
	var output := {}
	if not (raw is Dictionary):
		return output
	for key in (raw as Dictionary).keys():
		var effect_id := str((raw as Dictionary)[key])
		if get_definition(effect_id) == null:
			push_warning("CellEffectRuntime: dropping missing saved cell effect '%s'." % effect_id)
			continue
		var cell_id := int(str(key))
		if cell_id <= 0:
			continue
		output[str(cell_id)] = effect_id
	return output

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.GAMEOVER:
		reset_runtime_state()

func _build_prepare_result(ok: bool, errors: PackedStringArray, count: int) -> Dictionary:
	return {
		"ok": ok,
		"errors": errors,
		"count": count,
	}
