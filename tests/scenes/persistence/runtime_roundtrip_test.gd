extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_vampiric_surge.tscn")
const PISTOL_ID := "5"
const TASK_MODULE_ID := "task_clear_rare"

var _failures := PackedStringArray()
var _player: Player

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup_slot()
	_reset_runtime()
	DataHandler.prepare_world_data(true)
	CellEffectRuntime.load_definitions()
	CellTaskModuleRuntime.load_definitions()
	await _spawn_player()
	_seed_integrated_state()

	var save_result := SaveManager.commit_battle_success()
	_expect(bool(save_result.get("ok", false)), "victory commit must write the integrated run save")
	_expect(FileAccess.file_exists(SaveManager.RUN_PATH), "primary run document must exist")
	var post_battle_weapon := RewardInfo.new()
	post_battle_weapon.item_id = "1"
	post_battle_weapon.item_level = 1
	var reward_manager := BonusManager.new()
	add_child(reward_manager)
	reward_manager.call("_on_standard_battle_reward_selected", post_battle_weapon)
	_expect(PlayerData.player_weapon_list.size() == 2, "selected post-battle weapon must be granted before exit")
	_expect(not RewardDraftRuntime.has_pending_standard_draft(), "selected post-battle draft must be settled")

	_discard_memory_state()
	var continue_result := SaveManager.prepare_continue()
	_expect(bool(continue_result.get("ok", false)), "saved run must prepare for continue")
	var before_result := SaveManager.restore_before_world()
	_expect(bool(before_result.get("ok", false)), "pre-world state must restore")
	await _spawn_player()
	var after_result := SaveManager.restore_after_player_spawn()
	_expect(bool(after_result.get("ok", false)), "player-bound state must restore")

	_assert_integrated_state()
	_expect(not bool(SaveManager.restore_after_player_spawn().get("ok", true)), "integrated restore must be one-shot")

	_cleanup_slot()
	_reset_runtime()
	await get_tree().process_frame
	await get_tree().process_frame
	_finish()

func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame

func _seed_integrated_state() -> void:
	for weapon_ref in PlayerData.player_weapon_list.duplicate():
		var default_weapon := weapon_ref as Weapon
		if default_weapon and is_instance_valid(default_weapon):
			default_weapon.free()
	PlayerData.player_weapon_list.clear()
	var weapon := DataHandler.instantiate_weapon_from_save_payload({"weapon_id": PISTOL_ID, "level": 2, "fuse": 2})
	_player.create_weapon(weapon)
	weapon.fuse = 2
	DataHandler.restore_weapon_runtime_from_save_payload(weapon, {"level": 2, "fuse": 2, "branch_ids": [], "modules": []})

	var temporary := MODULE_SCENE.instantiate() as Module
	temporary.set_module_level(3)
	InventoryData.add_child(temporary)
	InventoryData.temporary_modules.append(temporary)
	InventoryData.pending_transactions.append({"kind": "integrated_test", "gold": 17})

	var effect_id := _first_definition_id(CellEffectRuntime.get("_definitions_by_id"))
	_expect(effect_id != "" and CellEffectRuntime.grant_effect(effect_id, 2), "cell effect seed must succeed")
	_expect(bool(CellEffectRuntime.set_pending_effect(2, effect_id).get("ok", false)), "pending cell edit seed must succeed")
	_expect(bool(CellTaskModuleRuntime.grant_module(TASK_MODULE_ID).get("ok", false)), "task module seed must succeed")

	var reward := RewardInfo.new()
	reward.reward_kind = RewardInfo.KIND_ECONOMY
	reward.gold_value = 37
	reward.total_chip_value = 11
	reward.reward_key_override = "integrated-save"
	RewardDraftRuntime.standard_draft_count = 2
	RewardDraftRuntime.set_pending_standard_draft([reward], {"draft_index": 3})
	BattleContractManager.last_selected_id = &"operation"
	BattleContractManager.consecutive_selection_count = 2
	BattleContractManager.missed_offer_counts[&"survival"] = 3

	PhaseManager.current_level = 4
	PlayerData.select_mecha_id = 1
	PlayerData.player_level = 4
	PlayerData.next_level_exp = 91
	PlayerData.player_exp = 37
	PlayerData.player_max_hp = 140
	PlayerData.player_hp = 61
	PlayerData.player_gold = 120
	PlayerData.run_enemy_kills = 9

func _discard_memory_state() -> void:
	if _player and is_instance_valid(_player):
		_player.free()
	_player = null
	_reset_runtime()
	PhaseManager.current_level = 99
	PlayerData.player_gold = 999

func _assert_integrated_state() -> void:
	_expect(PhaseManager.current_level == 4, "level must restore from the slot document")
	_expect(PlayerData.player_level == 4 and PlayerData.player_exp == 37, "player progression must restore")
	_expect(PlayerData.player_hp == 61 and PlayerData.player_gold == 120, "player hp and gold must restore")
	_expect(PlayerData.run_enemy_kills == 9, "run counters must restore")
	_expect(PlayerData.player_weapon_list.size() == 2, "equipped weapons, including the selected post-battle weapon, must restore")
	var restored_ids: Array[String] = []
	for weapon_ref in PlayerData.player_weapon_list:
		var payload := DataHandler.build_weapon_save_payload(weapon_ref as Weapon)
		restored_ids.append(str(payload.get("weapon_id", "")))
		if str(payload.get("weapon_id", "")) == PISTOL_ID:
			_expect(int(payload.get("level", 0)) == 2 and int(payload.get("fuse", 0)) == 2, "weapon progression must restore")
	_expect(PISTOL_ID in restored_ids and "1" in restored_ids, "post-battle weapon selection must survive continue")
	_expect(InventoryData.temporary_modules.size() == 1, "temporary module must restore")
	_expect(InventoryData.pending_transactions.size() == 1, "pending transaction must restore")
	_expect(not CellEffectRuntime.get_inventory_snapshot().is_empty(), "cell effect inventory must restore")
	_expect(str(CellEffectRuntime.get_pending_snapshot().get("2", "")) != "", "pending cell edit must restore")
	_expect(CellTaskModuleRuntime.get_inventory_snapshot().has(TASK_MODULE_ID), "task module inventory must restore")
	_expect(RewardDraftRuntime.standard_draft_count == 2 and not RewardDraftRuntime.has_pending_standard_draft(), "settled reward draft state must restore")
	_expect(str(BattleContractManager.last_selected_id) == "operation", "contract history must restore")
	_expect(BattleContractManager.consecutive_selection_count == 2, "contract streak must restore")

func _first_definition_id(definitions: Dictionary) -> String:
	return str(definitions.keys()[0]) if not definitions.is_empty() else ""

func _reset_runtime() -> void:
	PhaseManager.reset_runtime_state()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state(false)
	RewardDraftRuntime.reset_runtime_state(false)
	BattleContractManager.reset_persistent_state()
	SaveManager.set("_pending_restore", {})

func _cleanup_slot() -> void:
	for path in [SaveManager.RUN_PATH, SaveManager.BACKUP_PATH, SaveManager.CHECKPOINT_PATH, SaveManager.MANIFEST_PATH]:
		for candidate in [path, path + ".tmp"]:
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	SaveManager.set("_revision", 0)
	SaveManager.set("_pending_restore", {})

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PASS persistence runtime roundtrip")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("FAIL persistence runtime roundtrip")
	get_tree().quit(1)
