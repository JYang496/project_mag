extends Node

signal temporary_modules_changed
signal pending_transactions_changed

const RUNTIME_STATE_PATH := "user://equipment_runtime_state.json"

var temporary_modules: Array[Module] = []
var ready_to_sell_list: Array[Weapon] = []
var pending_transactions: Array[Dictionary] = []
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
	if ui.has_method("update_modules"):
		ui.update_modules()
	if ui.has_method("update_shop"):
		ui.update_shop()
	if ui.has_method("update_upg"):
		ui.update_upg()
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
	return result

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
	var duplicate := find_owned_module_by_scene_path(str(module_instance.scene_file_path), module_instance)
	if duplicate != null and duplicate != replaced_module:
		return {"ok": false, "reason": "Only one module of each type can be owned."}
	var projected_count := weapon.get_module_count()
	if replaced_module != null and replaced_module.get_parent() == weapon.modules:
		projected_count -= 1
	if projected_count >= int(weapon.MAX_MODULE_NUMBER):
		return {"ok": false, "reason": "No module slots available."}
	var reason := str(module_instance.get_incompatibility_reason(weapon))
	if reason != "":
		return {"ok": false, "reason": reason}
	return {"ok": true, "reason": ""}

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
		_notify(LocalizationManager.tr_format(
			"ui.inventory.obtain",
			{"name": LocalizationManager.get_module_name(module_instance), "level": module_instance.module_level},
			"Obtained %s Lv.%d" % [LocalizationManager.get_module_name(module_instance), module_instance.module_level]
		))
	return result

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
		var owner := _resolve_module_owner_weapon(existing)
		if owner and owner.has_method("calculate_status"):
			owner.calculate_status()
		_notify(LocalizationManager.tr_format(
			"ui.inventory.upgrade",
			{"name": LocalizationManager.get_module_name(existing), "level": existing.module_level},
			"Upgraded %s to Lv.%d" % [LocalizationManager.get_module_name(existing), existing.module_level]
		))
		temporary_modules_changed.emit()
		_refresh_ui()
		return {"ok": true, "result": "upgraded", "module": existing}
	var gold := _calculate_module_conversion_coins(incoming)
	PlayerData.player_gold += gold
	PlayerData.run_gold_earned += gold
	_discard_module_instance(incoming, existing)
	_notify(LocalizationManager.tr_format(
		"ui.inventory.convert",
		{"name": LocalizationManager.get_module_name(existing), "gold": gold},
		"Converted duplicate %s into +%d Gold" % [LocalizationManager.get_module_name(existing), gold]
	))
	_refresh_ui()
	return {"ok": true, "result": "converted_to_gold", "gold": gold}

func sell_temporary_module(module_instance: Module) -> Dictionary:
	if module_instance == null or not temporary_modules.has(module_instance):
		return {"ok": false, "reason": "Invalid module."}
	var gold := _calculate_module_conversion_coins(module_instance)
	temporary_modules.erase(module_instance)
	PlayerData.player_gold += gold
	PlayerData.run_gold_earned += gold
	_discard_module_instance(module_instance)
	temporary_modules_changed.emit()
	_refresh_ui()
	return {"ok": true, "gold": gold}

func sell_all_temporary_modules() -> Dictionary:
	var total_gold := 0
	var sold_count := 0
	for module_instance in temporary_modules.duplicate():
		var result := sell_temporary_module(module_instance)
		if result.get("ok", false):
			total_gold += int(result.get("gold", 0))
			sold_count += 1
	return {"ok": true, "gold": total_gold, "count": sold_count}

func sell_equipped_weapon(weapon: Weapon) -> Dictionary:
	if weapon == null or not PlayerData.player_weapon_list.has(weapon):
		return {"ok": false, "reason": "Invalid weapon."}
	if PlayerData.player_weapon_list.size() <= 1:
		return {"ok": false, "reason": "At least one weapon must remain equipped."}
	var ui = _get_ui()
	if ui and ui.has_method("is_branch_selection_blocking_interactions") \
			and bool(ui.call("is_branch_selection_blocking_interactions")):
		return {"ok": false, "reason": "Choose an evolution branch first."}
	_transfer_weapon_modules_to_temporary(weapon)
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	var base_price := int(weapon_def.price) if weapon_def else 0
	var gold := _get_economy_config().get_duplicate_weapon_gold(base_price)
	_remove_equipped_weapon(weapon)
	PlayerData.player_gold += gold
	PlayerData.run_gold_earned += gold
	_refresh_ui()
	return {"ok": true, "gold": gold}

func replace_equipped_weapon(old_weapon: Weapon, new_weapon: Weapon) -> Dictionary:
	if old_weapon == null or new_weapon == null:
		return {"ok": false, "reason": "Invalid weapon."}
	var slot_index := PlayerData.player_weapon_list.find(old_weapon)
	if slot_index < 0:
		return {"ok": false, "reason": "Invalid weapon."}
	var new_id := DataHandler.get_weapon_id_from_instance(new_weapon)
	for weapon_ref in PlayerData.player_weapon_list:
		var equipped := weapon_ref as Weapon
		if equipped != old_weapon and DataHandler.get_weapon_id_from_instance(equipped) == new_id:
			return {"ok": false, "reason": "Only one weapon of each type can be equipped."}
	_transfer_weapon_modules_to_temporary(old_weapon)
	var old_id := DataHandler.get_weapon_id_from_instance(old_weapon)
	var old_def := DataHandler.read_weapon_data(old_id) as WeaponDefinition
	var gold := _get_economy_config().get_duplicate_weapon_gold(int(old_def.price) if old_def else 0)
	var holder := old_weapon.get_parent()
	PlayerData.player_weapon_list[slot_index] = new_weapon
	if new_weapon.get_parent() != holder:
		if new_weapon.get_parent() != null:
			new_weapon.reparent(holder)
		elif holder:
			holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO
	old_weapon.queue_free()
	PlayerData.player_gold += gold
	PlayerData.run_gold_earned += gold
	if PlayerData.player and PlayerData.player.has_method("_apply_weapon_roles"):
		PlayerData.player.call("_apply_weapon_roles")
	_refresh_ui()
	return {"ok": true, "gold": gold, "slot": slot_index}

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
	ready_to_sell_list.clear()
	pending_transactions.clear()
	on_select_upg = null
	temporary_modules_changed.emit()
	pending_transactions_changed.emit()
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
	var payload := {
		"temporary_modules": module_payloads,
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
