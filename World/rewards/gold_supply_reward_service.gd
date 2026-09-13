extends RefCounted

const SOURCE := &"gold_supply"
const MODULE_CATALOG := preload("res://Player/Weapons/Core/module_offer_catalog.gd")
const FALLBACK_WEAPONS := [
	preload("res://data/weapons/machine_gun.tres"),
	preload("res://data/weapons/charged_blaster.tres"),
	preload("res://data/weapons/flamethrower.tres"),
]
var _busy := false
var _battle_owner: WeakRef
var _battle_pause_token := 0

func begin_battle_claim(owner: Node, token: int) -> bool:
	if _battle_owner != null or not PhaseManager.owns_pause(owner, token):
		return false
	_battle_owner = weakref(owner)
	_battle_pause_token = token
	return true

func end_battle_claim(owner: Node) -> void:
	if _battle_owner != null and _battle_owner.get_ref() == owner:
		_battle_owner = null
		_battle_pause_token = 0

func has_battle_claim() -> bool:
	var owner: Node = _battle_owner.get_ref() if _battle_owner != null else null
	return is_instance_valid(owner) and PhaseManager.owns_pause(owner, _battle_pause_token) \
		and PhaseManager.get_tree().paused and PhaseManager.current_state() == PhaseManager.BATTLE

func is_applying_battle_claim() -> bool:
	return _busy and has_battle_claim()


func normalize_record(record: Dictionary) -> Dictionary:
	record["source"] = str(SOURCE)
	if record.has("selected"):
		record["selected"] = int(record.selected)
	var options: Array[Dictionary] = []
	for option in record.get("options", []):
		for field in ["level", "from", "to", "amount"]:
			if option.has(field):
				option[field] = int(option[field])
		if option.has("tags"):
			option["tags"] = InventoryData.normalize_core_tags(option.tags)
		options.append(option)
	if record.has("options"):
		record["options"] = options
	return record

func _available() -> bool:
	return PlayerData.gold_supply_enabled and not _busy \
		and (PhaseManager.current_state() in [PhaseManager.REST, PhaseManager.SETTLEMENT] or has_battle_claim())

func _record(sequence: int) -> Dictionary:
	return PlayerData._find_gold_supply_record(sequence)

func _owned_weapon(id: String) -> Weapon:
	for weapon in PlayerData.player_weapon_list + InventoryData.get_stored_weapons():
		if is_instance_valid(weapon) and DataHandler.get_weapon_id_from_instance(weapon) == id:
			return weapon as Weapon
	return null

func _core(definition: WeaponDefinition) -> Dictionary:
	var tags := definition.get_normalized_core_tags()
	return {"kind": "weapon_core", "tags": Array(tags), "amount": 1, "id": definition.weapon_id, "key": "core:" + InventoryData.get_core_key(tags)}

func _append_unique(output: Array[Dictionary], option: Dictionary) -> void:
	for existing in output:
		if existing.key == option.key:
			return
	output.append(option)

func _pick_weighted_candidate(
	progress: Array[Dictionary],
	expansion: Array[Dictionary],
	cores: Array[Dictionary],
	excluded_keys: Dictionary
) -> Dictionary:
	var pools := {
		"progress": progress.filter(func(option: Dictionary) -> bool: return not excluded_keys.has(str(option.key))),
		"expansion": expansion.filter(func(option: Dictionary) -> bool: return not excluded_keys.has(str(option.key))),
		"core": cores.filter(func(option: Dictionary) -> bool: return not excluded_keys.has(str(option.key))),
	}
	var economy: EconomyConfig = GlobalVariables.economy_data if GlobalVariables.economy_data else EconomyConfig.new()
	var weights := economy.get_gold_supply_reward_weights()
	var total := 0.0
	for category in pools:
		if not (pools[category] as Array).is_empty():
			total += float(weights.get(category, 0.0))
	if total <= 0.0:
		for category in pools:
			if not (pools[category] as Array).is_empty():
				return (pools[category] as Array).pick_random()
		return {}
	var roll := randf() * total
	for category in ["progress", "core", "expansion"]:
		var pool: Array = pools[category]
		if pool.is_empty():
			continue
		roll -= float(weights.get(category, 0.0))
		if roll <= 0.0:
			return pool.pick_random()
	for category in ["progress", "core", "expansion"]:
		var fallback_pool: Array = pools[category]
		if not fallback_pool.is_empty():
			return fallback_pool.pick_random()
	return {}

func _build_options() -> Array[Dictionary]:
	var progress: Array[Dictionary] = []
	var expansion: Array[Dictionary] = []
	var cores: Array[Dictionary] = []
	for weapon in PlayerData.player_weapon_list:
		if not is_instance_valid(weapon):
			continue
		var id := DataHandler.get_weapon_id_from_instance(weapon)
		if int(weapon.level) < int(weapon.max_level):
			_append_unique(progress, {"kind": "weapon_upgrade", "id": id, "from": int(weapon.level), "to": int(weapon.level) + 1, "key": "upgrade:" + id})
		var definition := DataHandler.read_weapon_data(id) as WeaponDefinition
		if definition and int(weapon.fuse) < Weapon.MAX_FUSE_LEVEL:
			var core := _core(definition)
			if not InventoryData.get_fusion_branch_usages_for_core(core.tags).is_empty():
				_append_unique(progress, core)
	for path in MODULE_CATALOG.get_unlocked_scene_paths():
		var scene := load(path) as PackedScene
		var module := scene.instantiate() as Module if scene else null
		if module == null:
			continue
		var owned := InventoryData.find_owned_module_by_scene_path(path)
		if owned:
			if int(owned.module_level) < Module.MAX_LEVEL:
				_append_unique(progress, {"kind": "module_upgrade", "path": path, "from": int(owned.module_level), "to": int(owned.module_level) + 1, "level": 1, "key": "module:" + path})
		else:
			var option := {"kind": "module", "path": path, "level": 1, "key": "module:" + path}
			if InventoryData.can_assign_module_to_any_equipped_weapon(module, true):
				_append_unique(progress, option)
			else:
				_append_unique(expansion, option)
		module.free()
	for id in DataHandler.get_weapon_ids():
		var definition := DataHandler.read_weapon_data(id) as WeaponDefinition
		if definition == null or definition.is_hidden or definition.scene == null:
			continue
		if definition.has_valid_core_tag_count() and definition.get_unknown_core_tags().is_empty():
			_append_unique(cores, _core(definition))
		if _owned_weapon(id):
			if definition.has_valid_core_tag_count() and definition.get_unknown_core_tags().is_empty():
				var duplicate := _core(definition)
				duplicate["duplicate"] = true
				_append_unique(expansion, duplicate)
		else:
			_append_unique(expansion, {"kind": "weapon", "id": id, "level": 1, "key": "weapon:" + id})
	# Existing inherent core types have no inventory cap and are valid without slots.
	for definition in FALLBACK_WEAPONS:
		_append_unique(cores, _core(definition))
	var options: Array[Dictionary] = []
	var excluded_keys := {}
	while options.size() < 3:
		var picked := _pick_weighted_candidate(progress, expansion, cores, excluded_keys)
		if picked.is_empty():
			break
		_append_unique(options, picked)
		excluded_keys[str(picked.key)] = true
	# A core has no slot/capacity dependency, so one option remains valid even if the
	# loadout changes between preparation and claim (including after save/restore).
	var has_core := options.any(func(option: Dictionary) -> bool: return str(option.kind) == "weapon_core")
	if not has_core:
		for core in cores:
			if not excluded_keys.has(str(core.key)):
				if options.size() >= 3:
					options[-1] = core
				else:
					options.append(core)
				break
	# Keep the stable fallback in the third slot for a predictable claim path.
	for index in options.size():
		if str(options[index].kind) == "weapon_core":
			var core_option := options[index]
			options.remove_at(index)
			options.append(core_option)
			break
	return options

func prepare(sequence: int) -> Dictionary:
	if not _available():
		return {"ok": false, "status": "unavailable"}
	var record := _record(sequence)
	if record.is_empty():
		return {"ok": false, "status": "missing"}
	_busy = true
	if not record.has("options"):
		record["options"] = _build_options()
		record["status"] = "ready"
	if not SaveManager.begin_reward_transaction():
		_busy = false
		return {"ok": false, "status": "save_busy"}
	var saved := SaveManager.commit_reward_transaction(&"gold_supply_prepared")
	SaveManager.abort_reward_transaction()
	_busy = false
	if not bool(saved.get("ok", false)):
		return {"ok": false, "status": "save_failed"} # Keep the same candidates for retry.
	return {"ok": true, "source": SOURCE, "status": str(record.status), "record": record.duplicate(true), "rewards": get_rewards(sequence)}

func get_rewards(sequence: int) -> Array[RewardInfo]:
	var record := _record(sequence)
	var rewards: Array[RewardInfo] = []
	for option in record.get("options", []):
		var reward := RewardInfo.new()
		reward.source_id = SOURCE
		reward.reward_key_override = str(option.key)
		reward.rarity = str(record.get("quality", "common"))
		match str(option.kind):
			"weapon":
				reward.item_id = str(option.id)
				reward.item_level = int(option.level)
				if _owned_weapon(reward.item_id):
					reward.obtain_prediction_override = InventoryData.build_duplicate_weapon_core_preview(reward.item_id)
				else:
					reward.obtain_prediction_override = {"result": "not_applicable", "will_equip_to_empty_slot": InventoryData.has_open_weapon_slot(), "will_choose_replacement": not InventoryData.has_open_weapon_slot()}
			"weapon_upgrade":
				reward.reward_kind = RewardInfo.KIND_WEAPON_UPGRADE
				reward.target_weapon_id = str(option.id)
				reward.target_weapon_from_level = int(option.from)
				reward.target_weapon_to_level = int(option.to)
				var weapon := _owned_weapon(str(option.id))
				if weapon:
					reward.target_weapon_ref = weakref(weapon)
					reward.target_weapon_name = LocalizationManager.get_weapon_instance_display_name(weapon)
			"module", "module_upgrade":
				reward.module_scene = load(str(option.path)) as PackedScene if ResourceLoader.exists(str(option.path)) else null
				reward.module_level = int(option.get("to", option.level))
				var owned := InventoryData.find_owned_module_by_scene_path(str(option.path))
				if option.kind == "module" and owned:
					reward.module_level = mini(int(owned.module_level) + 1, Module.MAX_LEVEL)
				if option.kind == "module_upgrade":
					reward.reward_kind = RewardInfo.KIND_MODULE_UPGRADE
					reward.target_module_from_level = int(option.from)
					reward.target_module_to_level = int(option.to)
			"weapon_core":
				reward.reward_kind = RewardInfo.KIND_WEAPON_CORE
				reward.item_id = str(option.id)
				reward.core_tags = InventoryData.normalize_core_tags(option.tags)
				reward.core_amount = int(option.amount)
				reward.set_meta("duplicate_weapon", bool(option.get("duplicate", false)))
		rewards.append(reward)
	return rewards

func accept(sequence: int, option_index: int) -> Dictionary:
	return _choose(sequence, option_index, false, -1)

func complete_replacement(sequence: int, accepted: bool, slot_index: int = -1) -> Dictionary:
	if not _available():
		return {"ok": false, "status": "unavailable"}
	var record := _record(sequence)
	if record.get("status", "") != "awaiting_replacement":
		return {"ok": false, "status": "not_waiting"}
	if not accepted:
		return _cancel_replacement(record)
	return _choose(sequence, int(record.selected), true, slot_index)

func _cancel_replacement(record: Dictionary) -> Dictionary:
	_busy = true
	if not SaveManager.begin_reward_transaction():
		_busy = false
		return {"ok": false, "status": "save_busy"}
	var selected := int(record.selected)
	record["status"] = "ready"
	record.erase("selected")
	var saved := SaveManager.commit_reward_transaction(&"gold_supply_cancelled")
	if not bool(saved.get("ok", false)):
		record["status"] = "awaiting_replacement"
		record["selected"] = selected
	SaveManager.abort_reward_transaction()
	_busy = false
	return {"ok": bool(saved.get("ok", false)), "status": "cancelled" if bool(saved.get("ok", false)) else "save_failed"}

func _choose(sequence: int, option_index: int, replacement: bool, slot: int) -> Dictionary:
	if not _available():
		return {"ok": false, "status": "unavailable"}
	var record := _record(sequence)
	if record.is_empty():
		return {"ok": false, "status": "missing_or_claimed"}
	var pending := PlayerData.get_pending_gold_supplies()
	if int(pending[0].sequence) != sequence:
		return {"ok": false, "status": "out_of_order"}
	if record.get("status", "") == "awaiting_replacement" and not replacement:
		return {"ok": false, "status": "awaiting_replacement"}
	var options: Array = record.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return {"ok": false, "status": "invalid_option"}
	if not InventoryData.pending_transactions.is_empty():
		return {"ok": false, "status": "equipment_busy"}
	_busy = true
	if not SaveManager.begin_reward_transaction():
		_busy = false
		return {"ok": false, "status": "save_busy"}
	var snapshot := TaskRewardManager.build_run_snapshot()
	var option: Dictionary = options[option_index]
	if option.kind == "weapon" and not _owned_weapon(str(option.id)) and not InventoryData.has_open_weapon_slot() and not replacement:
		record["status"] = "awaiting_replacement"
		record["selected"] = option_index
		var saved := SaveManager.commit_reward_transaction(&"gold_supply_replacement_pending")
		if not bool(saved.get("ok", false)):
			record["status"] = "ready"
			record.erase("selected")
		SaveManager.abort_reward_transaction()
		_busy = false
		return {"ok": bool(saved.get("ok", false)), "status": "replacement_required" if bool(saved.get("ok", false)) else "save_failed", "sequence": sequence, "option": option.duplicate(true)}
	InventoryData.suspend_runtime_saves()
	var applied := _apply(option, replacement, slot)
	if bool(applied.get("ok", false)):
		var receipt := {"source": str(SOURCE), "sequence": sequence, "selected": option_index, "status": "claimed", "result": str(applied.get("result", "applied"))}
		PlayerData._finish_gold_supply_claim(sequence, receipt)
		var saved := SaveManager.commit_reward_transaction(&"gold_supply_claimed")
		if not bool(saved.get("ok", false)):
			TaskRewardManager.restore_run_snapshot_after_player_spawn(snapshot)
			applied = {"ok": false, "status": "save_failed"}
		else:
			applied = receipt.merged({"ok": true})
	else:
		# Failed validation must not mutate; failed application restores the full core.
		if bool(applied.get("mutated", false)):
			TaskRewardManager.restore_run_snapshot_after_player_spawn(snapshot)
	SaveManager.abort_reward_transaction()
	InventoryData.resume_runtime_saves(bool(applied.get("ok", false)))
	if is_instance_valid(PlayerData.player):
		PlayerData.player._refresh_weapon_structure_if_needed()
		PlayerData.player._rebuild_shared_heat_pool()
	_busy = false
	PlayerData.gold_supply_changed.emit()
	return applied

func _apply(option: Dictionary, replacement: bool, slot: int) -> Dictionary:
	match str(option.kind):
		"weapon_core":
			return InventoryData.add_weapon_cores(option.tags, int(option.amount), false)
		"weapon_upgrade":
			var weapon := _owned_weapon(str(option.id))
			if weapon == null or not PlayerData.player_weapon_list.has(weapon) or int(weapon.level) != int(option.from) or int(weapon.level) >= int(weapon.max_level):
				return {"ok": false, "status": "stale_upgrade"}
			weapon.set_level(int(option.to))
			if int(weapon.level) != int(option.to):
				return {"ok": false, "status": "upgrade_failed", "mutated": true}
			PlayerData.record_weapon_progress()
			PlayerData.notify_weapon_list_changed()
			return {"ok": true, "result": "weapon_upgraded"}
		"module", "module_upgrade":
			var owned := InventoryData.find_owned_module_by_scene_path(str(option.path))
			if owned and (int(owned.module_level) >= Module.MAX_LEVEL or (option.kind == "module_upgrade" and int(owned.module_level) != int(option.from))):
				return {"ok": false, "status": "stale_module"}
			if option.kind == "module_upgrade" and owned == null:
				return {"ok": false, "status": "missing_module"}
			var scene := load(str(option.path)) as PackedScene if ResourceLoader.exists(str(option.path)) else null
			var module := scene.instantiate() as Module if scene else null
			if module == null:
				return {"ok": false, "status": "missing_module_scene"}
			module.set_module_level(1)
			var result := InventoryData.obtain_module(module)
			if not bool(result.get("ok", false)) and is_instance_valid(module):
				module.queue_free()
			return {"ok": bool(result.get("ok", false)), "result": str(result.get("result", "failed"))}
		"weapon":
			if PlayerData.player == null or not is_instance_valid(PlayerData.player):
				return {"ok": false, "status": "player_not_ready"}
			var definition := DataHandler.read_weapon_data(str(option.id)) as WeaponDefinition
			var weapon := definition.scene.instantiate() as Weapon if definition and definition.scene else null
			if weapon == null:
				return {"ok": false, "status": "missing_weapon_scene"}
			weapon.level = int(option.level)
			var result: Dictionary
			if replacement and not _owned_weapon(str(option.id)):
				if slot < 0 or slot >= PlayerData.max_weapon_num:
					weapon.queue_free()
					return {"ok": false, "status": "invalid_slot"}
				var old := PlayerData.player_weapon_list[slot] as Weapon if slot < PlayerData.player_weapon_list.size() else null
				result = InventoryData.equip_incoming_weapon_to_slot(weapon, old, true)
			else:
				result = InventoryData.obtain_weapon_reward(weapon)
			if not bool(result.get("ok", false)):
				if is_instance_valid(weapon):
					weapon.queue_free()
				return {"ok": false, "status": "weapon_obtain_failed", "mutated": true}
			if str(result.get("result", "")) == "selection_pending":
				return {"ok": false, "status": "unexpected_pending", "mutated": true}
			return {"ok": true, "result": str(result.get("result", "obtained"))}
	return {"ok": false, "status": "invalid_reward"}
