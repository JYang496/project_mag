extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const DROP_SCENE := preload("res://Objects/loots/drop.tscn")
const DROP_ITEM_SCENE := preload("res://Objects/loots/drop_item.tscn")

var _flight_started := false
var _flight_finished := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	DataHandler.prepare_world_data()
	var economy := EconomyConfig.new()
	economy.battle_drop_weapon_chance = 0.0
	economy.battle_drop_module_chance = 0.0
	GlobalVariables.economy_data = economy

	var reward_manager := BonusManager.new()
	add_child(reward_manager)
	var rewards := reward_manager.build_completed_battle_drop_rewards(0, null)
	if rewards.size() != 1:
		_fail(1, "BattleDropStorageTest: fallback did not generate exactly one reward.")
		return
	var reward := rewards[0]
	if reward.item_id == "" and reward.module_scene == null:
		_fail(2, "BattleDropStorageTest: generated reward has no item.")
		return

	var player := PLAYER_SCENE.instantiate() as Player
	get_tree().root.add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	PlayerData.player = player
	PlayerData.max_weapon_num = 1
	if PlayerData.player_weapon_list.is_empty():
		_fail(3, "BattleDropStorageTest: player has no initial weapon.")
		return
	var stored_weapon_id := _find_unequipped_weapon_id()
	if stored_weapon_id == "":
		_fail(4, "BattleDropStorageTest: no warehouse weapon fixture found.")
		return
	var first_weapon := _instantiate_weapon(stored_weapon_id)
	var first_result := InventoryData.obtain_weapon_reward(first_weapon)
	if str(first_result.get("result", "")) != "stored" or InventoryData.weapon_storage.size() != 1:
		_fail(5, "BattleDropStorageTest: full loadout did not store the weapon.")
		return
	var stored_weapon := InventoryData.weapon_storage[0]
	var duplicate_result := InventoryData.obtain_weapon_reward(_instantiate_weapon(stored_weapon_id))
	if str(duplicate_result.get("result", "")) != "fused" or int(stored_weapon.fuse) != 2:
		_fail(6, "BattleDropStorageTest: stored duplicate did not fuse.")
		return

	InventoryData.save_runtime_state()
	stored_weapon.queue_free()
	InventoryData.weapon_storage.clear()
	await get_tree().process_frame
	InventoryData.load_runtime_state()
	if InventoryData.weapon_storage.size() != 1 \
			or int(InventoryData.weapon_storage[0].fuse) != 2:
		_fail(7, "BattleDropStorageTest: weapon warehouse did not restore.")
		return
	var equipped_weapon := PlayerData.player_weapon_list[0] as Weapon
	var module_scene := load("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn") as PackedScene
	var module_instance := module_scene.instantiate() as Module if module_scene else null
	if module_instance == null:
		_fail(8, "BattleDropStorageTest: failed to create module fixture.")
		return
	equipped_weapon.modules.add_child(module_instance)
	var exchange_result := InventoryData.exchange_stored_weapon(
		InventoryData.weapon_storage[0],
		equipped_weapon
	)
	if not exchange_result.get("ok", false) \
			or InventoryData.temporary_modules.size() != 1 \
			or InventoryData.weapon_storage[0].get_module_count() != 0:
		_fail(9, "BattleDropStorageTest: warehouse exchange retained weapon modules.")
		return
	player.call("_sync_weapon_orbit_states", true)
	var exchanged_weapon := PlayerData.player_weapon_list[0] as Weapon
	if exchanged_weapon == null or exchanged_weapon.get_parent() != player.equppied_weapons:
		_fail(10, "BattleDropStorageTest: exchanged weapon was not attached to EquippedWeapons.")
		return
	var arc_weapon_id := _find_unowned_weapon_id()
	if arc_weapon_id == "":
		_fail(11, "BattleDropStorageTest: no arc-drop weapon fixture found.")
		return
	var arc_drop := DROP_SCENE.instantiate()
	arc_drop.drop = DROP_ITEM_SCENE
	arc_drop.spawn_global_position = Vector2.ZERO
	arc_drop.item_id = arc_weapon_id
	arc_drop.level = 1
	arc_drop.settle_unclaimed_on_battle_start = true
	arc_drop.flight_duration = 1.0
	arc_drop.flight_started.connect(func(): _flight_started = true)
	arc_drop.flight_finished.connect(func(): _flight_finished = true)
	add_child(arc_drop)
	await get_tree().create_timer(0.35).timeout
	var landed_drop = arc_drop.drop_instance
	if not _flight_started or _flight_finished:
		_fail(12, "BattleDropStorageTest: flight animation timing signals are invalid.")
		return
	if InventoryData.weapon_storage.size() != 1:
		_fail(13, "BattleDropStorageTest: reward was collected before flight animation finished.")
		return
	if arc_drop.drop_instance == null \
			or absf(float(arc_drop.drop_instance.rotation)) < 0.1 \
			or arc_drop.drop_instance.global_position.distance_to(Vector2.ZERO) < 5.0:
		_fail(14, "BattleDropStorageTest: arc position or rotation animation was not visible.")
		return
	await get_tree().create_timer(0.9).timeout
	if not _flight_finished:
		_fail(15, "BattleDropStorageTest: flight animation did not finish.")
		return
	if InventoryData.weapon_storage.size() != 1 or landed_drop == null or not is_instance_valid(landed_drop):
		_fail(16, "BattleDropStorageTest: landed reward did not remain for interaction.")
		return
	if landed_drop.detect_area.get_collision_mask_value(1) == false:
		_fail(17, "BattleDropStorageTest: landed reward pickup detection was not activated.")
		return
	landed_drop.player_near = true
	var interact_event := InputEventAction.new()
	interact_event.action = &"INTERACT"
	interact_event.pressed = true
	Input.parse_input_event(interact_event)
	await get_tree().process_frame
	if InventoryData.weapon_storage.size() != 2:
		_fail(18, "BattleDropStorageTest: interacted reward was not collected through input dispatch.")
		return

	var arc_stored_weapon := _find_stored_weapon_by_id(arc_weapon_id)
	if arc_stored_weapon == null:
		_fail(19, "BattleDropStorageTest: interacted weapon was not stored.")
		return
	var fuse_before := int(arc_stored_weapon.fuse)
	var unclaimed_weapon_drop := DROP_ITEM_SCENE.instantiate()
	unclaimed_weapon_drop.item_id = arc_weapon_id
	unclaimed_weapon_drop.level = 1
	unclaimed_weapon_drop.spawn_ready = true
	unclaimed_weapon_drop.settle_unclaimed_on_battle_start = true
	add_child(unclaimed_weapon_drop)
	var unclaimed_module_drop := DROP_ITEM_SCENE.instantiate()
	unclaimed_module_drop.module_scene = module_scene
	unclaimed_module_drop.module_level = 1
	unclaimed_module_drop.spawn_ready = true
	unclaimed_module_drop.settle_unclaimed_on_battle_start = true
	add_child(unclaimed_module_drop)
	await get_tree().process_frame
	var unclaimed_module := unclaimed_module_drop.module_instance as Module
	if unclaimed_module == null:
		_fail(20, "BattleDropStorageTest: unclaimed module fixture failed to initialize.")
		return
	var gold_before := PlayerData.player_gold
	var expected_module_gold := economy.get_duplicate_module_gold(
		int(unclaimed_module.cost),
		int(unclaimed_module.module_level)
	)
	PhaseManager.enter_battle()
	await get_tree().process_frame
	if int(arc_stored_weapon.fuse) != fuse_before + 1:
		_fail(21, "BattleDropStorageTest: unclaimed weapon did not upgrade in warehouse.")
		return
	if PlayerData.player_gold != gold_before + expected_module_gold:
		_fail(22, "BattleDropStorageTest: unclaimed module was not automatically sold.")
		return
	if is_instance_valid(unclaimed_weapon_drop) or is_instance_valid(unclaimed_module_drop):
		_fail(23, "BattleDropStorageTest: settled drop nodes remained in the scene.")
		return

	InventoryData.reset_runtime_state()
	print("BattleDropStorageTest: PASS")
	get_tree().quit(0)

func _find_unequipped_weapon_id() -> String:
	var equipped_id := DataHandler.get_weapon_id_from_instance(PlayerData.player_weapon_list[0] as Weapon)
	for weapon_id in DataHandler.get_weapon_ids():
		if weapon_id != equipped_id:
			return weapon_id
	return ""

func _find_unowned_weapon_id() -> String:
	var owned: Dictionary = {}
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon:
			owned[DataHandler.get_weapon_id_from_instance(weapon)] = true
	for weapon in InventoryData.weapon_storage:
		if weapon:
			owned[DataHandler.get_weapon_id_from_instance(weapon)] = true
	for weapon_id in DataHandler.get_weapon_ids():
		if not owned.has(weapon_id):
			return weapon_id
	return ""

func _instantiate_weapon(weapon_id: String) -> Weapon:
	var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	return definition.scene.instantiate() as Weapon if definition and definition.scene else null

func _find_stored_weapon_by_id(weapon_id: String) -> Weapon:
	for weapon in InventoryData.weapon_storage:
		if weapon and DataHandler.get_weapon_id_from_instance(weapon) == weapon_id:
			return weapon
	return null

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
