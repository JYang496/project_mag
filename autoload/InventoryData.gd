extends Node

signal temporary_modules_changed
signal pending_transactions_changed
signal weapon_storage_changed
signal weapon_cores_changed
signal weapon_fusion_changed(weapon: Weapon, result: Dictionary)

const RUNTIME_STATE_PATH := "user://equipment_runtime_state.json"

var temporary_modules: Array[Module] = []
var weapon_storage: Array[Weapon] = []
var ready_to_sell_list: Array[Weapon] = []
var pending_transactions: Array[Dictionary] = []
var weapon_core_inventory: Dictionary = {}
var _fusion_commit_locks: Dictionary = {}
var on_select_upg: Weapon

func _ready() -> void:
	call_deferred("load_runtime_state")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_runtime_state()

func _get_ui():
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui):
		return ui
	return null

func _refresh_ui() -> void:
	var ui = _get_ui()
	if ui == null:
		return
	if ui.module_warehouse_controller:
		ui.module_warehouse_controller.update_modules()
	if ui.purchase_management_controller:
		ui.purchase_management_controller.update_shop()
	if ui.upgrade_management_controller:
		ui.upgrade_management_controller.update_upg()
	if ui.has_method("refresh_border"):
		ui.refresh_border()

func _notify(message: String, duration: float = 1.8) -> void:
	var ui = _get_ui()
	if ui and ui.has_method("show_item_message"):
		ui.show_item_message(message, duration)

func _is_rest_area_module_management_available() -> bool:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return false
	for node in get_tree().get_nodes_in_group("rest_area"):
		if node and is_instance_valid(node) and node.has_method("is_module_management_available"):
			if bool(node.call("is_module_management_available")):
				return true
	return false

func get_all_owned_modules() -> Array[Module]:
	var result: Array[Module] = []
	for module_instance in temporary_modules:
		if module_instance and is_instance_valid(module_instance):
			result.append(module_instance)
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon) or weapon.modules == null:
			continue
		for child in weapon.modules.get_children():
			var module_instance := child as Module
			if module_instance:
				result.append(module_instance)
	for weapon in weapon_storage:
		if weapon == null or not is_instance_valid(weapon) or weapon.modules == null:
			continue
		for child in weapon.modules.get_children():
			var module_instance := child as Module
			if module_instance:
				result.append(module_instance)
	return result

func get_stored_weapons() -> Array[Weapon]:
	var result: Array[Weapon] = []
	for weapon in weapon_storage:
		if weapon and is_instance_valid(weapon):
			result.append(weapon)
	return result

func normalize_core_tags(values: Variant) -> Array[StringName]:
	var normalized := BuildTag.normalize_array(values)
	normalized.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return normalized

func get_core_key(values: Variant) -> String:
	var parts := PackedStringArray()
	for tag in normalize_core_tags(values):
		parts.append(str(tag))
	return ",".join(parts)

func get_weapon_core_stacks() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var keys := weapon_core_inventory.keys()
	keys.sort()
	for key_variant in keys:
		var key := str(key_variant)
		var entry := weapon_core_inventory.get(key, {}) as Dictionary
		var count := maxi(int(entry.get("count", 0)), 0)
		if count <= 0:
			continue
		output.append({
			"key": key,
			"tags": normalize_core_tags(entry.get("tags", [])),
			"count": count,
		})
	return output

func get_weapon_core_count(values: Variant) -> int:
	var key := get_core_key(values)
	if key == "":
		return 0
	return maxi(int((weapon_core_inventory.get(key, {}) as Dictionary).get("count", 0)), 0)

func find_weapon_cores_containing_tag(tag: Variant) -> Array[Dictionary]:
	var normalized_tag := BuildTag.normalize(tag)
	if normalized_tag == StringName():
		return []
	var output: Array[Dictionary] = []
	for stack in get_weapon_core_stacks():
		if (stack.get("tags", []) as Array).has(normalized_tag):
			output.append(stack)
	return output

func add_weapon_cores(values: Variant, amount: int = 1, save_after: bool = true) -> Dictionary:
	var tags := normalize_core_tags(values)
	var key := get_core_key(tags)
	var safe_amount := maxi(amount, 0)
	if key == "" or safe_amount <= 0:
		return {"ok": false, "result": "invalid_core", "core_key": key, "core_tags": tags}
	var next_count := get_weapon_core_count(tags) + safe_amount
	weapon_core_inventory[key] = {"tags": tags, "count": next_count}
	weapon_cores_changed.emit()
	if save_after:
		save_runtime_state()
	return {"ok": true, "result": "core_added", "core_key": key, "core_tags": tags, "core_count": next_count}

func remove_weapon_cores(values: Variant, amount: int = 1, save_after: bool = true) -> bool:
	var tags := normalize_core_tags(values)
	var key := get_core_key(tags)
	var safe_amount := maxi(amount, 0)
	var current := get_weapon_core_count(tags)
	if key == "" or safe_amount <= 0 or current < safe_amount:
		return false
	var next_count := current - safe_amount
	if next_count <= 0:
		weapon_core_inventory.erase(key)
	else:
		weapon_core_inventory[key] = {"tags": tags, "count": next_count}
	weapon_cores_changed.emit()
	if save_after:
		save_runtime_state()
	return true

func build_duplicate_weapon_core_preview(weapon_id: String) -> Dictionary:
	var normalized_id := str(weapon_id).strip_edges()
	var weapon_def := DataHandler.read_weapon_data(normalized_id) as WeaponDefinition
	if weapon_def == null:
		return {"ok": false, "result": "invalid", "weapon_id": normalized_id}
	var unknown_tags := weapon_def.get_unknown_core_tags()
	var tags := weapon_def.get_normalized_core_tags()
	if not unknown_tags.is_empty() or tags.is_empty():
		return {
			"ok": false,
			"result": "invalid_core_tags",
			"weapon_id": normalized_id,
			"unknown_tags": unknown_tags,
		}
	var current_count := get_weapon_core_count(tags)
	return {
		"ok": true,
		"result": "dismantled_to_core",
		"weapon_id": normalized_id,
		"core_amount": 1,
		"core_key": get_core_key(tags),
		"core_tags": tags,
		"current_core_count": current_count,
		"core_count": current_count + 1,
		"resulting_core_count": current_count + 1,
		"usable_branches": get_fusion_branch_usages_for_core(tags),
	}

func get_fusion_branch_usages_for_core(values: Variant) -> Array[Dictionary]:
	var tags := normalize_core_tags(values)
	var output: Array[Dictionary] = []
	if tags.is_empty():
		return output
	DataHandler.load_weapon_branch_data()
	var scene_paths := GlobalVariables.weapon_branch_list.keys()
	scene_paths.sort()
	for scene_path_variant in scene_paths:
		var scene_path := str(scene_path_variant)
		for branch_variant in GlobalVariables.weapon_branch_list.get(scene_path, []):
			var branch := branch_variant as WeaponBranchDefinition
			if branch == null:
				continue
			var recipe := branch.get_normalized_fusion_required_tags()
			var contributed: Array[StringName] = []
			for tag in tags:
				if recipe.has(tag):
					contributed.append(tag)
			if contributed.is_empty():
				continue
			output.append({
				"weapon_id": DataHandler.get_weapon_id_from_scene_path(scene_path),
				"branch_id": str(branch.branch_id),
				"required_tags": recipe,
				"contributed_tags": contributed,
			})
	return output

func dismantle_duplicate_weapon(weapon_id: String, subject: Weapon = null) -> Dictionary:
	var preview := build_duplicate_weapon_core_preview(weapon_id)
	if not bool(preview.get("ok", false)):
		push_warning("Unable to dismantle duplicate weapon id=%s: %s" % [weapon_id, str(preview.get("result", "invalid"))])
		return preview
	var added := add_weapon_cores(preview.get("core_tags", []), 1, false)
	if not bool(added.get("ok", false)):
		return added
	PlayerData.record_weapon_progress()
	save_runtime_state()
	_refresh_ui()
	return {
		"ok": true,
		"result": "dismantled_to_core",
		"weapon_id": str(weapon_id),
		"weapon": subject,
		"core_key": str(added.get("core_key", "")),
		"core_tags": added.get("core_tags", []),
		"core_count": int(added.get("core_count", 0)),
	}

func preview_weapon_fusion(weapon: Weapon, branch_id: String, selected_core_keys: Array) -> Dictionary:
	var result := {
		"ok": false,
		"reason_code": "invalid_weapon",
		"target_fuse": 0,
		"required_level": 0,
		"required_core_count": 0,
		"level_ok": false,
		"core_count_ok": false,
		"tags_ok": false,
		"branch_ok": false,
		"required_tags": [],
		"covered_tags": [],
		"missing_tags": [],
		"unrelated_core_keys": [],
		"invalid_core_keys": [],
	}
	if weapon == null or not is_instance_valid(weapon):
		return result
	if not _is_owned_weapon(weapon):
		result["reason_code"] = "weapon_not_owned"
		return result
	var current_fuse := int(weapon.fuse)
	if current_fuse >= Weapon.MAX_FUSE_LEVEL:
		result["reason_code"] = "fusion_maxed"
		return result
	var target_fuse := current_fuse + 1
	if target_fuse not in [2, 3]:
		result["reason_code"] = "invalid_target_fuse"
		return result
	var required_level := 3 if target_fuse == 2 else 6
	var required_count := 2 if target_fuse == 2 else 3
	result["target_fuse"] = target_fuse
	result["required_level"] = required_level
	result["required_core_count"] = required_count
	result["level_ok"] = int(weapon.level) >= required_level
	var resolved_branch_id := str(branch_id).strip_edges()
	var branch_def: WeaponBranchDefinition = null
	if target_fuse == 2:
		branch_def = DataHandler.read_weapon_branch_definition(weapon.scene_file_path, resolved_branch_id)
		if branch_def == null:
			result["reason_code"] = "branch_not_found"
			return result
		if int(branch_def.unlock_fuse) > target_fuse or not weapon.branch_runtime.is_branch_compatible_with_existing(branch_def):
			result["reason_code"] = "branch_not_available"
			return result
	else:
		if weapon.branch_runtime.branch_ids.size() != 1:
			result["reason_code"] = "branch_not_available"
			return result
		var existing_branch_id := str(weapon.branch_runtime.branch_ids[0])
		if resolved_branch_id == "":
			resolved_branch_id = existing_branch_id
		if resolved_branch_id != existing_branch_id:
			result["reason_code"] = "branch_mismatch"
			return result
		if weapon.branch_runtime.is_branch_enhanced(resolved_branch_id):
			result["reason_code"] = "branch_already_enhanced"
			return result
		branch_def = DataHandler.read_weapon_branch_definition(weapon.scene_file_path, resolved_branch_id)
		if branch_def == null:
			result["reason_code"] = "branch_not_found"
			return result
	result["branch_id"] = resolved_branch_id
	result["branch_ok"] = true
	var required_tags := branch_def.get_normalized_fusion_required_tags()
	result["required_tags"] = required_tags
	var selected_counts: Dictionary = {}
	var covered: Array[StringName] = []
	var unrelated := PackedStringArray()
	var invalid := PackedStringArray()
	for key_variant in selected_core_keys:
		var key := str(key_variant).strip_edges()
		selected_counts[key] = int(selected_counts.get(key, 0)) + 1
		var entry := weapon_core_inventory.get(key, {}) as Dictionary
		if key == "" or entry.is_empty() or int(selected_counts[key]) > int(entry.get("count", 0)):
			if not invalid.has(key):
				invalid.append(key)
			continue
		var tags := normalize_core_tags(entry.get("tags", []))
		var contributes := false
		for tag in tags:
			if required_tags.has(tag):
				contributes = true
				if not covered.has(tag):
					covered.append(tag)
		if not contributes and not unrelated.has(key):
			unrelated.append(key)
	covered.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	var missing: Array[StringName] = []
	for required_tag in required_tags:
		if not covered.has(required_tag):
			missing.append(required_tag)
	result["covered_tags"] = covered
	result["missing_tags"] = missing
	result["unrelated_core_keys"] = unrelated
	result["invalid_core_keys"] = invalid
	result["core_count_ok"] = selected_core_keys.size() == required_count and invalid.is_empty()
	result["tags_ok"] = missing.is_empty() and unrelated.is_empty() and not required_tags.is_empty()
	if not bool(result["level_ok"]):
		result["reason_code"] = "level_too_low"
	elif not invalid.is_empty():
		result["reason_code"] = "core_missing"
	elif selected_core_keys.size() != required_count:
		result["reason_code"] = "core_count_mismatch"
	elif not unrelated.is_empty():
		result["reason_code"] = "core_unrelated"
	elif not missing.is_empty():
		result["reason_code"] = "tags_missing"
	else:
		result["ok"] = true
		result["reason_code"] = "ready"
	return result

func commit_weapon_fusion(weapon: Weapon, branch_id: String, selected_core_keys: Array) -> Dictionary:
	if weapon == null or not is_instance_valid(weapon):
		return preview_weapon_fusion(weapon, branch_id, selected_core_keys)
	var lock_key := weapon.get_instance_id()
	if _fusion_commit_locks.has(lock_key):
		return {"ok": false, "reason_code": "fusion_in_progress", "target_fuse": int(weapon.fuse) + 1}
	_fusion_commit_locks[lock_key] = true
	var preview := preview_weapon_fusion(weapon, branch_id, selected_core_keys)
	if not bool(preview.get("ok", false)):
		_fusion_commit_locks.erase(lock_key)
		return preview
	var old_fuse := int(weapon.fuse)
	var old_branch_ids := weapon.branch_runtime.branch_ids.duplicate()
	var old_enhanced_branch_id := str(weapon.branch_runtime.enhanced_branch_id)
	var target_fuse := int(preview.get("target_fuse", old_fuse + 1))
	var resolved_branch_id := str(preview.get("branch_id", ""))
	weapon.fuse = target_fuse
	var applied := weapon.branch_runtime.add_branch(resolved_branch_id) if target_fuse == 2 \
		else weapon.branch_runtime.set_enhanced_branch(resolved_branch_id)
	if not applied or not _consume_core_selection_unchecked(selected_core_keys):
		weapon.fuse = old_fuse
		weapon.branch_runtime.restore_branch_ids(old_branch_ids)
		weapon.branch_runtime.restore_enhanced_branch(old_enhanced_branch_id)
		_fusion_commit_locks.erase(lock_key)
		return {"ok": false, "reason_code": "commit_failed", "target_fuse": target_fuse}
	weapon_cores_changed.emit()
	PlayerData.record_weapon_progress()
	if weapon_storage.has(weapon):
		weapon_storage_changed.emit()
	else:
		PlayerData.notify_weapon_list_changed()
	var committed := preview.duplicate(true)
	committed["ok"] = true
	committed["reason_code"] = "fused"
	committed["from_fuse"] = old_fuse
	committed["weapon"] = weapon
	committed["enhanced"] = target_fuse == 3
	save_runtime_state()
	weapon_fusion_changed.emit(weapon, committed)
	_fusion_commit_locks.erase(lock_key)
	return committed

func _consume_core_selection_unchecked(selected_core_keys: Array) -> bool:
	var requested: Dictionary = {}
	for key_variant in selected_core_keys:
		var key := str(key_variant).strip_edges()
		requested[key] = int(requested.get(key, 0)) + 1
	for key in requested:
		var entry := weapon_core_inventory.get(key, {}) as Dictionary
		if entry.is_empty() or int(entry.get("count", 0)) < int(requested[key]):
			return false
	for key in requested:
		var entry := weapon_core_inventory.get(key, {}) as Dictionary
		var remaining := int(entry.get("count", 0)) - int(requested[key])
		if remaining <= 0:
			weapon_core_inventory.erase(key)
		else:
			entry["count"] = remaining
			weapon_core_inventory[key] = entry
	return true

func _is_owned_weapon(weapon: Weapon) -> bool:
	return weapon_storage.has(weapon) or PlayerData.player_weapon_list.has(weapon)

func obtain_weapon_reward(weapon: Weapon, on_pending_complete: Callable = Callable()) -> Dictionary:
	if weapon == null or not is_instance_valid(weapon):
		return {"ok": false, "result": "invalid"}
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	if weapon_id == "":
		weapon.queue_free()
		return {"ok": false, "result": "invalid"}
	if PlayerData.player and is_instance_valid(PlayerData.player):
		var equipped_result: Dictionary = PlayerData.player.try_weapon_obtain_conversion(weapon_id)
		if str(equipped_result.get("result", "")) != "not_applicable":
			weapon.queue_free()
			return equipped_result
	var stored_match := _find_stored_weapon_by_id(weapon_id)
	if stored_match:
		var stored_result := _merge_stored_weapon_duplicate(stored_match)
		weapon.queue_free()
		return stored_result
	if PlayerData.player and is_instance_valid(PlayerData.player) and has_open_weapon_slot():
		return equip_incoming_weapon_to_slot(weapon)
	if PhaseManager.current_state() not in [PhaseManager.SETTLEMENT, PhaseManager.REST]:
		return store_weapon(weapon)
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("request_weapon_replacement"):
		var opened := bool(ui.call("request_weapon_replacement", weapon, false, on_pending_complete))
		if opened:
			return {"ok": true, "result": "selection_pending", "weapon": weapon}
	return store_weapon(weapon)

func has_open_weapon_slot() -> bool:
	return PlayerData.player_weapon_list.size() < PlayerData.max_weapon_num

func settle_unclaimed_weapon_reward(weapon: Weapon) -> Dictionary:
	if weapon == null or not is_instance_valid(weapon):
		return {"ok": false, "result": "invalid"}
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	if weapon_id == "":
		weapon.queue_free()
		return {"ok": false, "result": "invalid"}
	if PlayerData.player and is_instance_valid(PlayerData.player):
		var equipped_result: Dictionary = PlayerData.player.try_weapon_obtain_conversion(weapon_id)
		if str(equipped_result.get("result", "")) != "not_applicable":
			weapon.queue_free()
			return equipped_result
	var stored_match := _find_stored_weapon_by_id(weapon_id)
	if stored_match:
		var stored_result := _merge_stored_weapon_duplicate(stored_match)
		weapon.queue_free()
		return stored_result
	return store_weapon(weapon)

func store_weapon(weapon: Weapon) -> Dictionary:
	if weapon == null or not is_instance_valid(weapon):
		return {"ok": false, "result": "invalid"}
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	if PlayerData.player_weapon_list.has(weapon):
		if PlayerData.player_weapon_list.size() <= 1:
			return {"ok": false, "reason": "At least one weapon must remain equipped."}
		_transfer_weapon_modules_to_temporary(weapon)
		_move_weapon_to_parent(weapon, self)
		PlayerData.player_weapon_list.erase(weapon)
		PlayerData.sanitize_main_weapon_index()
		if PlayerData.player and PlayerData.player.has_method("_apply_weapon_roles"):
			PlayerData.player.call("_apply_weapon_roles")
		PlayerData.notify_weapon_list_changed()
	else:
		_transfer_weapon_modules_to_temporary(weapon)
		_move_weapon_to_parent(weapon, self)
	weapon.visible = false
	weapon.process_mode = Node.PROCESS_MODE_DISABLED
	weapon_storage.append(weapon)
	weapon_storage_changed.emit()
	save_runtime_state()
	_refresh_ui()
	_notify(LocalizationManager.tr_format(
		"ui.inventory.weapon_stored",
		{"name": LocalizationManager.get_weapon_name_by_id(weapon_id, weapon.name)},
		"Stored %s in the weapon warehouse" % LocalizationManager.get_weapon_name_by_id(weapon_id, weapon.name)
	))
	PlayerData.record_weapon_progress()
	return {"ok": true, "result": "stored", "weapon": weapon}

func equip_stored_weapon(weapon: Weapon) -> Dictionary:
	if not PhaseManager.can_configure_loadout():
		return {"ok": false, "reason": "Stored weapons can only be equipped during rest."}
	if weapon == null or not weapon_storage.has(weapon):
		return {"ok": false, "reason": "Invalid stored weapon."}
	if PlayerData.player_weapon_list.size() >= PlayerData.max_weapon_num:
		return {"ok": false, "reason": "No weapon slots available."}
	weapon_storage.erase(weapon)
	weapon.visible = true
	weapon.process_mode = Node.PROCESS_MODE_INHERIT
	PlayerData.player.create_weapon(weapon)
	weapon_storage_changed.emit()
	save_runtime_state()
	return {"ok": true, "result": "equipped", "weapon": weapon}

func exchange_stored_weapon(stored_weapon: Weapon, equipped_weapon: Weapon) -> Dictionary:
	if not PhaseManager.can_configure_loadout():
		return {"ok": false, "reason": "Stored weapons can only be exchanged during rest."}
	if stored_weapon == null or equipped_weapon == null:
		return {"ok": false, "reason": "Invalid weapon."}
	if not weapon_storage.has(stored_weapon) or not PlayerData.player_weapon_list.has(equipped_weapon):
		return {"ok": false, "reason": "Invalid weapon."}
	var slot_index := PlayerData.player_weapon_list.find(equipped_weapon)
	var holder := equipped_weapon.get_parent()
	_transfer_weapon_modules_to_temporary(equipped_weapon)
	weapon_storage.erase(stored_weapon)
	_move_weapon_to_parent(stored_weapon, holder)
	stored_weapon.visible = true
	stored_weapon.process_mode = Node.PROCESS_MODE_INHERIT
	stored_weapon.position = Vector2.ZERO
	_move_weapon_to_parent(equipped_weapon, self)
	equipped_weapon.visible = false
	equipped_weapon.process_mode = Node.PROCESS_MODE_DISABLED
	weapon_storage.append(equipped_weapon)
	PlayerData.player_weapon_list[slot_index] = stored_weapon
	if PlayerData.player and PlayerData.player.has_method("_apply_weapon_roles"):
		PlayerData.player.call("_apply_weapon_roles")
	PlayerData.notify_weapon_list_changed()
	weapon_storage_changed.emit()
	save_runtime_state()
	_refresh_ui()
	return {"ok": true, "result": "exchanged", "weapon": stored_weapon, "slot": slot_index}

func equip_incoming_weapon_to_slot(new_weapon: Weapon, old_weapon: Weapon = null) -> Dictionary:
	var battle_pickup_to_empty_slot := PhaseManager.current_state() == PhaseManager.BATTLE and old_weapon == null
	if PhaseManager.current_state() not in [PhaseManager.SETTLEMENT, PhaseManager.REST] \
			and not battle_pickup_to_empty_slot:
		return {"ok": false, "reason": "New weapons can only be installed during settlement or rest."}
	if new_weapon == null or not is_instance_valid(new_weapon):
		return {"ok": false, "reason": "Invalid weapon."}
	if old_weapon == null:
		if PlayerData.player_weapon_list.size() >= PlayerData.max_weapon_num:
			return {"ok": false, "reason": "No weapon slots available."}
		PlayerData.player.create_weapon(new_weapon)
		return {"ok": true, "result": "equipped", "weapon": new_weapon}
	if not PlayerData.player_weapon_list.has(old_weapon):
		return {"ok": false, "reason": "Invalid weapon."}
	var slot_index := PlayerData.player_weapon_list.find(old_weapon)
	var holder := old_weapon.get_parent()
	_transfer_weapon_modules_to_temporary(old_weapon)
	_move_weapon_to_parent(new_weapon, holder)
	new_weapon.position = Vector2.ZERO
	_move_weapon_to_parent(old_weapon, self)
	old_weapon.visible = false
	old_weapon.process_mode = Node.PROCESS_MODE_DISABLED
	weapon_storage.append(old_weapon)
	PlayerData.player_weapon_list[slot_index] = new_weapon
	if PlayerData.player and PlayerData.player.has_method("_apply_weapon_roles"):
		PlayerData.player.call("_apply_weapon_roles")
	PlayerData.notify_weapon_list_changed()
	weapon_storage_changed.emit()
	save_runtime_state()
	_refresh_ui()
	return {"ok": true, "result": "exchanged", "weapon": new_weapon, "slot": slot_index}

func _move_weapon_to_parent(weapon: Weapon, target_parent: Node) -> void:
	if weapon.get_parent() == target_parent:
		return
	if weapon.get_parent():
		weapon.reparent(target_parent)
	else:
		target_parent.add_child(weapon)

func _find_stored_weapon_by_id(weapon_id: String) -> Weapon:
	for weapon in weapon_storage:
		if weapon and is_instance_valid(weapon) \
				and DataHandler.get_weapon_id_from_instance(weapon) == weapon_id:
			return weapon
	return null

func _merge_stored_weapon_duplicate(weapon: Weapon) -> Dictionary:
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	return dismantle_duplicate_weapon(weapon_id, weapon)

func find_owned_module_by_scene_path(scene_path: String, ignore_module: Module = null) -> Module:
	var normalized := scene_path.strip_edges()
	if normalized == "":
		return null
	for module_instance in get_all_owned_modules():
		if module_instance == ignore_module:
			continue
		if str(module_instance.scene_file_path) == normalized:
			return module_instance
	return null

func get_weapon_module_assignment_feedback(
	module_instance: Module,
	weapon: Weapon,
	replaced_module: Module = null,
	allow_reward_transaction: bool = false
) -> Dictionary:
	if module_instance == null or not is_instance_valid(module_instance):
		return {"ok": false, "reason": "Invalid module."}
	if weapon == null or not is_instance_valid(weapon):
		return {"ok": false, "reason": "Invalid weapon."}
	if not allow_reward_transaction and not _is_rest_area_module_management_available():
		return {"ok": false, "reason": "Modules can only be managed in the Rest Area."}
	if weapon.modules == null:
		return {"ok": false, "reason": "Weapon has no module container."}
	var duplicate_module := find_owned_module_by_scene_path(str(module_instance.scene_file_path), module_instance)
	if duplicate_module != null and duplicate_module != replaced_module:
		return {"ok": false, "reason": "Only one module of each type can be owned."}
	var projected_count := weapon.get_module_count()
	if replaced_module != null and replaced_module.get_parent() == weapon.modules:
		projected_count -= 1
	if projected_count >= weapon.module_slot_capacity:
		return {"ok": false, "reason": "No module slots available."}
	var reason := str(module_instance.get_incompatibility_reason(weapon))
	if reason != "":
		return {"ok": false, "reason": reason}
	return {"ok": true, "reason": ""}

func can_assign_module_to_any_equipped_weapon(
	module_instance: Module,
	allow_reward_transaction: bool = false
) -> bool:
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon):
			continue
		if bool(get_weapon_module_assignment_feedback(
			module_instance, weapon, null, allow_reward_transaction
		).get("ok", false)):
			return true
		for equipped_module in weapon.get_equipped_modules():
			if bool(get_weapon_module_assignment_feedback(
				module_instance, weapon, equipped_module, allow_reward_transaction
			).get("ok", false)):
				return true
	return false

func equip_module_to_weapon(
	module_instance: Module,
	weapon: Weapon,
	replaced_module: Module = null,
	allow_reward_transaction: bool = false
) -> Dictionary:
	var feedback := get_weapon_module_assignment_feedback(
		module_instance,
		weapon,
		replaced_module,
		allow_reward_transaction
	)
	if not feedback.get("ok", false):
		return feedback
	if replaced_module != null:
		var remove_result := move_module_to_temporary(replaced_module, weapon, allow_reward_transaction)
		if not remove_result.get("ok", false):
			return remove_result
	temporary_modules.erase(module_instance)
	if module_instance.get_parent() != null:
		module_instance.reparent(weapon.modules)
	else:
		weapon.modules.add_child(module_instance)
	module_instance.bind_to_weapon(weapon)
	if weapon.has_method("calculate_status"):
		weapon.calculate_status()
	temporary_modules_changed.emit()
	_refresh_ui()
	return {"ok": true, "reason": ""}

func unequip_module_from_weapon(module_instance: Module, weapon: Weapon) -> Dictionary:
	return move_module_to_temporary(module_instance, weapon, false)

func move_module_to_temporary(
	module_instance: Module,
	weapon: Weapon = null,
	allow_reward_transaction: bool = false
) -> Dictionary:
	if module_instance == null or not is_instance_valid(module_instance):
		return {"ok": false, "reason": "Invalid module."}
	if not allow_reward_transaction and not _is_rest_area_module_management_available():
		return {"ok": false, "reason": "Modules can only be managed in the Rest Area."}
	if weapon != null and (weapon.modules == null or module_instance.get_parent() != weapon.modules):
		return {"ok": false, "reason": "Module is not equipped."}
	var existing := find_owned_module_by_scene_path(str(module_instance.scene_file_path), module_instance)
	if existing != null:
		return _merge_duplicate_module(existing, module_instance)
	module_instance.unbind_from_weapon()
	if module_instance.get_parent() != self:
		if module_instance.get_parent() != null:
			module_instance.reparent(self)
		else:
			add_child(module_instance)
	if not temporary_modules.has(module_instance):
		temporary_modules.append(module_instance)
	_sort_temporary_modules()
	if weapon and weapon.has_method("calculate_status"):
		weapon.calculate_status()
	temporary_modules_changed.emit()
	_refresh_ui()
	return {"ok": true, "reason": ""}

func obtain_module(module_instance: Module, _ignore_weapon: Weapon = null) -> Dictionary:
	if module_instance == null or not is_instance_valid(module_instance):
		return {"ok": false, "reason": "Invalid module."}
	module_instance.set_module_level(module_instance.module_level)
	var existing := find_owned_module_by_scene_path(str(module_instance.scene_file_path), module_instance)
	if existing != null:
		return _merge_duplicate_module(existing, module_instance)
	var result := move_module_to_temporary(module_instance, null, true)
	if result.get("ok", false):
		result["result"] = "stored"
		result["module"] = module_instance
	return result

func purchase_module(module_scene: PackedScene) -> Dictionary:
	if not PhaseManager.can_configure_loadout():
		return {"ok": false, "reason": "Modules can only be purchased during rest."}
	if module_scene == null:
		return {"ok": false, "reason": "Invalid module."}
	var module_instance := module_scene.instantiate() as Module
	if module_instance == null:
		return {"ok": false, "reason": "Invalid module."}
	module_instance.set_module_level(1)
	var price := _get_economy_config().get_module_purchase_gold(int(module_instance.cost))
	if PlayerData.player_gold < price:
		module_instance.queue_free()
		return {"ok": false, "reason": "Not enough gold.", "price": price}
	if not PlayerData.spend_gold(price):
		module_instance.queue_free()
		return {"ok": false, "reason": "Not enough gold.", "price": price}
	var result := obtain_module(module_instance)
	if not result.get("ok", false):
		PlayerData.refund_gold_spending(price)
		if is_instance_valid(module_instance):
			_discard_module_instance(module_instance)
		return result
	result["price"] = price
	_refresh_ui()
	return result

func upgrade_module_with_gold(module_instance: Module) -> Dictionary:
	if not PhaseManager.can_configure_loadout():
		return {"ok": false, "reason": "Modules can only be upgraded during rest."}
	if module_instance == null or not is_instance_valid(module_instance):
		return {"ok": false, "reason": "Invalid module."}
	if int(module_instance.module_level) >= Module.MAX_LEVEL:
		return {"ok": false, "reason": "Module is fully upgraded."}
	var price := _get_economy_config().get_module_upgrade_gold(
		int(module_instance.cost),
		int(module_instance.module_level)
	)
	if PlayerData.player_gold < price:
		return {"ok": false, "reason": "Not enough gold.", "price": price}
	if not PlayerData.spend_gold(price):
		return {"ok": false, "reason": "Not enough gold.", "price": price}
	if not module_instance.increase_module_level(1):
		PlayerData.refund_gold_spending(price)
		return {"ok": false, "reason": "Module is fully upgraded.", "price": price}
	var owner_weapon := _resolve_module_owner_weapon(module_instance)
	if owner_weapon and owner_weapon.has_method("calculate_status"):
		owner_weapon.calculate_status()
	temporary_modules_changed.emit()
	_notify(LocalizationManager.tr_format(
		"ui.inventory.upgrade",
		{"name": LocalizationManager.get_module_name(module_instance), "level": module_instance.module_level},
		"Upgraded %s to Lv.%d" % [LocalizationManager.get_module_name(module_instance), module_instance.module_level]
	))
	_refresh_ui()
	return {"ok": true, "result": "upgraded", "module": module_instance, "price": price}

func begin_pending_transaction(transaction: Dictionary) -> void:
	var transaction_id := str(transaction.get("id", ""))
	if transaction_id != "":
		for existing in pending_transactions:
			if str(existing.get("id", "")) == transaction_id:
				return
	pending_transactions.append(transaction.duplicate(true))
	pending_transactions_changed.emit()
	save_runtime_state()

func finish_pending_transaction(transaction_id: String) -> void:
	for index in range(pending_transactions.size() - 1, -1, -1):
		if str(pending_transactions[index].get("id", "")) == transaction_id:
			pending_transactions.remove_at(index)
	pending_transactions_changed.emit()
	save_runtime_state()

func _merge_duplicate_module(existing: Module, incoming: Module) -> Dictionary:
	if existing.increase_module_level(1):
		_discard_module_instance(incoming, existing)
		var owner_weapon := _resolve_module_owner_weapon(existing)
		if owner_weapon and owner_weapon.has_method("calculate_status"):
			owner_weapon.calculate_status()
		temporary_modules_changed.emit()
		_refresh_ui()
		return {"ok": true, "result": "upgraded", "module": existing}
	var gold := _calculate_module_conversion_coins(incoming)
	PlayerData.recycle_gold(gold)
	_discard_module_instance(incoming, existing)
	_refresh_ui()
	return {"ok": true, "result": "converted_to_gold", "gold": gold}

func sell_temporary_module(module_instance: Module) -> Dictionary:
	if module_instance == null or not temporary_modules.has(module_instance):
		return {"ok": false, "reason": "Invalid module."}
	var gold := _calculate_module_conversion_coins(module_instance)
	temporary_modules.erase(module_instance)
	PlayerData.recycle_gold(gold)
	_discard_module_instance(module_instance)
	temporary_modules_changed.emit()
	_refresh_ui()
	return {"ok": true, "gold": gold}

func sell_module(module_instance: Module) -> Dictionary:
	if module_instance == null or not is_instance_valid(module_instance):
		return {"ok": false, "reason": "Invalid module."}
	if temporary_modules.has(module_instance):
		return sell_temporary_module(module_instance)
	var owner_weapon := _resolve_module_owner_weapon(module_instance)
	if owner_weapon == null or owner_weapon.modules == null or module_instance.get_parent() != owner_weapon.modules:
		return {"ok": false, "reason": "Invalid module."}
	var gold := _calculate_module_conversion_coins(module_instance)
	owner_weapon.modules.remove_child(module_instance)
	PlayerData.recycle_gold(gold)
	_discard_module_instance(module_instance)
	if owner_weapon.has_method("calculate_status"):
		owner_weapon.calculate_status()
	temporary_modules_changed.emit()
	_refresh_ui()
	return {"ok": true, "result": "sold", "gold": gold}

func sell_unclaimed_module(module_instance: Module) -> Dictionary:
	if module_instance == null or not is_instance_valid(module_instance):
		return {"ok": false, "reason": "Invalid module."}
	var gold := _calculate_module_conversion_coins(module_instance)
	var module_name := LocalizationManager.get_module_name(module_instance)
	PlayerData.recycle_gold(gold)
	_discard_module_instance(module_instance)
	_notify(LocalizationManager.tr_format(
		"ui.inventory.unclaimed_module_sold",
		{"name": module_name, "gold": gold},
		"Unclaimed %s sold for +%d Gold" % [module_name, gold]
	))
	_refresh_ui()
	return {"ok": true, "result": "sold", "gold": gold}

func sell_all_temporary_modules() -> Dictionary:
	var total_gold := 0
	var sold_count := 0
	for module_instance in temporary_modules.duplicate():
		var result := sell_temporary_module(module_instance)
		if result.get("ok", false):
			total_gold += int(result.get("gold", 0))
			sold_count += 1
	return {"ok": true, "gold": total_gold, "count": sold_count}

func sell_equipped_weapon(_weapon: Weapon) -> Dictionary:
	return {
		"ok": false,
		"reason": LocalizationManager.tr_key(
			"ui.weapon.sell_disabled",
			"Weapon selling has been replaced by the weapon warehouse."
		),
	}

func replace_equipped_weapon(old_weapon: Weapon, new_weapon: Weapon) -> Dictionary:
	return equip_incoming_weapon_to_slot(new_weapon, old_weapon)

func _transfer_weapon_modules_to_temporary(weapon: Weapon) -> void:
	if weapon == null or weapon.modules == null:
		return
	for child in weapon.modules.get_children().duplicate():
		var module_instance := child as Module
		if module_instance:
			move_module_to_temporary(module_instance, weapon, true)

func _remove_equipped_weapon(weapon: Weapon) -> void:
	var removed_index := PlayerData.player_weapon_list.find(weapon)
	PlayerData.player_weapon_list.erase(weapon)
	weapon.queue_free()
	if PlayerData.player_weapon_list.is_empty():
		PlayerData.set_main_weapon_index(-1)
	else:
		var next_index := clampi(PlayerData.main_weapon_index, 0, PlayerData.player_weapon_list.size() - 1)
		if removed_index <= PlayerData.main_weapon_index:
			next_index = maxi(0, next_index - 1)
		PlayerData.set_main_weapon_index(next_index)
	if PlayerData.player and PlayerData.player.has_method("_apply_weapon_roles"):
		PlayerData.player.call("_apply_weapon_roles")

func _sort_temporary_modules() -> void:
	temporary_modules.sort_custom(func(a: Module, b: Module) -> bool:
		var rarity_cmp := _rarity_rank(a.get_rarity()) - _rarity_rank(b.get_rarity())
		if rarity_cmp != 0:
			return rarity_cmp > 0
		return LocalizationManager.get_module_name(a).naturalnocasecmp_to(
			LocalizationManager.get_module_name(b)
		) < 0
	)

func _rarity_rank(rarity: String) -> int:
	match rarity.to_lower():
		"legendary":
			return 4
		"epic":
			return 3
		"rare":
			return 2
		"uncommon":
			return 1
		_:
			return 0

func _resolve_module_owner_weapon(module_instance: Module) -> Weapon:
	var current: Node = module_instance
	while current:
		if current is Weapon:
			return current as Weapon
		current = current.get_parent()
	return null

func _calculate_module_conversion_coins(module_instance: Module) -> int:
	return _get_economy_config().get_duplicate_module_gold(
		int(module_instance.cost),
		int(module_instance.module_level)
	)

func _get_economy_config() -> EconomyConfig:
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data
	return EconomyConfig.new()

func _discard_module_instance(module_instance: Module, keep_instance: Module = null) -> void:
	if module_instance == null or module_instance == keep_instance or not is_instance_valid(module_instance):
		return
	if module_instance.get_parent() != null:
		module_instance.queue_free()
	else:
		module_instance.free()

func clear_on_select() -> void:
	on_select_upg = null
	ready_to_sell_list.clear()

func reset_runtime_state() -> void:
	for module_instance in temporary_modules:
		if module_instance and is_instance_valid(module_instance):
			_discard_module_instance(module_instance)
	temporary_modules.clear()
	for weapon in weapon_storage:
		if weapon and is_instance_valid(weapon):
			weapon.queue_free()
	weapon_storage.clear()
	weapon_core_inventory.clear()
	_fusion_commit_locks.clear()
	ready_to_sell_list.clear()
	pending_transactions.clear()
	on_select_upg = null
	temporary_modules_changed.emit()
	pending_transactions_changed.emit()
	weapon_storage_changed.emit()
	weapon_cores_changed.emit()
	if FileAccess.file_exists(RUNTIME_STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUNTIME_STATE_PATH))

func save_runtime_state() -> void:
	var module_payloads: Array[Dictionary] = []
	for module_instance in temporary_modules:
		if module_instance == null or not is_instance_valid(module_instance):
			continue
		module_payloads.append({
			"scene_path": str(module_instance.scene_file_path),
			"level": int(module_instance.module_level),
		})
	var weapon_payloads: Array[Dictionary] = []
	for weapon in weapon_storage:
		if weapon and is_instance_valid(weapon):
			weapon_payloads.append(DataHandler.build_weapon_save_payload(weapon))
	var payload := {
		"temporary_modules": module_payloads,
		"weapon_storage": weapon_payloads,
		"weapon_cores": get_weapon_core_stacks(),
		"pending_transactions": pending_transactions,
	}
	var file := FileAccess.open(RUNTIME_STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))

func load_runtime_state() -> void:
	if not FileAccess.file_exists(RUNTIME_STATE_PATH):
		return
	var file := FileAccess.open(RUNTIME_STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var payload := parsed as Dictionary
	_restore_weapon_cores(payload.get("weapon_cores", []))
	for weapon_variant in payload.get("weapon_storage", []):
		if not (weapon_variant is Dictionary):
			continue
		var weapon := DataHandler.instantiate_weapon_from_save_payload(weapon_variant as Dictionary)
		if weapon:
			add_child(weapon)
			DataHandler.restore_weapon_runtime_from_save_payload(weapon, weapon_variant as Dictionary)
			_transfer_weapon_modules_to_temporary(weapon)
			weapon.visible = false
			weapon.process_mode = Node.PROCESS_MODE_DISABLED
			weapon_storage.append(weapon)
	weapon_storage_changed.emit()
	for entry_variant in payload.get("temporary_modules", []):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var scene_path := str(entry.get("scene_path", ""))
		var scene := load(scene_path) as PackedScene
		if scene == null:
			push_warning("Skipping missing temporary module scene: %s" % scene_path)
			continue
		var module_instance := scene.instantiate() as Module
		if module_instance == null:
			continue
		module_instance.set_module_level(int(entry.get("level", 1)))
		obtain_module(module_instance)
	var restored_transactions = payload.get("pending_transactions", [])
	pending_transactions.clear()
	if restored_transactions is Array:
		for transaction in restored_transactions:
			if transaction is Dictionary:
				pending_transactions.append((transaction as Dictionary).duplicate(true))
	pending_transactions_changed.emit()

func restore_weapon_core_inventory(payload: Variant) -> void:
	_restore_weapon_cores(payload)

func _restore_weapon_cores(payload: Variant) -> void:
	weapon_core_inventory.clear()
	if not (payload is Array):
		if payload != null:
			push_warning("Skipping invalid weapon core inventory payload.")
		weapon_cores_changed.emit()
		return
	for entry_variant in payload:
		if not (entry_variant is Dictionary):
			push_warning("Skipping malformed weapon core inventory entry.")
			continue
		var entry := entry_variant as Dictionary
		var unknown := BuildTag.unknown_values(entry.get("tags", []))
		var tags := normalize_core_tags(entry.get("tags", []))
		var count := int(entry.get("count", 0))
		if not unknown.is_empty() or tags.is_empty() or count <= 0:
			push_warning("Skipping invalid weapon core entry tags=%s count=%d unknown=%s" % [str(entry.get("tags", [])), count, str(unknown)])
			continue
		var key := get_core_key(tags)
		var accumulated := get_weapon_core_count(tags) + count
		weapon_core_inventory[key] = {"tags": tags, "count": accumulated}
	weapon_cores_changed.emit()
