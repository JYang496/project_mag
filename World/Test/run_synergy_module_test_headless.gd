extends Node

const TEST_WEAPON_SCRIPT := preload("res://World/Test/weapon_numeric_module_test_weapon.gd")
const TEST_ENEMY_SCRIPT := preload("res://World/Test/synergy_module_test_enemy.gd")

var _weapon_a: Ranger
var _weapon_b: Ranger
var _targets: Array[Node] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	_weapon_a = _create_weapon("SynergyWeaponA")
	_weapon_b = _create_weapon("SynergyWeaponB")
	get_tree().root.add_child(_weapon_a)
	get_tree().root.add_child(_weapon_b)
	await get_tree().process_frame
	await _test_firepower_diffusion()
	await _test_rhythm_converter()
	await _test_penetration_momentum()
	await _test_weakness_relay()
	await _test_overkill_recovery()
	await _test_magazine_pressure()
	await _test_inertial_aim()
	await _test_crossfire()
	await _test_kill_endurance()
	await _test_compatibility()
	for target in _targets:
		if target != null and is_instance_valid(target):
			target.queue_free()
	_weapon_a.queue_free()
	_weapon_b.queue_free()
	await get_tree().process_frame
	print("SynergyModuleTest: PASS")
	get_tree().quit(0)

func _test_firepower_diffusion() -> void:
	var module := await _equip("wmod_firepower_diffusion", _weapon_a)
	_weapon_a.on_hit_target(_enemy())
	_weapon_a.on_hit_target(_enemy())
	_assert_gt(_weapon_a.get_total_external_damage_mul(), 1.0, "Firepower Diffusion")
	await _remove(module)

func _test_rhythm_converter() -> void:
	var module := await _equip("wmod_rhythm_converter", _weapon_a)
	module.pause_sec = 0.1
	_weapon_a.on_hit_target(_enemy())
	_weapon_a.on_hit_target(_enemy())
	await get_tree().create_timer(0.15).timeout
	_assert_gt(_weapon_a.get_total_external_damage_mul(), 1.0, "Rhythm Converter")
	await _remove(module)

func _test_penetration_momentum() -> void:
	var module := await _equip("wmod_penetration_momentum", _weapon_a)
	_weapon_a.on_hit_target(_enemy())
	_weapon_a.on_hit_target(_enemy())
	_assert_gt(_weapon_a.get_total_external_damage_mul(), 1.0, "Penetration Momentum")
	await _remove(module)

func _test_weakness_relay() -> void:
	var module := await _equip("wmod_weakness_relay", _weapon_a)
	var target := _enemy()
	target.set_meta(&"_incoming_damage_state", {"frost_stacks": 1})
	_weapon_a.on_hit_target(target)
	_assert_gt(_weapon_a.get_total_external_damage_mul(), 1.0, "Weakness Relay")
	await _remove(module)

func _test_overkill_recovery() -> void:
	var module := await _equip("wmod_overkill_recovery", _weapon_a)
	var target := _enemy()
	target.set("hp", -20)
	_weapon_a.on_hit_target(target)
	_assert_gt(_weapon_a.get_total_external_damage_mul(), 1.0, "Overkill Recovery")
	await _remove(module)

func _test_magazine_pressure() -> void:
	var module := await _equip("wmod_magazine_pressure", _weapon_a)
	_weapon_a.current_ammo = 0
	_assert_gt(_weapon_a.get_runtime_damage_value(100.0), 100, "Magazine Pressure")
	await _remove(module)

func _test_inertial_aim() -> void:
	var module := await _equip("wmod_inertial_aim", _weapon_a)
	_assert_gt(_weapon_a.get_runtime_damage_value(100.0), 100, "Inertial Aim stationary damage")
	await _remove(module)

func _test_crossfire() -> void:
	var module := await _equip("wmod_crossfire", _weapon_a)
	var target := _enemy()
	_weapon_b.on_hit_target(target)
	_weapon_a.on_hit_target(target)
	_assert_gt(_weapon_a.get_total_external_damage_mul(), 1.0, "Crossfire")
	await _remove(module)

func _test_kill_endurance() -> void:
	var module := await _equip("wmod_kill_endurance", _weapon_a)
	module.set_module_level(3)
	module.refund_chance_lv3 = 1.0
	_weapon_a.current_ammo = 1
	var target := _enemy()
	target.set("hp", 0)
	_weapon_a.on_hit_target(target)
	if _weapon_a.current_ammo != 2:
		_fail("Kill Endurance did not refund ammo.")
	await _remove(module)

func _test_compatibility() -> void:
	var plain_weapon := Weapon.new()
	var modules := WeaponModules.new()
	modules.name = "Modules"
	plain_weapon.add_child(modules)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	plain_weapon.add_child(sprite)
	var magazine := _instantiate("wmod_magazine_pressure")
	var endurance := _instantiate("wmod_kill_endurance")
	if magazine.can_apply_to_weapon(plain_weapon) or endurance.can_apply_to_weapon(plain_weapon):
		_fail("Ammo synergy modules accepted a non-ammo weapon.")
	plain_weapon.free()
	magazine.free()
	endurance.free()

func _create_weapon(weapon_name: String) -> Ranger:
	var weapon := TEST_WEAPON_SCRIPT.new() as Ranger
	weapon.name = weapon_name
	weapon.base_damage = 20
	weapon.magazine_capacity = 10
	var modules := WeaponModules.new()
	modules.name = "Modules"
	weapon.add_child(modules)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	weapon.add_child(sprite)
	return weapon

func _enemy() -> Node:
	var target := TEST_ENEMY_SCRIPT.new()
	target.add_to_group("enemies")
	get_tree().root.add_child(target)
	_targets.append(target)
	return target

func _equip(id: String, target_weapon: Weapon) -> Module:
	var module := _instantiate(id)
	target_weapon.modules.add_child(module)
	await get_tree().process_frame
	return module

func _remove(module: Module) -> void:
	module.queue_free()
	await get_tree().process_frame

func _instantiate(id: String) -> Module:
	var scene := load("res://Player/Weapons/Modules/%s.tscn" % id) as PackedScene
	var module := scene.instantiate() as Module if scene else null
	if module == null:
		_fail("Failed to instantiate %s." % id)
	return module

func _assert_gt(actual: float, threshold: float, label: String) -> void:
	if actual <= threshold:
		_fail("%s expected > %.2f, got %.2f." % [label, threshold, actual])

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
	assert(false, message)
