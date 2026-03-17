extends Node

const TEST_WEAPON_SCENE := preload("res://Utility/tests/mocks/test_weapon.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/prototype.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")

const MODULE_DAMAGE_UP := preload("res://Player/Weapons/Modules/damage_up.tscn")
const MODULE_FASTER_RELOAD := preload("res://Player/Weapons/Modules/faster_reload.tscn")
const MODULE_MORE_HP := preload("res://Player/Weapons/Modules/more_hp.tscn")
const MODULE_PIERCE := preload("res://Player/Weapons/Modules/pierce.tscn")
const MODULE_STUN := preload("res://Player/Weapons/Modules/stun_on_hit.tscn")
const MODULE_SLOW := preload("res://Player/Weapons/Modules/slow_on_hit.tscn")
const MODULE_LIFE_STEAL := preload("res://Player/Weapons/Modules/life_steal.tscn")
const MODULE_LIGHTNING := preload("res://Player/Weapons/Modules/lightning_chain.tscn")
const GF_CONFIRM_BUTTON_SCRIPT := preload("res://UI/scripts/gf_confirm_btn.gd")
const TEST_ENEMY_SCRIPT := preload("res://Utility/tests/mocks/test_enemy.gd")

var all_traits_mask: int = 0

var _pass_count: int = 0
var _fail_count: int = 0
var _messages: PackedStringArray = []

func _ready() -> void:
	all_traits_mask = (1 << CombatTrait.FLAG_ORDER.size()) - 1
	await run_all_tests()

func run_all_tests() -> void:
	_print_header("Weapon Module Test Runner")
	await _test_module_activation_smoke()
	await _test_module_obtain_upgrade_convert()
	await _test_compatibility_guard_pierce()
	await _test_fuse_integrity()
	await _test_runtime_stability_and_cleanup()
	_print_summary()

func _test_module_activation_smoke() -> void:
	await _reset_runtime_state()
	var weapon := _spawn_test_weapon("SmokeWeapon", true, false)
	weapon.base_damage = 10
	weapon.base_attack_cooldown = 2.0
	weapon.base_projectile_hits = 1
	weapon.base_hp = 3
	weapon.modules.weapon_traits = all_traits_mask

	weapon.modules.add_child(MODULE_DAMAGE_UP.instantiate())
	weapon.modules.add_child(MODULE_FASTER_RELOAD.instantiate())
	weapon.modules.add_child(MODULE_MORE_HP.instantiate())
	weapon.modules.add_child(MODULE_PIERCE.instantiate())

	await _wait_frames(2)
	weapon.sync_stats()

	_assert_eq_int(weapon.damage, 15, "Smoke: DamageUp applies")
	_assert_near(weapon.attack_cooldown, 1.4, 0.001, "Smoke: FasterReload applies")
	_assert_eq_int(weapon.projectile_hits, 3, "Smoke: Pierce applies")
	_assert_eq_int(weapon.hp, 5, "Smoke: MoreHP applies")

	var weapon_reentered := weapon.duplicate() as TestWeapon
	weapon.queue_free()
	await _wait_frames(2)
	add_child(weapon_reentered)
	await _wait_frames(2)
	weapon_reentered.sync_stats()

	_assert_eq_int(weapon_reentered.damage, 15, "Re-enter: DamageUp still applies")
	_assert_near(weapon_reentered.attack_cooldown, 1.4, 0.001, "Re-enter: FasterReload still applies")
	_assert_eq_int(weapon_reentered.projectile_hits, 3, "Re-enter: Pierce still applies")
	_assert_eq_int(weapon_reentered.hp, 5, "Re-enter: MoreHP still applies")

func _test_module_obtain_upgrade_convert() -> void:
	await _reset_runtime_state()
	var module_a := MODULE_DAMAGE_UP.instantiate() as Module
	InventoryData.obtain_module(module_a)
	_assert_eq_int(InventoryData.moddule_slots.size(), 1, "Obtain: First module is stored")
	var existing := InventoryData.moddule_slots[0] as Module
	_assert_eq_int(existing.module_level, 1, "Obtain: First module starts at Lv.1")

	var module_b := MODULE_DAMAGE_UP.instantiate() as Module
	InventoryData.obtain_module(module_b)
	_assert_eq_int(InventoryData.moddule_slots.size(), 1, "Obtain: Duplicate module does not add new slot")
	_assert_eq_int(existing.module_level, 2, "Obtain: Duplicate upgrades existing module to Lv.2")

	existing.set_module_level(Module.MAX_LEVEL)
	var gold_before := PlayerData.player_gold
	var module_c := MODULE_DAMAGE_UP.instantiate() as Module
	InventoryData.obtain_module(module_c)
	_assert_eq_int(existing.module_level, Module.MAX_LEVEL, "Obtain: Module stays at max level")
	_assert_true(PlayerData.player_gold > gold_before, "Obtain: Max-level duplicate converts into gold")

func _test_compatibility_guard_pierce() -> void:
	await _reset_runtime_state()
	var melee_weapon := _spawn_test_weapon("MeleeOnly", false, true)
	melee_weapon.modules.weapon_traits = CombatTrait.traits_to_flags([CombatTrait.MELEE, CombatTrait.PHYSICAL])
	var pierce_module := MODULE_PIERCE.instantiate()
	InventoryData.moddule_slots.append(pierce_module)
	InventoryData.on_select_inventory_module = pierce_module
	InventoryData.on_select_module_weapon = melee_weapon
	await _wait_frames(2)

	_assert_eq_int(melee_weapon.modules.get_child_count(), 0, "Compat: Pierce blocked on melee-only weapon")
	_assert_true(InventoryData.moddule_slots.has(pierce_module), "Compat: Blocked module stays in inventory module slots")

	var ranged_weapon := _spawn_test_weapon("RangedOnly", true, false)
	ranged_weapon.modules.weapon_traits = CombatTrait.traits_to_flags([CombatTrait.PROJECTILE, CombatTrait.PHYSICAL])
	InventoryData.on_select_inventory_module = pierce_module
	InventoryData.on_select_module_weapon = ranged_weapon
	await _wait_frames(2)

	_assert_eq_int(ranged_weapon.modules.get_child_count(), 1, "Compat: Pierce installs on ranged weapon")
	_assert_false(InventoryData.moddule_slots.has(pierce_module), "Compat: Installed module removed from inventory module slots")

func _test_fuse_integrity() -> void:
	await _reset_runtime_state()
	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	var ui := UI_SCENE.instantiate()
	add_child(ui)
	await _wait_frames(2)

	var weapon_a := _create_inventory_weapon("FuseBase")
	var weapon_b := _create_inventory_weapon("FuseBase")
	add_child(weapon_a)
	add_child(weapon_b)
	await _wait_frames(2)
	weapon_a.modules.add_child(MODULE_DAMAGE_UP.instantiate())
	weapon_a.modules.add_child(MODULE_FASTER_RELOAD.instantiate())
	weapon_b.modules.add_child(MODULE_PIERCE.instantiate())

	InventoryData.inventory_slots.append(weapon_a)
	InventoryData.inventory_slots.append(weapon_b)
	InventoryData.ready_to_fuse_list = [weapon_a, weapon_b]
	InventoryData.moddule_slots.clear()

	var confirm_btn := Button.new()
	confirm_btn.set_script(GF_CONFIRM_BUTTON_SCRIPT)
	add_child(confirm_btn)
	confirm_btn._on_button_up()
	await _wait_frames(6)

	var fused_weapon := _find_fused_test_weapon(2)
	_assert_true(fused_weapon != null, "Fuse: Created fused weapon")
	if fused_weapon == null:
		_debug_print_weapon_list("Fuse debug: equipped weapons after confirm")
	if fused_weapon:
		_assert_eq_int(int(fused_weapon.fuse), 2, "Fuse: Result fuse level increased to 2")
		_assert_eq_int(fused_weapon.modules.get_child_count(), 2, "Fuse: Base weapon modules preserved on fused result")
	_assert_eq_int(InventoryData.moddule_slots.size(), 1, "Fuse: Only non-base weapon modules salvaged")
	if InventoryData.moddule_slots.size() == 1:
		var salvaged_name: Variant = InventoryData.moddule_slots[0].get("ITEM_NAME")
		_assert_eq_str(str(salvaged_name), "Pierce", "Fuse: Salvaged module comes from non-base weapon")

func _test_runtime_stability_and_cleanup() -> void:
	await _reset_runtime_state()
	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	await _wait_frames(2)

	PlayerData.player_hp = 1
	PlayerData.player_max_hp = 10

	var weapon := _spawn_test_weapon("OnHit", true, false)
	weapon.modules.weapon_traits = all_traits_mask
	weapon.fuse = 1

	var stun_module = MODULE_STUN.instantiate()
	stun_module.base_chance = 1.0
	var slow_module = MODULE_SLOW.instantiate()
	slow_module.chance = 1.0
	var life_steal_module = MODULE_LIFE_STEAL.instantiate()
	var lightning_module = MODULE_LIGHTNING.instantiate()
	weapon.modules.add_child(stun_module)
	weapon.modules.add_child(slow_module)
	weapon.modules.add_child(life_steal_module)
	weapon.modules.add_child(lightning_module)

	var primary_enemy := TEST_ENEMY_SCRIPT.new() as TestEnemy
	primary_enemy.add_to_group("enemies")
	primary_enemy.global_position = Vector2.ZERO
	add_child(primary_enemy)

	var chained_enemy := TEST_ENEMY_SCRIPT.new() as TestEnemy
	chained_enemy.add_to_group("enemies")
	chained_enemy.global_position = Vector2(20, 0)
	add_child(chained_enemy)

	await _wait_frames(2)
	weapon.on_hit_target(primary_enemy)
	await _wait_frames(2)

	var payload_ids: Array[String] = []
	for payload_entry in primary_enemy.status_payloads:
		payload_ids.append(str(payload_entry.get("id", "")))
	_assert_true(payload_ids.has("stun"), "On-hit: Stun payload applied")
	_assert_true(payload_ids.has("slow"), "On-hit: Slow payload applied")
	_assert_true(PlayerData.player_hp > 1, "On-hit: LifeSteal recovers player HP")
	_assert_true(chained_enemy.received_attacks.size() > 0, "On-hit: Lightning chain damages nearby enemy")

	weapon._on_tree_exited()
	_assert_eq_int(weapon.on_hit_plugins.size(), 0, "Cleanup: on-hit plugins cleared on tree exit")
	_assert_true(weapon.branch_behavior == null, "Cleanup: branch behavior cleared on tree exit")
	_assert_true(weapon.branch_definition == null, "Cleanup: branch definition cleared on tree exit")

func _spawn_test_weapon(item_name: String, projectiles: bool, melee: bool) -> TestWeapon:
	var weapon := TEST_WEAPON_SCENE.instantiate() as TestWeapon
	weapon.ITEM_NAME = item_name
	weapon.projectile_enabled = projectiles
	weapon.melee_enabled = melee
	add_child(weapon)
	return weapon

func _create_inventory_weapon(item_name: String) -> TestWeapon:
	var weapon := TEST_WEAPON_SCENE.instantiate() as TestWeapon
	weapon.ITEM_NAME = item_name
	weapon.projectile_enabled = true
	weapon.melee_enabled = false
	return weapon

func _find_fused_test_weapon(expected_fuse: int) -> Weapon:
	for weapon in PlayerData.player_weapon_list:
		if not is_instance_valid(weapon):
			continue
		if weapon is TestWeapon and int(weapon.fuse) == expected_fuse:
			return weapon
	for weapon in PlayerData.player_weapon_list:
		if not is_instance_valid(weapon):
			continue
		if weapon is TestWeapon and int(weapon.fuse) >= expected_fuse:
			return weapon
	return null

func _get_weapon_item_name(weapon: Weapon) -> String:
	if weapon == null:
		return ""
	var name_value: Variant = null
	if "ITEM_NAME" in weapon:
		name_value = weapon.ITEM_NAME
	else:
		name_value = weapon.get("ITEM_NAME")
	if name_value == null:
		return ""
	return str(name_value)

func _reset_runtime_state() -> void:
	for child in get_children():
		child.queue_free()
	await _wait_frames(2)
	if GlobalVariables.has_method("reset_runtime_state"):
		GlobalVariables.reset_runtime_state()
	if InventoryData.has_method("reset_runtime_state"):
		InventoryData.reset_runtime_state()
	if PlayerData.has_method("reset_runtime_state"):
		PlayerData.reset_runtime_state()
	await _wait_frames(1)

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass(message)
	else:
		_fail(message)

func _assert_false(condition: bool, message: String) -> void:
	_assert_true(not condition, message)

func _assert_eq_int(actual: int, expected: int, message: String) -> void:
	if actual == expected:
		_pass("%s (actual=%d)" % [message, actual])
	else:
		_fail("%s (expected=%d actual=%d)" % [message, expected, actual])

func _assert_eq_str(actual: String, expected: String, message: String) -> void:
	if actual == expected:
		_pass("%s (actual=%s)" % [message, actual])
	else:
		_fail("%s (expected=%s actual=%s)" % [message, expected, actual])

func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) <= tolerance:
		_pass("%s (actual=%.3f)" % [message, actual])
	else:
		_fail("%s (expected=%.3f actual=%.3f)" % [message, expected, actual])

func _pass(message: String) -> void:
	_pass_count += 1
	var line := "[PASS] %s" % message
	_messages.append(line)
	print(line)

func _fail(message: String) -> void:
	_fail_count += 1
	var line := "[FAIL] %s" % message
	_messages.append(line)
	push_error(line)

func _print_header(title: String) -> void:
	print("")
	print("========== %s ==========" % title)

func _print_summary() -> void:
	print("")
	print("========== Test Summary ==========")
	print("Passed: %d" % _pass_count)
	print("Failed: %d" % _fail_count)
	if _fail_count == 0:
		print("Result: PASS")
	else:
		print("Result: FAIL")

func _debug_print_weapon_list(label: String) -> void:
	print(label)
	for i in range(PlayerData.player_weapon_list.size()):
		var weapon: Variant = PlayerData.player_weapon_list[i]
		if weapon == null or not is_instance_valid(weapon):
			print("  [%d] <invalid>" % i)
			continue
		print("  [%d] name=%s fuse=%d modules=%d" % [
			i,
			_get_weapon_item_name(weapon),
			int(weapon.fuse),
			weapon.modules.get_child_count()
		])

func _wait_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await get_tree().process_frame
