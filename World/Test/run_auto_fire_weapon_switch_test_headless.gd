extends Node

class TestWeapon extends Weapon:
	var test_traits: Array[StringName] = []

	func has_weapon_trait(trait_name: Variant) -> bool:
		return test_traits.has(WeaponTrait.normalize(trait_name))


var _signal_count := 0
var _player_data: Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_player_data = get_tree().root.get_node_or_null("/root/PlayerData")
	if _player_data == null:
		_fail("missing PlayerData autoload")
		return
	_player_data.call("reset_runtime_state")
	_player_data.connect("main_weapon_index_changed", Callable(self, "_on_main_weapon_index_changed"))

	if not _assert_skips_auto_fire_forward():
		return
	if not _assert_skips_auto_fire_backward():
		return
	if not _assert_auto_fire_main_can_switch_out():
		return
	if not _assert_switch_reverts_when_only_auto_fire_targets_remain():
		return
	if not _assert_direct_set_can_select_auto_fire():
		return

	_player_data.disconnect("main_weapon_index_changed", Callable(self, "_on_main_weapon_index_changed"))
	_clear_test_weapons()
	_player_data.call("reset_runtime_state")
	print("PASS: auto-fire weapon switch skipping")
	get_tree().quit(0)


func _assert_skips_auto_fire_forward() -> bool:
	_set_weapons([
		_make_weapon(false),
		_make_weapon(true),
		_make_weapon(false),
	], 0)
	_signal_count = 0
	var changed := bool(_player_data.call("shift_main_weapon", 1))
	if not changed:
		return _fail("forward switch should find the next non-auto weapon")
	if int(_player_data.get("main_weapon_index")) != 2:
		return _fail("forward switch expected index 2, got %d" % int(_player_data.get("main_weapon_index")))
	if _signal_count != 1:
		return _fail("forward switch expected one change signal, got %d" % _signal_count)
	return true


func _assert_skips_auto_fire_backward() -> bool:
	_set_weapons([
		_make_weapon(false),
		_make_weapon(true),
		_make_weapon(false),
	], 2)
	_signal_count = 0
	var changed := bool(_player_data.call("shift_main_weapon", -1))
	if not changed:
		return _fail("backward switch should find the previous non-auto weapon")
	if int(_player_data.get("main_weapon_index")) != 0:
		return _fail("backward switch expected index 0, got %d" % int(_player_data.get("main_weapon_index")))
	if _signal_count != 1:
		return _fail("backward switch expected one change signal, got %d" % _signal_count)
	return true


func _assert_auto_fire_main_can_switch_out() -> bool:
	_set_weapons([
		_make_weapon(true),
		_make_weapon(true),
		_make_weapon(false),
	], 0)
	_signal_count = 0
	var changed := bool(_player_data.call("shift_main_weapon", 1))
	if not changed:
		return _fail("auto-fire main weapon should be allowed to switch out")
	if int(_player_data.get("main_weapon_index")) != 2:
		return _fail("auto-fire main switch expected index 2, got %d" % int(_player_data.get("main_weapon_index")))
	if _signal_count != 1:
		return _fail("auto-fire main switch expected one change signal, got %d" % _signal_count)
	return true


func _assert_switch_reverts_when_only_auto_fire_targets_remain() -> bool:
	_set_weapons([
		_make_weapon(false),
		_make_weapon(true),
		_make_weapon(true),
	], 0)
	_signal_count = 0
	var changed := bool(_player_data.call("shift_main_weapon", 1))
	if changed:
		return _fail("switch should return false when no non-auto target exists")
	if int(_player_data.get("main_weapon_index")) != 0:
		return _fail("failed switch should keep index 0, got %d" % int(_player_data.get("main_weapon_index")))
	if _signal_count != 0:
		return _fail("failed switch should not emit change signal, got %d" % _signal_count)
	return true


func _assert_direct_set_can_select_auto_fire() -> bool:
	_set_weapons([
		_make_weapon(false),
		_make_weapon(true),
	], 0)
	_player_data.call("set_main_weapon_index", 1)
	if int(_player_data.get("main_weapon_index")) != 1:
		return _fail("direct set_main_weapon_index should allow auto-fire weapon")
	return true


func _set_weapons(weapons: Array, main_index: int) -> void:
	_clear_test_weapons()
	_player_data.set("player_weapon_list", weapons)
	_player_data.set("main_weapon_index", main_index)
	_player_data.set("on_select_weapon", main_index)


func _clear_test_weapons() -> void:
	if _player_data == null:
		return
	var old_weapons: Array = _player_data.get("player_weapon_list")
	for old_weapon in old_weapons:
		if old_weapon != null and is_instance_valid(old_weapon):
			(old_weapon as Node).free()
	_player_data.set("player_weapon_list", [])


func _make_weapon(auto_fire: bool) -> TestWeapon:
	var weapon := TestWeapon.new()
	if auto_fire:
		weapon.test_traits.append(WeaponTrait.AUTO_FIRE)
	else:
		weapon.test_traits.append(WeaponTrait.PHYSICAL)
	return weapon


func _on_main_weapon_index_changed(_old_index: int, _new_index: int, _step: int) -> void:
	_signal_count += 1


func _fail(message: String) -> bool:
	push_error("FAIL: auto-fire weapon switch: %s" % message)
	if _player_data != null and _player_data.is_connected("main_weapon_index_changed", Callable(self, "_on_main_weapon_index_changed")):
		_player_data.disconnect("main_weapon_index_changed", Callable(self, "_on_main_weapon_index_changed"))
	if _player_data != null:
		_player_data.call("reset_runtime_state")
	get_tree().quit(1)
	return false
