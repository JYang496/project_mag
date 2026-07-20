extends Node

signal pending_reward_changed(has_pending: bool)

const STATE_PATH := "user://task_reward_state.json"
const ROLLBACK_PATH := "user://battle_rollback_snapshot.json"
const ENTRY_PENDING := "pending"
const ENTRY_GRANTED := "granted"
const ENTRY_WAITING := "waiting"
const BATTLE_END_REWARD_DELAY_SEC := 1.5

var _pending_level: int = -1
var _pending_reward_entries: Array[Dictionary] = []
var _unbuilt_bundle_count: int = 0
var _next_reward_entry_id: int = 1
var _reward_unlocked := false
var _reward_panel_open := false
var _battle_in_progress := false
var _restore_snapshot_on_world_start := false
var _reward_manager: Node
var _bundle_generation_warning_emitted := false

func _ready() -> void:
	_load_state()
	if _battle_in_progress and FileAccess.file_exists(ROLLBACK_PATH):
		_restore_snapshot_on_world_start = true
		_clear_pending_reward(false)
	if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.connect(_on_phase_changed)
	call_deferred("_connect_reward_draft_runtime")

func is_enabled() -> bool:
	var economy := _get_economy_config()
	return economy.task_reward_options_enabled

func is_task_reward_blocking_interactions() -> bool:
	return _reward_unlocked and PhaseManager.current_state() == PhaseManager.PREPARE

func is_reward_blocking_interactions() -> bool:
	return is_task_reward_blocking_interactions() \
		or RewardDraftRuntime.is_standard_draft_blocking_interactions() \
		or PhaseManager.is_post_battle_collect_gate_active()

func _connect_reward_draft_runtime() -> void:
	if RewardDraftRuntime == null:
		return
	if not RewardDraftRuntime.pending_standard_draft_changed.is_connected(_on_standard_draft_blocking_changed):
		RewardDraftRuntime.pending_standard_draft_changed.connect(_on_standard_draft_blocking_changed)

func _on_standard_draft_blocking_changed(_has_pending: bool) -> void:
	pending_reward_changed.emit(is_reward_blocking_interactions())

func has_pending_reward() -> bool:
	return _reward_unlocked

func get_pending_reward_options() -> Array[RewardInfo]:
	var rewards: Array[RewardInfo] = []
	for entry in _pending_reward_entries:
		var reward := entry.get("reward", null) as RewardInfo
		if reward != null:
			rewards.append(reward)
	return rewards

func notify_objective_completed(_cell_id: String = "") -> void:
	if not is_enabled() or PhaseManager.current_state() != PhaseManager.BATTLE:
		return
	if CellTaskModuleRuntime != null and CellTaskModuleRuntime.has_method("record_objective_completed"):
		CellTaskModuleRuntime.record_objective_completed(_cell_id)
	_unbuilt_bundle_count += 1
	_reward_unlocked = true
	_pending_level = int(PhaseManager.current_level)
	_build_pending_reward_bundles()
	_save_state()
	pending_reward_changed.emit(true)
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("show_item_message"):
		ui.show_item_message(LocalizationManager.tr_key(
			"ui.task_reward.unlocked",
			"Objective complete. Rewards will be delivered in the Rest Area."
		), 2.6)

func begin_battle_snapshot() -> bool:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return false
	if not _write_rollback_snapshot():
		push_warning("Unable to create battle rollback snapshot.")
		return false
	_battle_in_progress = true
	_clear_pending_reward(false)
	_save_state()
	return true

func prepare_world_start() -> bool:
	if _battle_in_progress and FileAccess.file_exists(ROLLBACK_PATH):
		_restore_snapshot_on_world_start = true
		_clear_pending_reward(false)
		return true
	if _reward_unlocked and FileAccess.file_exists(ROLLBACK_PATH):
		_restore_snapshot_on_world_start = true
		return true
	return false

func restore_snapshot_after_player_spawn() -> bool:
	if not _restore_snapshot_on_world_start:
		return false
	var snapshot := _read_json_dictionary(ROLLBACK_PATH)
	_restore_snapshot_on_world_start = false
	if snapshot.is_empty():
		_battle_in_progress = false
		_save_state()
		return false
	var preserve_pending_reward := _reward_unlocked
	_restore_player_state(snapshot.get("player", {}) as Dictionary)
	_restore_inventory_state(snapshot.get("inventory", {}) as Dictionary)
	if snapshot.get("reward_draft_runtime", {}) is Dictionary:
		RewardDraftRuntime.restore_battle_rollback_snapshot(snapshot.get("reward_draft_runtime", {}) as Dictionary)
	if snapshot.get("battle_contract", {}) is Dictionary:
		BattleContractManager.restore_rollback_snapshot(snapshot.get("battle_contract", {}) as Dictionary)
	PhaseManager.current_level = maxi(int(snapshot.get("level", 0)), 0)
	_battle_in_progress = false
	_save_state()
	InventoryData.save_runtime_state()
	if preserve_pending_reward:
		call_deferred("_try_open_pending_reward")
	else:
		_clear_pending_reward(false)
		_delete_file(ROLLBACK_PATH)
	return true

func reset_runtime_state(preserve_persistent_state: bool = false) -> void:
	_reward_panel_open = false
	_reward_manager = null
	if preserve_persistent_state:
		return
	_pending_level = -1
	_pending_reward_entries.clear()
	_unbuilt_bundle_count = 0
	_next_reward_entry_id = 1
	_reward_unlocked = false
	_battle_in_progress = false
	_restore_snapshot_on_world_start = false
	_bundle_generation_warning_emitted = false
	_delete_file(STATE_PATH)
	_delete_file(ROLLBACK_PATH)
	pending_reward_changed.emit(false)

func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.GAMEOVER:
		_clear_pending_reward(true)
		_battle_in_progress = false
		_delete_file(ROLLBACK_PATH)
		_save_state()
		return
	if new_phase != PhaseManager.PREPARE:
		return
	_battle_in_progress = false
	if _reward_unlocked and _pending_level == int(PhaseManager.current_level) - 1:
		_write_rollback_snapshot()
		_save_state()
		call_deferred("_try_open_pending_reward_after_battle_outro")
		return
	_save_state()
	_clear_pending_reward(true)
	call_deferred("_finalize_success_without_reward")

func _finalize_success_without_reward() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE or _reward_unlocked:
		return
	_delete_file(ROLLBACK_PATH)

func _try_open_pending_reward() -> void:
	if not _reward_unlocked or _reward_panel_open:
		return
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	if PhaseManager.is_post_battle_collect_gate_active():
		_retry_open_later()
		return
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui) or not ui.has_method("request_task_reward_summary"):
		_retry_open_later()
		return
	if _unbuilt_bundle_count > 0:
		_build_pending_reward_bundles()
		_save_state()
	if _pending_reward_entries.is_empty() or _unbuilt_bundle_count > 0:
		_retry_open_later()
		return
	var settlement_status := _settle_pending_reward_entries()
	if settlement_status != ENTRY_GRANTED:
		if settlement_status == ENTRY_PENDING:
			_retry_open_later()
		return
	var summary_rewards := _build_summary_rewards()
	if summary_rewards.is_empty():
		_retry_open_later()
		return
	_reward_panel_open = bool(ui.request_task_reward_summary(
		summary_rewards,
		Callable(self, "_on_reward_summary_closed")
	))
	if not _reward_panel_open:
		_retry_open_later()

func _try_open_pending_reward_after_battle_outro() -> void:
	await get_tree().create_timer(BATTLE_END_REWARD_DELAY_SEC).timeout
	_try_open_pending_reward()

func _retry_open_later() -> void:
	await get_tree().create_timer(0.2).timeout
	_try_open_pending_reward()

func _on_reward_summary_closed() -> void:
	_reward_panel_open = false
	_clear_pending_reward(true)
	_delete_file(ROLLBACK_PATH)
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("resume_pending_weapon_branch_selection"):
		ui.call_deferred("resume_pending_weapon_branch_selection")

func _settle_pending_reward_entries() -> String:
	for index in range(_pending_reward_entries.size()):
		var entry := _pending_reward_entries[index]
		if str(entry.get("status", ENTRY_PENDING)) == ENTRY_GRANTED:
			continue
		var reward := entry.get("reward", null) as RewardInfo
		if not _is_reward_valid(reward):
			reward = _build_invalid_reward_fallback(str(entry.get("id", "")))
			entry["reward"] = reward
			entry["status"] = ENTRY_PENDING
			_pending_reward_entries[index] = entry
			_save_state()
		var grant_result := _grant_reward_entry(str(entry.get("id", "")), reward)
		var status := str(grant_result.get("status", ENTRY_PENDING))
		if status == ENTRY_GRANTED:
			entry["status"] = ENTRY_GRANTED
			_pending_reward_entries[index] = entry
			_save_state()
			continue
		entry["status"] = status
		_pending_reward_entries[index] = entry
		_save_state()
		return status
	return ENTRY_GRANTED

func _grant_reward_entry(entry_id: String, reward: RewardInfo) -> Dictionary:
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		return {"status": ENTRY_GRANTED} \
			if CellEffectRuntime.grant_effect_once(entry_id, reward.cell_effect_id) \
			else {"status": ENTRY_PENDING}
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		var result := CellTaskModuleRuntime.grant_module_once(entry_id, reward.task_module_id)
		return {"status": ENTRY_GRANTED} if bool(result.get("ok", false)) else {"status": ENTRY_PENDING}
	var manager := _resolve_reward_manager()
	var grant_reward := _prepare_reward_for_grant(reward)
	if manager != null and grant_reward != null and manager.grant_reward_immediately(grant_reward):
		return {"status": ENTRY_GRANTED}
	return {"status": ENTRY_PENDING}

func _build_pending_reward_bundles() -> void:
	while _unbuilt_bundle_count > 0:
		var bundle := _build_task_reward_bundle(_pending_level)
		if bundle.size() != 2:
			if not _bundle_generation_warning_emitted:
				push_warning("TaskRewardManager: reward bundle could not be generated; settlement remains pending.")
				_bundle_generation_warning_emitted = true
			return
		_bundle_generation_warning_emitted = false
		for reward in bundle:
			_pending_reward_entries.append({
				"id": "task_reward_%d" % _next_reward_entry_id,
				"status": ENTRY_PENDING,
				"reward": reward,
			})
			_next_reward_entry_id += 1
		_unbuilt_bundle_count -= 1

func _build_task_reward_bundle(level_index: int) -> Array[RewardInfo]:
	var guaranteed_task := CellTaskModuleRuntime.build_reward_option(level_index)
	if guaranteed_task == null:
		return []
	var secondary: RewardInfo
	var task_chance := _get_economy_config().get_task_reward_secondary_task_module_chance()
	if randf() < task_chance:
		secondary = CellTaskModuleRuntime.build_reward_option(level_index)
		if secondary == null:
			secondary = _build_cell_effect_reward(level_index)
	else:
		secondary = _build_cell_effect_reward(level_index)
		if secondary == null:
			secondary = CellTaskModuleRuntime.build_reward_option(level_index)
	if secondary == null:
		return []
	return [guaranteed_task, secondary]

func _build_cell_effect_reward(level_index: int) -> RewardInfo:
	var rewards := CellEffectRuntime.build_reward_options(level_index, 1)
	return rewards[0] if not rewards.is_empty() else null

func _is_reward_valid(reward: RewardInfo) -> bool:
	if reward == null:
		return false
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		return CellEffectRuntime.get_definition(reward.cell_effect_id) != null
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		return CellTaskModuleRuntime.get_definition(reward.task_module_id) != null
	if reward.item_id.strip_edges() != "":
		return DataHandler.read_weapon_data(reward.item_id) != null
	if reward.module_scene != null:
		return true
	return reward.total_chip_value > 0 or reward.gold_value > 0 or reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE

func _build_invalid_reward_fallback(entry_id: String) -> RewardInfo:
	push_warning("TaskRewardManager: replaced invalid pending reward '%s' with economy compensation." % entry_id)
	var fallback := RewardInfo.new()
	fallback.reward_kind = RewardInfo.KIND_ECONOMY
	fallback.gold_value = _get_economy_config().get_reward_economy_gold()
	fallback.reward_key_override = "task_reward_fallback_economy"
	return fallback

func _build_summary_rewards() -> Array[RewardInfo]:
	var grouped: Dictionary = {}
	for entry in _pending_reward_entries:
		if str(entry.get("status", "")) != ENTRY_GRANTED:
			continue
		var reward := entry.get("reward", null) as RewardInfo
		if reward == null:
			continue
		var key := _get_reward_summary_key(reward)
		if grouped.has(key):
			var existing := grouped[key] as RewardInfo
			existing.set_meta("summary_count", int(existing.get_meta("summary_count", 1)) + 1)
		else:
			reward.set_meta("summary_count", 1)
			grouped[key] = reward
	var rewards: Array[RewardInfo] = []
	for value in grouped.values():
		rewards.append(value as RewardInfo)
	rewards.sort_custom(func(a: RewardInfo, b: RewardInfo) -> bool:
		var category_delta := _get_reward_category_rank(a) - _get_reward_category_rank(b)
		if category_delta != 0:
			return category_delta < 0
		var rarity_delta := _get_rarity_rank(a.get_rarity()) - _get_rarity_rank(b.get_rarity())
		if rarity_delta != 0:
			return rarity_delta > 0
		return _get_reward_summary_key(a) < _get_reward_summary_key(b)
	)
	return rewards

func _get_reward_summary_key(reward: RewardInfo) -> String:
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		return "cell_effect:%s" % reward.cell_effect_id
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		return "task_module:%s" % reward.task_module_id
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		return "weapon_upgrade:%s:%d:%d" % [
			reward.target_weapon_id,
			reward.target_weapon_from_level,
			reward.target_weapon_to_level,
		]
	if reward.item_id.strip_edges() != "":
		return "weapon:%s:%d" % [reward.item_id, reward.item_level]
	if reward.module_scene != null:
		return "module:%s:%d" % [reward.module_scene.resource_path, reward.module_level]
	if reward.total_chip_value > 0 or reward.gold_value > 0:
		return "economy:%d:%d" % [reward.total_chip_value, reward.gold_value]
	return reward.reward_key_override

func _get_reward_category_rank(reward: RewardInfo) -> int:
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		return 0
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		return 1
	if reward.item_id.strip_edges() != "" or reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		return 2
	if reward.module_scene != null:
		return 3
	return 4

func _get_rarity_rank(rarity: String) -> int:
	match rarity.to_lower():
		"legendary":
			return 3
		"epic":
			return 2
		"rare":
			return 1
		_:
			return 0

func _resolve_reward_manager() -> Node:
	if _reward_manager and is_instance_valid(_reward_manager):
		return _reward_manager
	var scene := get_tree().current_scene
	if scene:
		_reward_manager = scene.get_node_or_null("RewardManager")
	return _reward_manager

func _build_rollback_snapshot() -> Dictionary:
	var weapon_payloads: Array[Dictionary] = []
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon and is_instance_valid(weapon):
			weapon_payloads.append(DataHandler.build_weapon_save_payload(weapon))
	var temporary_payloads: Array[Dictionary] = []
	for module_ref in InventoryData.temporary_modules:
		var module_instance := module_ref as Module
		if module_instance and is_instance_valid(module_instance):
			temporary_payloads.append({
				"scene_path": str(module_instance.scene_file_path),
				"level": int(module_instance.module_level),
			})
	var stored_weapon_payloads: Array[Dictionary] = []
	for weapon in InventoryData.weapon_storage:
		if weapon and is_instance_valid(weapon):
			stored_weapon_payloads.append(DataHandler.build_weapon_save_payload(weapon))
	return {
		"level": int(PhaseManager.current_level),
		"player": {
			"level": int(PlayerData.player_level),
			"exp": int(PlayerData.player_exp),
			"next_exp": int(PlayerData.next_level_exp),
			"speed": float(PlayerData.player_speed),
			"bonus_speed": float(PlayerData.player_bonus_speed),
			"dash_cooldown": float(PlayerData.dash_cooldown),
			"max_hp": int(PlayerData.player_max_hp),
			"hp": int(PlayerData.player_hp),
			"hp_regen": int(PlayerData.hp_regen),
			"hp_bonus_regen": int(PlayerData.hp_bonus_regen),
			"armor": int(PlayerData.armor),
			"bonus_armor": int(PlayerData.bonus_armor),
			"shield": int(PlayerData.shield),
			"bonus_shield": int(PlayerData.bonus_shield),
			"damage_reduction": float(PlayerData.damage_reduction),
			"bonus_damage_reduction": float(PlayerData.bonus_damage_reduction),
			"crit_rate": float(PlayerData.crit_rate),
			"bonus_crit_rate": float(PlayerData.bonus_crit_rate),
			"crit_damage": float(PlayerData.crit_damage),
			"bonus_crit_damage": float(PlayerData.bonus_crit_damage),
			"grab_radius": float(PlayerData.grab_radius),
			"grab_radius_multiplier": float(PlayerData.grab_radius_mutifactor),
			"gold": int(PlayerData.player_gold),
			"round_coin": int(PlayerData.round_coin_collected),
			"round_chip": int(PlayerData.round_chip_collected),
			"run_damage": int(PlayerData.run_total_damage_dealt),
			"run_kills": int(PlayerData.run_enemy_kills),
			"run_elite_kills": int(PlayerData.run_elite_kills),
			"run_completed_levels": int(PlayerData.run_completed_levels),
			"run_gold": int(PlayerData.run_gold_earned),
			"run_gold_recycled": int(PlayerData.run_gold_recycled),
			"run_gold_spent": int(PlayerData.run_gold_spent),
			"rounds_without_weapon_progress": int(PlayerData.rounds_without_weapon_progress),
			"main_weapon_index": int(PlayerData.main_weapon_index),
			"weapons": weapon_payloads,
		},
		"inventory": {
			"temporary_modules": temporary_payloads,
			"weapon_storage": stored_weapon_payloads,
			"pending_transactions": InventoryData.pending_transactions.duplicate(true),
		},
		"reward_draft_runtime": RewardDraftRuntime.build_battle_rollback_snapshot(),
		"battle_contract": BattleContractManager.build_rollback_snapshot(),
	}

func build_run_snapshot() -> Dictionary:
	return _build_rollback_snapshot()

func restore_run_snapshot_after_player_spawn(payload: Dictionary) -> void:
	_restore_player_state(payload.get("player", {}) as Dictionary)
	_restore_inventory_state(payload.get("inventory", {}) as Dictionary)

func export_save_state() -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry in _pending_reward_entries:
		entries.append({
			"id": str(entry.get("id", "")),
			"status": str(entry.get("status", ENTRY_PENDING)),
			"reward": _serialize_reward(entry.get("reward", null) as RewardInfo),
		})
	return {
		"pending_level": _pending_level,
		"entries": entries,
		"unbuilt_bundle_count": _unbuilt_bundle_count,
		"next_reward_entry_id": _next_reward_entry_id,
		"reward_unlocked": _reward_unlocked,
	}

func import_save_state(payload: Dictionary) -> void:
	_pending_level = int(payload.get("pending_level", -1))
	_pending_reward_entries.clear()
	for value in payload.get("entries", []):
		if value is Dictionary:
			var entry := value as Dictionary
			_pending_reward_entries.append({
				"id": str(entry.get("id", "")),
				"status": str(entry.get("status", ENTRY_PENDING)),
				"reward": _deserialize_reward(entry.get("reward", {}) as Dictionary),
			})
	_unbuilt_bundle_count = maxi(int(payload.get("unbuilt_bundle_count", 0)), 0)
	_next_reward_entry_id = maxi(int(payload.get("next_reward_entry_id", 1)), 1)
	_reward_unlocked = bool(payload.get("reward_unlocked", false))
	_battle_in_progress = false
	pending_reward_changed.emit(_reward_unlocked)

func _write_rollback_snapshot() -> bool:
	var file := FileAccess.open(ROLLBACK_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_build_rollback_snapshot()))
	return true

func _restore_player_state(payload: Dictionary) -> void:
	PlayerData.player_level = int(payload.get("level", PlayerData.player_level))
	PlayerData.next_level_exp = int(payload.get("next_exp", PlayerData.next_level_exp))
	PlayerData.player_exp = int(payload.get("exp", PlayerData.player_exp))
	PlayerData.player_speed = float(payload.get("speed", PlayerData.player_speed))
	PlayerData.player_bonus_speed = float(payload.get("bonus_speed", 0.0))
	PlayerData.dash_cooldown = float(payload.get("dash_cooldown", PlayerData.dash_cooldown))
	PlayerData.player_max_hp = int(payload.get("max_hp", PlayerData.player_max_hp))
	PlayerData.player_hp = int(payload.get("hp", PlayerData.player_hp))
	PlayerData.hp_regen = int(payload.get("hp_regen", PlayerData.hp_regen))
	PlayerData.hp_bonus_regen = int(payload.get("hp_bonus_regen", 0))
	PlayerData.armor = int(payload.get("armor", PlayerData.armor))
	PlayerData.bonus_armor = int(payload.get("bonus_armor", 0))
	PlayerData.shield = int(payload.get("shield", PlayerData.shield))
	PlayerData.bonus_shield = int(payload.get("bonus_shield", 0))
	PlayerData.damage_reduction = float(payload.get("damage_reduction", PlayerData.damage_reduction))
	PlayerData.bonus_damage_reduction = float(payload.get("bonus_damage_reduction", 1.0))
	PlayerData.crit_rate = float(payload.get("crit_rate", PlayerData.crit_rate))
	PlayerData.bonus_crit_rate = float(payload.get("bonus_crit_rate", 0.0))
	PlayerData.crit_damage = float(payload.get("crit_damage", PlayerData.crit_damage))
	PlayerData.bonus_crit_damage = float(payload.get("bonus_crit_damage", 1.0))
	PlayerData.grab_radius = float(payload.get("grab_radius", PlayerData.grab_radius))
	PlayerData.grab_radius_mutifactor = float(payload.get("grab_radius_multiplier", 1.0))
	PlayerData.player_gold = int(payload.get("gold", PlayerData.player_gold))
	PlayerData.round_coin_collected = int(payload.get("round_coin", 0))
	PlayerData.round_chip_collected = int(payload.get("round_chip", 0))
	PlayerData.run_total_damage_dealt = int(payload.get("run_damage", 0))
	PlayerData.run_enemy_kills = int(payload.get("run_kills", 0))
	PlayerData.run_elite_kills = int(payload.get("run_elite_kills", 0))
	PlayerData.run_completed_levels = int(payload.get("run_completed_levels", 0))
	PlayerData.run_gold_earned = int(payload.get("run_gold", 0))
	PlayerData.run_gold_recycled = int(payload.get("run_gold_recycled", 0))
	PlayerData.run_gold_spent = int(payload.get("run_gold_spent", 0))
	PlayerData.rounds_without_weapon_progress = int(payload.get("rounds_without_weapon_progress", 0))
	_clear_equipped_weapons()
	var player := PlayerData.player as Player
	if player:
		for weapon_variant in payload.get("weapons", []):
			if not (weapon_variant is Dictionary):
				continue
			var weapon_payload := weapon_variant as Dictionary
			var weapon := DataHandler.instantiate_weapon_from_save_payload(weapon_payload)
			if weapon:
				player.create_weapon(weapon)
				DataHandler.restore_weapon_runtime_from_save_payload(weapon, weapon_payload)
		PlayerData.set_main_weapon_index(int(payload.get("main_weapon_index", 0)))
	# Rebuilding weapon levels can emit normal progression side effects. The
	# rollback snapshot remains authoritative, so restore progression last.
	PlayerData.player_level = int(payload.get("level", PlayerData.player_level))
	PlayerData.next_level_exp = int(payload.get("next_exp", PlayerData.next_level_exp))
	PlayerData.player_exp = int(payload.get("exp", PlayerData.player_exp))

func _restore_inventory_state(payload: Dictionary) -> void:
	for module_instance in InventoryData.temporary_modules.duplicate():
		if module_instance and is_instance_valid(module_instance):
			module_instance.queue_free()
	InventoryData.temporary_modules.clear()
	for weapon in InventoryData.weapon_storage:
		if weapon and is_instance_valid(weapon):
			weapon.queue_free()
	InventoryData.weapon_storage.clear()
	for entry_variant in payload.get("temporary_modules", []):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var scene := load(str(entry.get("scene_path", ""))) as PackedScene
		var module_instance := scene.instantiate() as Module if scene else null
		if module_instance:
			module_instance.set_module_level(int(entry.get("level", 1)))
			InventoryData.add_child(module_instance)
			InventoryData.temporary_modules.append(module_instance)
	for weapon_variant in payload.get("weapon_storage", []):
		if not (weapon_variant is Dictionary):
			continue
		var weapon_payload := weapon_variant as Dictionary
		var weapon := DataHandler.instantiate_weapon_from_save_payload(weapon_payload)
		if weapon:
			InventoryData.add_child(weapon)
			DataHandler.restore_weapon_runtime_from_save_payload(weapon, weapon_payload)
			InventoryData.call("_transfer_weapon_modules_to_temporary", weapon)
			weapon.visible = false
			weapon.process_mode = Node.PROCESS_MODE_DISABLED
			InventoryData.weapon_storage.append(weapon)
	InventoryData.pending_transactions.clear()
	for transaction_variant in payload.get("pending_transactions", []):
		if transaction_variant is Dictionary:
			InventoryData.pending_transactions.append((transaction_variant as Dictionary).duplicate(true))
	InventoryData.temporary_modules_changed.emit()
	InventoryData.pending_transactions_changed.emit()
	InventoryData.weapon_storage_changed.emit()

func _clear_equipped_weapons() -> void:
	for weapon_ref in PlayerData.player_weapon_list.duplicate():
		var weapon := weapon_ref as Weapon
		if weapon and is_instance_valid(weapon):
			weapon.queue_free()
	PlayerData.player_weapon_list.clear()
	PlayerData.main_weapon_index = -1

func _serialize_reward(reward: RewardInfo) -> Dictionary:
	if reward == null:
		return {}
	return {
		"kind": str(reward.reward_kind),
		"chip": int(reward.total_chip_value),
		"gold": int(reward.gold_value),
		"item_id": reward.item_id,
		"item_level": int(reward.item_level),
		"module_path": str(reward.module_scene.resource_path) if reward.module_scene else "",
		"module_level": int(reward.module_level),
		"rarity": reward.rarity,
		"reward_key": reward.reward_key_override,
		"target_weapon_id": reward.target_weapon_id,
		"target_weapon_name": reward.target_weapon_name,
		"target_from": int(reward.target_weapon_from_level),
		"target_to": int(reward.target_weapon_to_level),
		"cell_effect_id": reward.cell_effect_id,
		"task_module_id": reward.task_module_id,
	}

func _deserialize_reward(payload: Dictionary) -> RewardInfo:
	var reward := RewardInfo.new()
	reward.reward_kind = StringName(str(payload.get("kind", RewardInfo.KIND_STANDARD)))
	reward.total_chip_value = int(payload.get("chip", 0))
	reward.gold_value = int(payload.get("gold", 0))
	reward.item_id = str(payload.get("item_id", ""))
	reward.item_level = int(payload.get("item_level", 0))
	var module_path := str(payload.get("module_path", ""))
	if module_path != "":
		reward.module_scene = load(module_path) as PackedScene
	reward.module_level = int(payload.get("module_level", 1))
	reward.rarity = str(payload.get("rarity", "common"))
	reward.reward_key_override = str(payload.get("reward_key", ""))
	reward.target_weapon_id = str(payload.get("target_weapon_id", ""))
	reward.target_weapon_name = str(payload.get("target_weapon_name", ""))
	reward.target_weapon_from_level = int(payload.get("target_from", 0))
	reward.target_weapon_to_level = int(payload.get("target_to", 0))
	reward.cell_effect_id = str(payload.get("cell_effect_id", ""))
	reward.task_module_id = str(payload.get("task_module_id", ""))
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		var weapon := _find_equipped_weapon(reward.target_weapon_id)
		if weapon:
			reward.target_weapon_ref = weakref(weapon)
	return reward

func _find_equipped_weapon(weapon_id: String) -> Weapon:
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon and DataHandler.get_weapon_id_from_instance(weapon) == weapon_id:
			return weapon
	return null

func _prepare_reward_for_grant(reward: RewardInfo) -> RewardInfo:
	if reward == null:
		return null
	if reward.reward_kind != RewardInfo.KIND_WEAPON_UPGRADE:
		return reward
	var weapon := _find_equipped_weapon(reward.target_weapon_id)
	if weapon and int(weapon.level) < int(weapon.max_level):
		reward.target_weapon_ref = weakref(weapon)
		return reward
	var converted := RewardInfo.new()
	converted.reward_kind = RewardInfo.KIND_ECONOMY
	converted.rarity = reward.rarity
	var weapon_def := DataHandler.read_weapon_data(reward.target_weapon_id) as WeaponDefinition
	var base_price := int(weapon_def.price) if weapon_def else 0
	converted.gold_value = _get_economy_config().get_duplicate_weapon_gold(base_price)
	return converted

func _save_state() -> void:
	var entry_payloads: Array[Dictionary] = []
	for entry in _pending_reward_entries:
		entry_payloads.append({
			"id": str(entry.get("id", "")),
			"status": str(entry.get("status", ENTRY_PENDING)),
			"reward": _serialize_reward(entry.get("reward", null) as RewardInfo),
		})
	var payload := {
		"battle_in_progress": _battle_in_progress,
		"reward_unlocked": _reward_unlocked,
		"pending_level": _pending_level,
		"unbuilt_bundle_count": _unbuilt_bundle_count,
		"next_reward_entry_id": _next_reward_entry_id,
		"entries": entry_payloads,
	}
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))

func _load_state() -> void:
	var payload := _read_json_dictionary(STATE_PATH)
	if payload.is_empty():
		return
	_battle_in_progress = bool(payload.get("battle_in_progress", false))
	_reward_unlocked = bool(payload.get("reward_unlocked", false))
	_pending_level = int(payload.get("pending_level", -1))
	_pending_reward_entries.clear()
	_unbuilt_bundle_count = maxi(int(payload.get("unbuilt_bundle_count", 0)), 0)
	_next_reward_entry_id = maxi(int(payload.get("next_reward_entry_id", 1)), 1)
	for entry_variant in payload.get("entries", []):
		if not (entry_variant is Dictionary):
			continue
		var entry_payload := entry_variant as Dictionary
		var reward_payload := entry_payload.get("reward", {}) as Dictionary
		var status := str(entry_payload.get("status", ENTRY_PENDING))
		if status == ENTRY_WAITING:
			status = ENTRY_PENDING
		_pending_reward_entries.append({
			"id": str(entry_payload.get("id", "task_reward_%d" % _next_reward_entry_id)),
			"status": status,
			"reward": _deserialize_reward(reward_payload),
		})
		_next_reward_entry_id += 1
	if payload.has("entries"):
		return
	var legacy_count := maxi(int(payload.get("pending_reward_count", 1 if _reward_unlocked else 0)), 0)
	_unbuilt_bundle_count = legacy_count
	_pending_reward_entries.clear()
	_next_reward_entry_id = 1

func _clear_pending_reward(save_after: bool) -> void:
	_pending_level = -1
	_pending_reward_entries.clear()
	_unbuilt_bundle_count = 0
	_next_reward_entry_id = 1
	_reward_unlocked = false
	_reward_panel_open = false
	_bundle_generation_warning_emitted = false
	pending_reward_changed.emit(false)
	if save_after:
		_save_state()

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed = parser.data
	return parsed as Dictionary if parsed is Dictionary else {}

func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _get_economy_config() -> EconomyConfig:
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data
	return EconomyConfig.new()
