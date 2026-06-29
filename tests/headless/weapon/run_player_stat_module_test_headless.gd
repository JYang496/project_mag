extends Node

const MODULE_PATHS: PackedStringArray = [
	"res://Player/Weapons/Modules/wmod_crit_calibrator.tscn",
	"res://Player/Weapons/Modules/wmod_crit_amplifier.tscn",
	"res://Player/Weapons/Modules/wmod_dash_cooler.tscn",
	"res://Player/Weapons/Modules/wmod_recovery_magnet.tscn",
]

var _weapon: Weapon
var _offhand_weapon: Weapon

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	_weapon = _create_test_weapon()
	_offhand_weapon = _create_test_weapon()
	_offhand_weapon.name = "PlayerStatModuleTestOffhand"
	get_tree().root.add_child(_weapon)
	get_tree().root.add_child(_offhand_weapon)
	PlayerData.player_weapon_list.append(_weapon)
	PlayerData.player_weapon_list.append(_offhand_weapon)
	PlayerData.set_main_weapon_index(0)
	await get_tree().process_frame

	await _test_main_weapon_requirement()
	await _test_crit_calibrator()
	await _test_crit_amplifier()
	await _test_crit_damage_runtime()
	await _test_dash_cooler()
	await _test_recovery_magnet()

	_weapon.queue_free()
	_offhand_weapon.queue_free()
	InventoryData.reset_runtime_state()
	PlayerData.reset_runtime_state()
	print("PlayerStatModuleTest: PASS")
	get_tree().quit(0)

func _test_main_weapon_requirement() -> void:
	var module := _instantiate_module(MODULE_PATHS[0])
	InventoryData.add_child(module)
	module.reparent(_offhand_weapon.modules)
	await get_tree().process_frame
	_assert_approx(PlayerData.total_crit_rate, 0.0, "Offhand player stat module was applied.")
	PlayerData.set_main_weapon_index(1)
	await get_tree().process_frame
	_assert_approx(PlayerData.total_crit_rate, 0.04, "Player stat module was not applied after becoming main weapon.")
	PlayerData.set_main_weapon_index(0)
	await get_tree().process_frame
	_assert_approx(PlayerData.total_crit_rate, 0.0, "Player stat module remained active after becoming offhand.")
	module.queue_free()

func _test_crit_calibrator() -> void:
	var module := _instantiate_module(MODULE_PATHS[0])
	InventoryData.add_child(module)
	await get_tree().process_frame
	_assert_approx(PlayerData.total_crit_rate, 0.0, "Crit calibrator affected player while temporary.")
	module.reparent(_weapon.modules)
	await get_tree().process_frame
	_assert_approx(PlayerData.total_crit_rate, 0.04, "Crit calibrator level 1 was not applied.")
	module.set_module_level(3)
	_assert_approx(PlayerData.total_crit_rate, 0.08, "Crit calibrator upgrade was not applied.")
	module.reparent(InventoryData)
	await get_tree().process_frame
	_assert_approx(PlayerData.total_crit_rate, 0.0, "Crit calibrator was not removed.")
	module.queue_free()

func _test_crit_amplifier() -> void:
	var module := _instantiate_module(MODULE_PATHS[1])
	InventoryData.add_child(module)
	await get_tree().process_frame
	module.reparent(_weapon.modules)
	await get_tree().process_frame
	_assert_approx(PlayerData.total_crit_damage, 1.15, "Crit amplifier level 1 was not applied.")
	module.set_module_level(3)
	_assert_approx(PlayerData.total_crit_damage, 1.35, "Crit amplifier upgrade was not applied.")
	module.reparent(InventoryData)
	await get_tree().process_frame
	_assert_approx(PlayerData.total_crit_damage, 1.0, "Crit amplifier was not removed.")
	module.queue_free()

func _test_crit_damage_runtime() -> void:
	PlayerData.crit_rate = 0.92
	var calibrator := _instantiate_module(MODULE_PATHS[0])
	calibrator.set_module_level(3)
	InventoryData.add_child(calibrator)
	calibrator.reparent(_weapon.modules)
	var amplifier := _instantiate_module(MODULE_PATHS[1])
	amplifier.set_module_level(3)
	InventoryData.add_child(amplifier)
	amplifier.reparent(_weapon.modules)
	await get_tree().process_frame
	var status_system := PlayerStatusModifierSystem.new()
	var critical_damage := status_system.compute_outgoing_damage(100)
	if critical_damage != 135:
		_fail("Crit modules did not affect outgoing damage. Expected 135, got %d." % critical_damage)
	calibrator.reparent(InventoryData)
	amplifier.reparent(InventoryData)
	await get_tree().process_frame
	calibrator.queue_free()
	amplifier.queue_free()
	PlayerData.crit_rate = 0.0

func _test_dash_cooler() -> void:
	var module := _instantiate_module(MODULE_PATHS[2])
	InventoryData.add_child(module)
	await get_tree().process_frame
	module.reparent(_weapon.modules)
	await get_tree().process_frame
	_assert_approx(PlayerData.dash_cooldown, 4.25, "Dash cooler level 1 was not applied.")
	module.set_module_level(3)
	_assert_approx(PlayerData.dash_cooldown, 3.55, "Dash cooler upgrade was not applied.")
	module.reparent(InventoryData)
	await get_tree().process_frame
	_assert_approx(PlayerData.dash_cooldown, 5.0, "Dash cooler was not removed.")
	module.queue_free()

func _test_recovery_magnet() -> void:
	var module := _instantiate_module(MODULE_PATHS[3])
	InventoryData.add_child(module)
	await get_tree().process_frame
	module.reparent(_weapon.modules)
	await get_tree().process_frame
	_assert_approx(PlayerData.total_grab_radius, 62.5, "Recovery magnet level 1 was not applied.")
	module.set_module_level(3)
	_assert_approx(PlayerData.total_grab_radius, 77.5, "Recovery magnet upgrade was not applied.")
	module.reparent(InventoryData)
	await get_tree().process_frame
	_assert_approx(PlayerData.total_grab_radius, 50.0, "Recovery magnet was not removed.")
	module.queue_free()

func _create_test_weapon() -> Weapon:
	var weapon := Weapon.new()
	weapon.name = "PlayerStatModuleTestWeapon"
	var modules := WeaponModules.new()
	modules.name = "Modules"
	weapon.add_child(modules)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	weapon.add_child(sprite)
	return weapon

func _instantiate_module(path: String) -> Module:
	var scene := load(path) as PackedScene
	var module := scene.instantiate() as Module if scene else null
	if module == null:
		_fail("Failed to instantiate module: %s" % path)
	return module

func _assert_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s Expected %.3f, got %.3f." % [message, expected, actual])

func _fail(message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	PlayerData.reset_runtime_state()
	get_tree().quit(1)
	assert(false, message)
