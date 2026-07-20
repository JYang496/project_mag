extends Node

const TEST_ID := "world.battle_rollback_roundtrip"
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const PISTOL_ID := "5"
const PISTOL_BRANCH := "arc_coil"
const MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_vampiric_surge.tscn")
const ELIMINATION := preload("res://data/battle_contracts/elimination.tres")
const SURVIVAL := preload("res://data/battle_contracts/survival.tres")

var failures: PackedStringArray = []
var player: Player

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup(true)
	var prepare_result := DataHandler.prepare_world_data(true)
	_expect(bool(prepare_result.get("ok", false)), "runtime catalogs must load")
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	_seed_pre_battle_state()
	_expect(PlayerData.player_level == 4 and PlayerData.player_exp == 37, "seeded progression must match the intended pre-battle state")
	_expect(TaskRewardManager.begin_battle_snapshot(), "snapshot must be created in prepare phase")
	_expect(FileAccess.file_exists(TaskRewardManager.ROLLBACK_PATH), "rollback file must exist")
	_pollute_battle_state()

	_expect(TaskRewardManager.prepare_world_start(), "unfinished battle must schedule rollback")
	_expect(TaskRewardManager.restore_snapshot_after_player_spawn(), "scheduled rollback must restore")
	_assert_restored_state()
	_expect(not TaskRewardManager.restore_snapshot_after_player_spawn(), "restore must be idempotent")
	_expect(PlayerData.player_weapon_list.size() == 1, "second restore must not duplicate equipped weapons")
	_expect(not FileAccess.file_exists(TaskRewardManager.ROLLBACK_PATH), "successful rollback must consume snapshot")
	await get_tree().process_frame

	# A malformed snapshot is a safe failure: no crash, no partial restoration loop.
	PhaseManager.phase = PhaseManager.PREPARE
	_expect(TaskRewardManager.begin_battle_snapshot(), "second snapshot setup must succeed")
	var corrupt := FileAccess.open(TaskRewardManager.ROLLBACK_PATH, FileAccess.WRITE)
	if corrupt:
		corrupt.store_string("{ definitely-not-json")
	_expect(TaskRewardManager.prepare_world_start(), "corrupt unfinished snapshot must still schedule an attempt")
	_expect(not TaskRewardManager.restore_snapshot_after_player_spawn(), "corrupt snapshot must fail safely")
	_expect(not TaskRewardManager.restore_snapshot_after_player_spawn(), "corrupt restore failure must not loop")

	_cleanup(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_finish()

func _seed_pre_battle_state() -> void:
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 3
	for weapon_ref in PlayerData.player_weapon_list.duplicate():
		var default_weapon := weapon_ref as Weapon
		if default_weapon and is_instance_valid(default_weapon):
			default_weapon.free()
	PlayerData.player_weapon_list.clear()

	var equipped := DataHandler.instantiate_weapon_from_save_payload({"weapon_id": PISTOL_ID, "level": 3, "fuse": 2})
	player.create_weapon(equipped)
	equipped.level = 3
	equipped.fuse = 2
	equipped.branch_runtime.restore_branch_ids([PISTOL_BRANCH])
	var weapon_module := MODULE_SCENE.instantiate() as Module
	weapon_module.set_module_level(2)
	equipped.modules.add_child(weapon_module)

	var stored := DataHandler.instantiate_weapon_from_save_payload({"weapon_id": PISTOL_ID, "level": 2, "fuse": 1})
	InventoryData.add_child(stored)
	stored.visible = false
	InventoryData.weapon_storage.append(stored)
	var temporary := MODULE_SCENE.instantiate() as Module
	temporary.set_module_level(3)
	InventoryData.add_child(temporary)
	InventoryData.temporary_modules.append(temporary)
	InventoryData.pending_transactions.append({"kind": "test_purchase", "gold": 17})

	BattleContractManager.set_offer([ELIMINATION, SURVIVAL])
	BattleContractManager.select_contract(ELIMINATION)
	RewardDraftRuntime.standard_draft_count = 2
	# Weapon creation can apply progression side effects; the snapshot authority is
	# the fully prepared state immediately before battle entry.
	PlayerData.player_level = 4
	PlayerData.next_level_exp = 91
	PlayerData.player_exp = 37
	PlayerData.player_max_hp = 140
	PlayerData.player_hp = 61
	PlayerData.player_gold = 120
	PlayerData.run_enemy_kills = 9
	PlayerData.run_gold_earned = 44

func _pollute_battle_state() -> void:
	PhaseManager.current_level = 99
	PlayerData.player_level = 12
	PlayerData.player_exp = 999
	PlayerData.player_hp = 1
	PlayerData.player_gold = 1119
	PlayerData.run_enemy_kills = 999
	PlayerData.run_gold_earned = 999
	for weapon_ref in PlayerData.player_weapon_list.duplicate():
		var weapon := weapon_ref as Weapon
		if weapon:
			weapon.queue_free()
	PlayerData.player_weapon_list.clear()
	for module_ref in InventoryData.temporary_modules.duplicate():
		var module := module_ref as Module
		if module:
			module.queue_free()
	InventoryData.temporary_modules.clear()
	InventoryData.pending_transactions.clear()
	BattleContractManager.reset_runtime_state()
	RewardDraftRuntime.standard_draft_count = 77

func _assert_restored_state() -> void:
	_expect(PhaseManager.current_level == 3, "level must roll back")
	_expect(PlayerData.player_level == 4 and PlayerData.player_exp == 37, "player progression must roll back (level=%d exp=%d)" % [PlayerData.player_level, PlayerData.player_exp])
	_expect(PlayerData.player_hp == 61 and PlayerData.player_gold == 120, "hp and gold must roll back")
	_expect(PlayerData.run_enemy_kills == 9 and PlayerData.run_gold_earned == 44, "run counters must roll back")
	_expect(PlayerData.player_weapon_list.size() == 1, "battle weapons must be replaced by equipped snapshot (count=%d)" % PlayerData.player_weapon_list.size())
	if PlayerData.player_weapon_list.size() == 1:
		var weapon := PlayerData.player_weapon_list[0] as Weapon
		var payload := DataHandler.build_weapon_save_payload(weapon)
		_expect(str(payload.get("weapon_id", "")) == PISTOL_ID, "equipped weapon identity must restore")
		_expect(int(payload.get("level", 0)) == 3 and int(payload.get("fuse", 0)) == 2, "weapon level and fuse must restore")
		_expect(PISTOL_BRANCH in payload.get("branch_ids", []), "weapon branch must restore")
		var modules: Array = payload.get("modules", [])
		_expect(modules.size() == 1 and int(modules[0].get("level", 0)) == 2, "equipped module and level must restore")
	_expect(InventoryData.weapon_storage.size() == 1, "stored weapon must restore")
	_expect(InventoryData.temporary_modules.size() == 1, "temporary module must restore")
	if InventoryData.temporary_modules.size() == 1:
		_expect(int((InventoryData.temporary_modules[0] as Module).module_level) == 3, "temporary module level must restore")
	_expect(InventoryData.pending_transactions.size() == 1, "one pending transaction must restore")
	if InventoryData.pending_transactions.size() == 1:
		var transaction: Dictionary = InventoryData.pending_transactions[0]
		_expect(str(transaction.get("kind", "")) == "test_purchase" and int(transaction.get("gold", 0)) == 17, "pending transaction values must restore (actual=%s)" % str(transaction))
	_expect(BattleContractManager.state == BattleContractManager.SELECTED, "contract selection state must restore")
	_expect(BattleContractManager.selected_contract == ELIMINATION, "selected contract identity must restore")
	_expect(BattleContractManager.restored_selection_pending, "restored contract must require reconfirmation flow")
	_expect(RewardDraftRuntime.standard_draft_count == 2, "reward draft state must restore")

func _cleanup(delete_persistent: bool) -> void:
	if player and is_instance_valid(player):
		player.queue_free()
	player = null
	PlayerData.player = null
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	RewardDraftRuntime.reset_runtime_state(false)
	BattleContractManager.reset_persistent_state()
	TaskRewardManager.reset_runtime_state(not delete_persistent)
	PhaseManager.reset_runtime_state()
	if delete_persistent:
		for path in [TaskRewardManager.STATE_PATH, TaskRewardManager.ROLLBACK_PATH]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS %s" % TEST_ID)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FAIL %s" % TEST_ID)
	get_tree().quit(1)
