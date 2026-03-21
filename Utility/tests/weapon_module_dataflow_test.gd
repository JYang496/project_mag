extends Node2D

const TEST_WEAPON_SCENE := preload("res://Utility/tests/mocks/test_weapon.tscn")
const TEST_ENEMY_SCRIPT := preload("res://Utility/tests/mocks/test_enemy.gd")
const TEST_PLAYER_SCENE := preload("res://Player/Mechas/scenes/heavy_assault.tscn")

const MODULE_DAMAGE_UP := preload("res://Player/Weapons/Modules/damage_up.tscn")
const MODULE_FASTER_RELOAD := preload("res://Player/Weapons/Modules/faster_reload.tscn")
const MODULE_PIERCE := preload("res://Player/Weapons/Modules/pierce.tscn")
const MODULE_STUN := preload("res://Player/Weapons/Modules/stun_on_hit.tscn")
const MODULE_LIFE_STEAL := preload("res://Player/Weapons/Modules/life_steal.tscn")
const MODULE_LIGHTNING := preload("res://Player/Weapons/Modules/lightning_chain.tscn")

@onready var info_label: Label = $CanvasLayer/InfoLabel

var _player: Player
var _weapon: TestWeapon
var _primary_enemy: TestEnemy
var _secondary_enemy: TestEnemy

var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: PackedStringArray = []
var _last_manual_action: String = "None"

func _ready() -> void:
	await _reset_runtime()
	await run_automatic_tests()
	_render_status()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F5:
			_last_manual_action = "Rerun automatic tests"
			await _reset_runtime()
			await run_automatic_tests()
			_render_status()
		KEY_H:
			_manual_trigger_hit()
			_render_status()
		KEY_1:
			await _manual_equip_module(MODULE_DAMAGE_UP, "Damage Up")
		KEY_2:
			await _manual_equip_module(MODULE_LIFE_STEAL, "Life Steal")
		KEY_3:
			await _manual_equip_module(MODULE_LIGHTNING, "Lightning Chain")
		KEY_R:
			_last_manual_action = "Reset runtime"
			await _reset_runtime()
			_render_status()
		_:
			return

func run_automatic_tests() -> void:
	_pass_count = 0
	_fail_count = 0
	_log_lines.clear()
	await _test_stat_module_pipeline()
	await _test_dataflow_player_weapon_enemy_modules()
	_log_lines.append("[SUMMARY] pass=%d fail=%d" % [_pass_count, _fail_count])
	for line in _log_lines:
		print(line)

func _test_stat_module_pipeline() -> void:
	await _reset_combat_fixture()
	var damage_module := await _obtain_and_equip(MODULE_DAMAGE_UP)
	var reload_module := await _obtain_and_equip(MODULE_FASTER_RELOAD)
	var pierce_module := await _obtain_and_equip(MODULE_PIERCE)
	_assert_true(damage_module != null, "Stat pipeline: Damage Up equipped")
	_assert_true(reload_module != null, "Stat pipeline: Faster Reload equipped")
	_assert_true(pierce_module != null, "Stat pipeline: Pierce equipped")
	if _weapon:
		_weapon.sync_stats()
	_assert_eq_int(_weapon.damage, 15, "Stat pipeline: damage 10 -> 15")
	_assert_near(_weapon.attack_cooldown, 1.4, 0.001, "Stat pipeline: cooldown 2.0 -> 1.4")
	_assert_eq_int(_weapon.projectile_hits, 3, "Stat pipeline: projectile hits 1 -> 3")

func _test_dataflow_player_weapon_enemy_modules() -> void:
	await _reset_combat_fixture()
	var stun_module := await _obtain_and_equip(MODULE_STUN)
	var life_steal_module := await _obtain_and_equip(MODULE_LIFE_STEAL)
	var lightning_module := await _obtain_and_equip(MODULE_LIGHTNING)
	if stun_module and stun_module.has_method("set"):
		stun_module.set("base_chance", 1.0)
	_assert_true(stun_module != null, "Dataflow: Stun module equipped")
	_assert_true(life_steal_module != null, "Dataflow: Life Steal module equipped")
	_assert_true(lightning_module != null, "Dataflow: Lightning module equipped")

	PlayerData.player_max_hp = 10
	PlayerData.player_hp = 1
	_spawn_enemies()
	await get_tree().process_frame

	_weapon.on_hit_target(_primary_enemy)
	await get_tree().process_frame

	_assert_true(PlayerData.player_hp > 1, "Dataflow: Life Steal increased player HP after hit")
	_assert_true(_has_status_payload(_primary_enemy, "stun"), "Dataflow: Stun payload applied to primary enemy")
	_assert_true(_secondary_enemy.received_attacks.size() > 0, "Dataflow: Lightning damaged chained enemy")

func _manual_trigger_hit() -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		_last_manual_action = "Hit test failed: no active weapon"
		return
	if _primary_enemy == null or not is_instance_valid(_primary_enemy) or _secondary_enemy == null or not is_instance_valid(_secondary_enemy):
		_spawn_enemies()
	PlayerData.player_max_hp = 10
	PlayerData.player_hp = max(1, PlayerData.player_hp)
	_weapon.on_hit_target(_primary_enemy)
	_last_manual_action = "Triggered manual on-hit flow"

func _manual_equip_module(module_scene: PackedScene, module_name: String) -> void:
	var module_instance := module_scene.instantiate() as Module
	if module_instance == null:
		_last_manual_action = "Failed to instantiate %s" % module_name
		_render_status()
		return
	InventoryData.obtain_module(module_instance)
	var result := InventoryData.equip_module_to_weapon(module_instance, _weapon)
	if not result.get("ok", false):
		_last_manual_action = "Equip failed for %s: %s" % [module_name, str(result.get("reason", ""))]
	else:
		_last_manual_action = "Equipped %s" % module_name
	_render_status()
	await get_tree().process_frame

func _obtain_and_equip(module_scene: PackedScene) -> Module:
	var module_instance := module_scene.instantiate() as Module
	if module_instance == null:
		return null
	InventoryData.obtain_module(module_instance)
	var result := InventoryData.equip_module_to_weapon(module_instance, _weapon)
	if not result.get("ok", false):
		return null
	await get_tree().process_frame
	return module_instance

func _reset_runtime() -> void:
	_clear_spawned_children()
	if GlobalVariables.has_method("reset_runtime_state"):
		GlobalVariables.reset_runtime_state()
	if InventoryData.has_method("reset_runtime_state"):
		InventoryData.reset_runtime_state()
	if PlayerData.has_method("reset_runtime_state"):
		PlayerData.reset_runtime_state()
	_last_manual_action = "Runtime initialized"
	await _reset_combat_fixture()

func _reset_combat_fixture() -> void:
	_remove_node_if_valid(_primary_enemy)
	_remove_node_if_valid(_secondary_enemy)
	_primary_enemy = null
	_secondary_enemy = null
	_remove_node_if_valid(_weapon)
	_weapon = null
	_remove_node_if_valid(_player)
	_player = null
	await get_tree().process_frame

	_player = TEST_PLAYER_SCENE.instantiate() as Player
	if _player == null:
		return
	_player.name = "TestPlayer"
	_player.add_to_group("player")
	add_child(_player)
	await get_tree().process_frame
	PlayerData.player = _player

	for existing_weapon in PlayerData.player_weapon_list:
		if existing_weapon and is_instance_valid(existing_weapon):
			existing_weapon.queue_free()
	PlayerData.player_weapon_list.clear()
	PlayerData.on_select_weapon = -1

	_weapon = TEST_WEAPON_SCENE.instantiate() as TestWeapon
	_weapon.name = "TestWeaponDataflow"
	_weapon.MAX_MODULE_NUMBER = 6
	if _player.equppied_weapons:
		_player.equppied_weapons.add_child(_weapon)
	_weapon.position = Vector2.ZERO
	PlayerData.player_weapon_list.append(_weapon)
	await get_tree().process_frame
	var modules_container: WeaponModules = _weapon.get_node_or_null("Modules") as WeaponModules
	if modules_container:
		modules_container.weapon_traits = (1 << CombatTrait.FLAG_ORDER.size()) - 1
	_weapon.sync_stats()
	await get_tree().process_frame

func _spawn_enemies() -> void:
	_remove_node_if_valid(_primary_enemy)
	_remove_node_if_valid(_secondary_enemy)
	_primary_enemy = TEST_ENEMY_SCRIPT.new() as TestEnemy
	_primary_enemy.name = "PrimaryEnemy"
	_primary_enemy.global_position = Vector2.ZERO
	_primary_enemy.add_to_group("enemies")
	add_child(_primary_enemy)

	_secondary_enemy = TEST_ENEMY_SCRIPT.new() as TestEnemy
	_secondary_enemy.name = "SecondaryEnemy"
	_secondary_enemy.global_position = Vector2(40, 0)
	_secondary_enemy.add_to_group("enemies")
	add_child(_secondary_enemy)

func _clear_spawned_children() -> void:
	for child in get_children():
		if child is CanvasLayer:
			continue
		child.queue_free()

func _remove_node_if_valid(node_ref: Node) -> void:
	if node_ref and is_instance_valid(node_ref):
		node_ref.queue_free()

func _has_status_payload(enemy: TestEnemy, status_id: String) -> bool:
	if enemy == null:
		return false
	for payload_entry in enemy.status_payloads:
		if str(payload_entry.get("id", "")) == status_id:
			return true
	return false

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		_log_lines.append("[PASS] %s" % message)
	else:
		_fail_count += 1
		_log_lines.append("[FAIL] %s" % message)

func _assert_eq_int(actual: int, expected: int, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%d actual=%d)" % [message, expected, actual])

func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s (expected=%.3f actual=%.3f)" % [message, expected, actual])

func _render_status() -> void:
	var lines: PackedStringArray = []
	lines.append("Weapon Module Dataflow Test")
	lines.append("Auto tests run on start.")
	lines.append("Keys: [F5] Rerun Auto  [H] Trigger Hit  [1] Equip DamageUp  [2] Equip LifeSteal  [3] Equip Lightning  [R] Reset")
	lines.append("Last action: %s" % _last_manual_action)
	lines.append("Results: pass=%d fail=%d" % [_pass_count, _fail_count])
	lines.append("Player HP: %d/%d" % [int(PlayerData.player_hp), int(PlayerData.player_max_hp)])
	if _weapon and is_instance_valid(_weapon):
		lines.append("Weapon Stats: dmg=%d cd=%.2f hits=%d modules=%d/%d" % [
			int(_weapon.damage),
			float(_weapon.attack_cooldown),
			int(_weapon.projectile_hits),
			_weapon.get_module_count(),
			int(_weapon.MAX_MODULE_NUMBER)
		])
		var module_lines: PackedStringArray = []
		for module_instance in _weapon.get_equipped_modules():
			module_lines.append("%s Lv.%d" % [
				module_instance.get_module_display_name(),
				int(module_instance.module_level)
			])
		lines.append("Equipped Modules: %s" % (", ".join(module_lines) if not module_lines.is_empty() else "none"))
	else:
		lines.append("Weapon Stats: (none)")
	lines.append("Primary Enemy Payloads: %d  Secondary Enemy Hits: %d" % [
		_primary_enemy.status_payloads.size() if _primary_enemy else 0,
		_secondary_enemy.received_attacks.size() if _secondary_enemy else 0
	])
	if not _log_lines.is_empty():
		lines.append("Last Log: %s" % _log_lines[_log_lines.size() - 1])
	info_label.text = "\n".join(lines)
