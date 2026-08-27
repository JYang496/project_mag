extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const SHOP_SLOT_SCENE := preload("res://UI/scenes/shop_weapon_slot.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failures := PackedStringArray()

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	DataHandler.prepare_world_data(true)
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	PhaseManager.phase = PhaseManager.PREPARE
	PlayerData.player_gold = 500
	var weapon := PlayerData.player_weapon_list[0] as Weapon
	var original_fuse := int(weapon.fuse)
	var definition := DataHandler.read_weapon_data("1") as WeaponDefinition
	var tags := definition.get_normalized_core_tags()
	var slot := SHOP_SLOT_SCENE.instantiate() as ShopWeaponSlot
	slot.item_id = "1"
	add_child(slot)
	await get_tree().process_frame
	slot.item_id = "1"
	slot.price = 100
	slot.refresh_affordability()
	var item_data: Dictionary = slot.call("_build_shop_item_data")
	var prediction := item_data.get("obtain_prediction", {}) as Dictionary
	_expect(str(prediction.get("result", "")) == "dismantled_to_core", "shop preview must identify a duplicate as one core")
	_expect(prediction.get("core_tags", []) == tags, "shop preview must show every inherent core Tag")
	_expect(int(prediction.get("current_core_count", -1)) == 0, "shop preview must show current stack count before payment")
	_expect(not (prediction.get("usable_branches", []) as Array).is_empty(), "shop preview branch usages must come from registered recipes")
	_expect(slot.lbl_description.autowrap_mode == TextServer.AUTOWRAP_OFF, "shop duplicate summary must remain a fixed single line")
	var slot_summary := str(slot.call("_format_duplicate_slot_summary", prediction))
	_expect(slot_summary.contains("4") and not slot_summary.contains("physical"), "shop duplicate summary must use a compact Tag count")
	slot.refresh_obtain_presentation()
	_expect(slot.core_badge.visible, "duplicate weapon shop card must show a core badge before selection")
	_expect(slot.equip_name.text != LocalizationManager.get_weapon_name_by_id("1", "Machine Gun"), "duplicate weapon shop card title must identify a transformed core item")
	_expect(slot.socket_2.text != definition.description and not slot.socket_2.text.is_empty(), "duplicate weapon shop card must explain the conversion before selection")
	var gold_before := PlayerData.player_gold
	_expect(slot.try_purchase(), "duplicate shop purchase must complete")
	_expect(PlayerData.player_gold == gold_before - 100, "shop must charge exactly once after duplicate preview")
	_expect(InventoryData.get_weapon_core_count(tags) == 1, "shop duplicate purchase must add one core")
	_expect(int(weapon.fuse) == original_fuse, "shop duplicate purchase must not change Fuse")
	_expect(PlayerData.player_weapon_list.size() == 1, "shop duplicate purchase must not add another weapon")
	await _finish()

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _finish() -> void:
	var code := 0
	if _failures.is_empty(): print("PASS: weapon core shop semantics")
	else:
		code = 1
		for failure in _failures: push_error(failure)
		print("FAIL: weapon core shop semantics")
	await TEST_TEARDOWN.finish(self, code, _reset)

func _reset() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
