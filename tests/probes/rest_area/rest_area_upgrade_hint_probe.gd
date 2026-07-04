extends Node

const HINT_PRESENTER := preload("res://World/rest_area_hint_presenter.gd")
const UPGRADE_VIEW := preload("res://UI/scripts/management/upgrade_management_view.gd")

var _old_gold := 0
var _old_player_weapons: Array = []
var _old_storage: Array[Weapon] = []
var _probe_weapon: Weapon

func _ready() -> void:
	_old_gold = PlayerData.player_gold
	_old_player_weapons = PlayerData.player_weapon_list.duplicate()
	_old_storage = InventoryData.weapon_storage.duplicate()

	var weapon_def := DataHandler.read_weapon_data("1") as WeaponDefinition
	if weapon_def == null or weapon_def.scene == null:
		_fail("missing weapon definition")
		return
	_probe_weapon = weapon_def.scene.instantiate() as Weapon
	if _probe_weapon == null:
		_fail("failed to instantiate weapon")
		return
	add_child(_probe_weapon)
	await get_tree().process_frame
	if _probe_weapon.has_method("refresh_max_level_from_data"):
		_probe_weapon.call("refresh_max_level_from_data")
	if _probe_weapon.has_method("set_level"):
		_probe_weapon.call("set_level", 1)
	else:
		_probe_weapon.level = 1

	PlayerData.player_weapon_list.clear()
	InventoryData.weapon_storage.clear()
	InventoryData.weapon_storage.append(_probe_weapon)
	PlayerData.player_gold = 9999

	var presenter = HINT_PRESENTER.new()
	var hint_count := int(presenter.call("_get_affordable_upgrade_count"))
	var view := UPGRADE_VIEW.new()
	var items := view.build_items(&"weapon")
	var stored_items := 0
	for item in items:
		if item is Dictionary and item.get("weapon") == _probe_weapon:
			stored_items += 1
	view.free()

	_restore_state()
	if hint_count == 1 and stored_items == 1:
		print("PASS rest_area_upgrade_hint_probe")
		get_tree().quit(0)
	else:
		push_error("expected stored weapon in hint and upgrade list, got hint=%d stored_items=%d" % [hint_count, stored_items])
		get_tree().quit(1)

func _fail(message: String) -> void:
	_restore_state()
	push_error(message)
	get_tree().quit(1)

func _restore_state() -> void:
	PlayerData.player_gold = _old_gold
	PlayerData.player_weapon_list.clear()
	PlayerData.player_weapon_list.append_array(_old_player_weapons)
	InventoryData.weapon_storage.clear()
	InventoryData.weapon_storage.append_array(_old_storage)
	if _probe_weapon != null and is_instance_valid(_probe_weapon):
		if _probe_weapon.get_parent() != null:
			_probe_weapon.get_parent().remove_child(_probe_weapon)
		_probe_weapon.free()
	_probe_weapon = null
