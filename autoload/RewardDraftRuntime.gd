extends Node

signal pending_standard_draft_changed(has_pending: bool)

const STATE_PATH := "user://reward_draft_runtime_state.json"
const RARITY_UTIL := preload("res://data/LootRarity.gd")

var standard_draft_count: int = 0
var _pending_standard_draft_payloads: Array[Dictionary] = []
var _pending_context: Dictionary = {}
var _pending_draft_index: int = 0
var _pending_consumed_recorded := false

func _ready() -> void:
	_load_state()
	if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.connect(_on_phase_changed)

func get_next_standard_draft_index() -> int:
	if has_pending_standard_draft():
		return maxi(_pending_draft_index, standard_draft_count + 1)
	return standard_draft_count + 1

func get_standard_draft_stage_rules(economy_config: EconomyConfig = null) -> Dictionary:
	var economy := economy_config if economy_config != null else _get_economy_config()
	var draft_index := get_next_standard_draft_index()
	var early_count := economy.get_early_standard_draft_count()
	var is_early := draft_index <= early_count
	var normal_module_chance := 1.0 - economy.get_reward_weapon_option_chance()
	var module_chance := normal_module_chance
	if is_early:
		module_chance = economy.get_early_module_option_chance(draft_index)
	return {
		"draft_index": draft_index,
		"is_early": is_early,
		"reserve_weapon_progress_slot": is_early and economy.early_weapon_progress_slot_enabled,
		"module_option_chance": clampf(module_chance, 0.0, 1.0),
		"normal_economy_enabled": economy.early_economy_option_enabled if is_early else true,
		"allow_fallback_economy": economy.early_allow_fallback_economy if is_early else true,
	}

func set_pending_standard_draft(options: Array[RewardInfo], context: Dictionary = {}) -> void:
	_pending_standard_draft_payloads.clear()
	for reward in options:
		_pending_standard_draft_payloads.append(_serialize_reward(reward))
	_pending_context = context.duplicate(true)
	_pending_draft_index = int(_pending_context.get("draft_index", get_next_standard_draft_index()))
	_pending_consumed_recorded = false
	_save_state()
	pending_standard_draft_changed.emit(true)

func has_pending_standard_draft() -> bool:
	return not _pending_standard_draft_payloads.is_empty()

func get_pending_standard_draft_options() -> Array[RewardInfo]:
	var options: Array[RewardInfo] = []
	for payload in _pending_standard_draft_payloads:
		options.append(_deserialize_reward(payload))
	return options

func record_standard_draft_consumed() -> void:
	if has_pending_standard_draft():
		if not _pending_consumed_recorded:
			standard_draft_count = maxi(standard_draft_count, maxi(_pending_draft_index, 1))
			_pending_consumed_recorded = true
			_save_state()
		return
	standard_draft_count += 1
	_save_state()

func clear_pending_standard_draft(save_after: bool = true) -> void:
	_pending_standard_draft_payloads.clear()
	_pending_context.clear()
	_pending_draft_index = 0
	_pending_consumed_recorded = false
	pending_standard_draft_changed.emit(false)
	if save_after:
		_save_state()

func save_runtime_state() -> void:
	_save_state()

func reset_runtime_state(preserve_persistent_state: bool = false) -> void:
	if preserve_persistent_state:
		_load_state()
		return
	standard_draft_count = 0
	clear_pending_standard_draft(false)
	_delete_file(STATE_PATH)
	pending_standard_draft_changed.emit(false)

func build_battle_rollback_snapshot() -> Dictionary:
	return {
		"standard_draft_count": standard_draft_count,
		"pending_options": _pending_standard_draft_payloads.duplicate(true),
		"pending_context": _pending_context.duplicate(true),
		"pending_draft_index": _pending_draft_index,
		"pending_consumed_recorded": _pending_consumed_recorded,
	}

func restore_battle_rollback_snapshot(payload: Dictionary) -> void:
	standard_draft_count = maxi(int(payload.get("standard_draft_count", 0)), 0)
	_pending_standard_draft_payloads.clear()
	for option_variant in payload.get("pending_options", []):
		if option_variant is Dictionary:
			_pending_standard_draft_payloads.append((option_variant as Dictionary).duplicate(true))
	_pending_context = (payload.get("pending_context", {}) as Dictionary).duplicate(true) \
		if payload.get("pending_context", {}) is Dictionary else {}
	_pending_draft_index = maxi(int(payload.get("pending_draft_index", 0)), 0)
	_pending_consumed_recorded = bool(payload.get("pending_consumed_recorded", false))
	_save_state()
	pending_standard_draft_changed.emit(has_pending_standard_draft())

func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.GAMEOVER:
		reset_runtime_state(false)

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
	if module_path != "" and ResourceLoader.exists(module_path):
		reward.module_scene = load(module_path) as PackedScene
	reward.module_level = int(payload.get("module_level", 1))
	reward.rarity = RARITY_UTIL.normalize(str(payload.get("rarity", RARITY_UTIL.COMMON)))
	reward.reward_key_override = str(payload.get("reward_key", ""))
	reward.target_weapon_id = str(payload.get("target_weapon_id", ""))
	reward.target_weapon_name = str(payload.get("target_weapon_name", ""))
	reward.target_weapon_from_level = int(payload.get("target_from", 0))
	reward.target_weapon_to_level = int(payload.get("target_to", 0))
	if _reward_payload_is_invalid(reward, module_path):
		return _build_invalid_pending_fallback(payload)
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		var weapon := _find_equipped_weapon(reward.target_weapon_id)
		if weapon:
			reward.target_weapon_ref = weakref(weapon)
	return reward

func _reward_payload_is_invalid(reward: RewardInfo, module_path: String) -> bool:
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		var weapon := _find_equipped_weapon(reward.target_weapon_id)
		return weapon == null or int(weapon.level) >= int(weapon.max_level)
	if module_path.strip_edges() != "" and reward.module_scene == null:
		return true
	if reward.item_id.strip_edges() != "":
		return DataHandler.read_weapon_data(reward.item_id) == null
	return false

func _build_invalid_pending_fallback(payload: Dictionary) -> RewardInfo:
	var economy := _get_economy_config()
	var fallback := RewardInfo.new()
	fallback.reward_kind = RewardInfo.KIND_ECONOMY
	fallback.total_chip_value = economy.get_reward_economy_exp()
	fallback.gold_value = economy.get_reward_economy_gold()
	fallback.rarity = RARITY_UTIL.COMMON
	var old_key := str(payload.get("reward_key", "invalid"))
	if old_key.strip_edges() == "":
		old_key = "invalid"
	fallback.reward_key_override = "fallback_economy:%s" % old_key
	return fallback

func _find_equipped_weapon(weapon_id: String) -> Weapon:
	var normalized_id := weapon_id.strip_edges()
	if normalized_id == "":
		return null
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon and is_instance_valid(weapon) and DataHandler.get_weapon_id_from_instance(weapon) == normalized_id:
			return weapon
	return null

func _save_state() -> void:
	var payload := {
		"standard_draft_count": standard_draft_count,
		"pending_options": _pending_standard_draft_payloads,
		"pending_context": _pending_context,
		"pending_draft_index": _pending_draft_index,
		"pending_consumed_recorded": _pending_consumed_recorded,
	}
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))

func _load_state() -> void:
	var payload := _read_json_dictionary(STATE_PATH)
	if payload.is_empty():
		return
	standard_draft_count = maxi(int(payload.get("standard_draft_count", 0)), 0)
	_pending_standard_draft_payloads.clear()
	for option_variant in payload.get("pending_options", []):
		if option_variant is Dictionary:
			_pending_standard_draft_payloads.append((option_variant as Dictionary).duplicate(true))
	_pending_context = (payload.get("pending_context", {}) as Dictionary).duplicate(true) \
		if payload.get("pending_context", {}) is Dictionary else {}
	_pending_draft_index = maxi(int(payload.get("pending_draft_index", 0)), 0)
	_pending_consumed_recorded = bool(payload.get("pending_consumed_recorded", false))

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
