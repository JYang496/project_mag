extends Node

signal pending_reward_changed(has_pending: bool)

const STATE_PATH := "user://task_reward_state.json"
const ROLLBACK_PATH := "user://battle_rollback_snapshot.json"
const NORMAL_ROUTE_PATH := "res://data/routes/normal_route.tres"

var _pending_level: int = -1
var _pending_options: Array[RewardInfo] = []
var _reward_unlocked := false
var _reward_panel_open := false
var _battle_in_progress := false
var _restore_snapshot_on_world_start := false
var _reward_manager: BonusManager

func _ready() -> void:
	_load_state()
	if _battle_in_progress and FileAccess.file_exists(ROLLBACK_PATH):
		_restore_snapshot_on_world_start = true
		_clear_pending_reward(false)
	if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.connect(_on_phase_changed)

func is_enabled() -> bool:
	var economy := _get_economy_config()
	return economy.task_reward_options_enabled

func is_reward_blocking_interactions() -> bool:
	return _reward_unlocked and PhaseManager.current_state() == PhaseManager.PREPARE

func has_pending_reward() -> bool:
	return _reward_unlocked

func get_pending_reward_options() -> Array[RewardInfo]:
	return _pending_options.duplicate()

func notify_objective_completed(_cell_id: String = "") -> void:
	if not is_enabled() or PhaseManager.current_state() != PhaseManager.BATTLE:
		return
	if _reward_unlocked:
		return
	_reward_unlocked = true
	_pending_level = int(PhaseManager.current_level)
	_pending_options = _build_reward_options_from_current_state()
	_save_state()
	pending_reward_changed.emit(true)
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("show_item_message"):
		ui.show_item_message(LocalizationManager.tr_key(
			"ui.task_reward.unlocked",
			"Objective complete. Reward choice unlocked for the Rest Area."
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
	PhaseManager.current_level = maxi(int(snapshot.get("level", 0)), 0)
	RunRouteManager.restore_route_history(snapshot.get("route_history", {}) as Dictionary)
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
	_pending_options.clear()
	_reward_unlocked = false
	_battle_in_progress = false
	_restore_snapshot_on_world_start = false
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
		call_deferred("_try_open_pending_reward")
		return
	_save_state()
	_clear_pending_reward(true)
	call_deferred("_finalize_success_without_reward")

func _finalize_success_without_reward() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE or _reward_unlocked:
		return
	DataHandler.save_game(DataHandler.save_data)
	_delete_file(ROLLBACK_PATH)

func _try_open_pending_reward() -> void:
	if not _reward_unlocked or _reward_panel_open:
		return
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui) or not ui.has_method("request_task_reward_selection"):
		_retry_open_later()
		return
	if _pending_options.is_empty():
		_pending_options = _build_reward_options_from_current_state()
		_save_state()
	if _pending_options.is_empty():
		_retry_open_later()
		return
	_reward_panel_open = bool(ui.request_task_reward_selection(
		_pending_options,
		Callable(self, "_on_reward_selected")
	))
	if not _reward_panel_open:
		_retry_open_later()

func _retry_open_later() -> void:
	await get_tree().create_timer(0.2).timeout
	_try_open_pending_reward()

func _on_reward_selected(reward: RewardInfo) -> void:
	_reward_panel_open = false
	var manager := _resolve_reward_manager()
	var grant_reward := _prepare_reward_for_grant(reward)
	if manager == null or grant_reward == null or not manager.grant_reward_immediately(grant_reward):
		call_deferred("_try_open_pending_reward")
		return
	_clear_pending_reward(true)
	DataHandler.save_game(DataHandler.save_data)
	_delete_file(ROLLBACK_PATH)
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("resume_pending_weapon_branch_selection"):
		ui.call_deferred("resume_pending_weapon_branch_selection")

func _build_reward_options_from_current_state() -> Array[RewardInfo]:
	var manager := _resolve_reward_manager()
	if manager == null:
		return []
	var route := load(NORMAL_ROUTE_PATH) as RunRouteDefinition
	return manager.build_reward_selection_options(int(PhaseManager.current_level), route, 3)

func _resolve_reward_manager() -> BonusManager:
	if _reward_manager and is_instance_valid(_reward_manager):
		return _reward_manager
	var scene := get_tree().current_scene
	if scene:
		_reward_manager = scene.get_node_or_null("RewardManager") as BonusManager
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
		"route_history": RunRouteManager.get_route_history_snapshot(),
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
			"main_weapon_index": int(PlayerData.main_weapon_index),
			"weapons": weapon_payloads,
		},
		"inventory": {
			"temporary_modules": temporary_payloads,
			"weapon_storage": stored_weapon_payloads,
			"pending_transactions": InventoryData.pending_transactions.duplicate(true),
		},
	}

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
	var option_payloads: Array[Dictionary] = []
	for reward in _pending_options:
		option_payloads.append(_serialize_reward(reward))
	var payload := {
		"battle_in_progress": _battle_in_progress,
		"reward_unlocked": _reward_unlocked,
		"pending_level": _pending_level,
		"options": option_payloads,
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
	_pending_options.clear()
	for option_variant in payload.get("options", []):
		if option_variant is Dictionary:
			_pending_options.append(_deserialize_reward(option_variant as Dictionary))

func _clear_pending_reward(save_after: bool) -> void:
	_pending_level = -1
	_pending_options.clear()
	_reward_unlocked = false
	_reward_panel_open = false
	pending_reward_changed.emit(false)
	if save_after:
		_save_state()

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _get_economy_config() -> EconomyConfig:
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data
	return EconomyConfig.new()
