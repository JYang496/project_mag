extends Node2D

const WEAPON_MODULES_SCRIPT := preload("res://Player/Weapons/Core/weapon_modules.gd")
const TRAIL_MODULE_SCRIPT := preload("res://Player/Weapons/Modules/wmod_trail_aoe_freeze.gd")
const BLAST_DAMAGE_SCRIPT := preload("res://Player/Weapons/Modules/wmod_reload_blast_damage.gd")
const BLAST_KNOCKBACK_SCRIPT := preload("res://Player/Weapons/Modules/wmod_reload_blast_knockback.gd")
const DAMAGE_BOOST_SCRIPT := preload("res://Player/Weapons/Modules/wmod_reload_damage_boost.gd")
const MOVE_BOOST_SCRIPT := preload("res://Player/Weapons/Modules/wmod_reload_move_boost.gd")
const SHIELD_BOOST_SCRIPT := preload("res://Player/Weapons/Modules/wmod_reload_shield_boost.gd")
const OFFHAND_BOOST_SCRIPT := preload("res://Player/Weapons/Modules/wmod_reload_offhand_boost.gd")
const SPEED_LINK_SCRIPT := preload("res://Player/Weapons/Modules/wmod_reload_speed_link.gd")

class MockPlayer:
	extends Node2D
	var _move_speed_mul_modifiers: Dictionary = {}

	func apply_move_speed_mul(source_id: StringName, mul: float) -> void:
		_move_speed_mul_modifiers[source_id] = clampf(mul, 0.05, 10.0)

	func remove_move_speed_mul(source_id: StringName) -> void:
		if _move_speed_mul_modifiers.has(source_id):
			_move_speed_mul_modifiers.erase(source_id)

	func get_total_move_speed_mul() -> float:
		var total := 1.0
		for mul in _move_speed_mul_modifiers.values():
			total *= float(mul)
		return total

class MockEnemy:
	extends Node2D
	var hp: int = 100
	var last_knockback_amount: float = 0.0
	var last_knockback_angle: Vector2 = Vector2.ZERO

	func _ready() -> void:
		add_to_group("enemies")

	func damaged(attack: Attack) -> void:
		if attack == null:
			return
		hp -= max(0, int(attack.damage))
		last_knockback_amount = float(attack.knock_back.amount)
		last_knockback_angle = attack.knock_back.angle

class MockWeapon:
	extends Weapon
	var damage: int = 10

	func supports_projectiles() -> bool:
		return true

	func uses_ammo_system() -> bool:
		return true

@onready var result_label: Label = $ResultLabel

var _logs: PackedStringArray = []
var _failure_count: int = 0

func _ready() -> void:
	PlayerData.reset_runtime_state()
	await _run_tests()
	result_label.text = "\n".join(_logs)

func _run_tests() -> void:
	await _test_trail_module_spawns_freeze_field()
	await _test_reload_blast_damage()
	await _test_reload_blast_knockback()
	await _test_reload_damage_boost()
	await _test_reload_move_boost()
	await _test_reload_shield_boost()
	await _test_reload_offhand_boost()
	await _test_reload_speed_link()
	var status := "PASS" if _failure_count == 0 else "FAIL (%d)" % _failure_count
	_log("==== Reload Module Suite: %s ====" % status)

func _test_trail_module_spawns_freeze_field() -> void:
	var rig := _create_rig()
	var enemy := _spawn_enemy(Vector2(40, 0))
	var module_instance: Module = TRAIL_MODULE_SCRIPT.new() as Module
	rig.main.modules.add_child(module_instance)
	await get_tree().process_frame
	var projectile := Node2D.new()
	projectile.global_position = Vector2.ZERO
	add_child(projectile)
	rig.main.notify_projectile_spawned(projectile)
	projectile.global_position = Vector2(80, 0)
	module_instance._physics_process(0.2)
	module_instance._physics_process(0.4)
	_expect(enemy.hp < 100, "trail module should damage enemies along projectile path")
	rig.root.queue_free()
	enemy.queue_free()

func _test_reload_blast_damage() -> void:
	var rig := _create_rig()
	var enemy := _spawn_enemy(Vector2(20, 0))
	var module_instance: Module = BLAST_DAMAGE_SCRIPT.new() as Module
	rig.main.modules.add_child(module_instance)
	await get_tree().process_frame
	await get_tree().process_frame
	rig.main.current_ammo = 4
	rig.main.request_reload()
	_expect(enemy.hp < 100, "reload blast damage should damage nearby enemies")
	rig.root.queue_free()
	enemy.queue_free()

func _test_reload_blast_knockback() -> void:
	var rig := _create_rig()
	var enemy := _spawn_enemy(Vector2(20, 0))
	var module_instance: Module = BLAST_KNOCKBACK_SCRIPT.new() as Module
	rig.main.modules.add_child(module_instance)
	await get_tree().process_frame
	await get_tree().process_frame
	rig.main.current_ammo = 2
	rig.main.request_reload()
	_expect(enemy.last_knockback_amount > 0.0, "reload knockback should push nearby enemies")
	rig.root.queue_free()
	enemy.queue_free()

func _test_reload_damage_boost() -> void:
	var rig := _create_rig()
	var module_instance := DAMAGE_BOOST_SCRIPT.new() as Module
	rig.main.modules.add_child(module_instance)
	await get_tree().process_frame
	var base_damage: int = rig.main.get_runtime_damage_value(10.0)
	rig.main.current_ammo = 0
	rig.main.request_reload()
	var boosted_damage: int = rig.main.get_runtime_damage_value(10.0)
	_expect(boosted_damage > base_damage, "reload damage boost should increase current weapon damage")
	await get_tree().create_timer(3.2).timeout
	var recovered_damage: int = rig.main.get_runtime_damage_value(10.0)
	_expect(recovered_damage == base_damage, "reload damage boost should expire")
	rig.root.queue_free()

func _test_reload_move_boost() -> void:
	var rig := _create_rig()
	var module_instance := MOVE_BOOST_SCRIPT.new() as Module
	rig.main.modules.add_child(module_instance)
	await get_tree().process_frame
	rig.main.current_ammo = 0
	rig.main.request_reload()
	_expect(rig.player.get_total_move_speed_mul() > 1.0, "reload move boost should affect player move speed")
	await get_tree().create_timer(3.2).timeout
	_expect(is_equal_approx(rig.player.get_total_move_speed_mul(), 1.0), "reload move boost should expire")
	rig.root.queue_free()

func _test_reload_shield_boost() -> void:
	var rig := _create_rig()
	var module_instance := SHIELD_BOOST_SCRIPT.new() as Module
	rig.main.modules.add_child(module_instance)
	await get_tree().process_frame
	rig.main.current_ammo = 0
	rig.main.request_reload()
	_expect(PlayerData.bonus_shield > 0, "reload shield boost should add temporary shield")
	await get_tree().create_timer(3.2).timeout
	_expect(PlayerData.bonus_shield == 0, "reload shield boost should expire")
	rig.root.queue_free()

func _test_reload_offhand_boost() -> void:
	var rig := _create_rig(true)
	var module_instance := OFFHAND_BOOST_SCRIPT.new() as Module
	rig.main.modules.add_child(module_instance)
	await get_tree().process_frame
	var base_damage: int = rig.offhand.get_runtime_damage_value(10.0)
	rig.main.current_ammo = 0
	rig.main.request_reload()
	var boosted_damage: int = rig.offhand.get_runtime_damage_value(10.0)
	_expect(boosted_damage > base_damage, "reload offhand boost should increase other weapon damage")
	await get_tree().create_timer(3.2).timeout
	var recovered_damage: int = rig.offhand.get_runtime_damage_value(10.0)
	_expect(recovered_damage == base_damage, "reload offhand boost should expire")
	rig.root.queue_free()

func _test_reload_speed_link() -> void:
	var rig := _create_rig(true)
	var module_instance := SPEED_LINK_SCRIPT.new() as Module
	rig.main.modules.add_child(module_instance)
	await get_tree().process_frame
	rig.offhand.current_ammo = 0
	rig.offhand.request_reload()
	rig.main.current_ammo = 0
	rig.main.request_reload()
	_expect(rig.main.reload_time_left < rig.main.reload_duration_sec, "reload speed link should shorten reload while another weapon reloads")
	rig.root.queue_free()

func _create_rig(with_offhand: bool = false) -> Dictionary:
	PlayerData.reset_runtime_state()
	PlayerData.player_max_hp = 10
	var root := Node2D.new()
	add_child(root)
	var player := MockPlayer.new()
	root.add_child(player)
	var main_weapon := _new_weapon("MainWeapon", 10)
	player.add_child(main_weapon)
	PlayerData.player_weapon_list.append(main_weapon)
	var offhand_weapon: MockWeapon = null
	if with_offhand:
		offhand_weapon = _new_weapon("OffhandWeapon", 10)
		player.add_child(offhand_weapon)
		PlayerData.player_weapon_list.append(offhand_weapon)
	PlayerData.set_main_weapon_index(0)
	main_weapon.set_weapon_role("main")
	if offhand_weapon != null:
		offhand_weapon.set_weapon_role("offhand")
	return {
		"root": root,
		"player": player,
		"main": main_weapon,
		"offhand": offhand_weapon,
	}

func _new_weapon(weapon_name: String, base_damage: int) -> MockWeapon:
	var weapon := MockWeapon.new()
	weapon.name = weapon_name
	weapon.damage = base_damage
	weapon.magazine_capacity = 10
	weapon.reload_duration_sec = 2.0
	var modules_node := WEAPON_MODULES_SCRIPT.new() as WeaponModules
	modules_node.name = "Modules"
	weapon.add_child(modules_node)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	weapon.add_child(sprite)
	return weapon

func _spawn_enemy(position_value: Vector2) -> MockEnemy:
	var enemy := MockEnemy.new()
	add_child(enemy)
	enemy.global_position = position_value
	return enemy

func _expect(condition: bool, message: String) -> void:
	if condition:
		_log("[PASS] %s" % message)
		return
	_failure_count += 1
	_log("[FAIL] %s" % message)

func _log(message: String) -> void:
	print(message)
	_logs.append(message)
