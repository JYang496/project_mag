extends Node

const TEST_WEAPON_SCRIPT := preload("res://World/Test/weapon_numeric_module_test_weapon.gd")
const SHOTGUN_SCENE := preload("res://Player/Weapons/Instances/shotgun.tscn")
const MODULE_CASES: Array[Dictionary] = [
	{"path": "res://Player/Weapons/Modules/wmod_quick_cycle.tscn", "stat": "attack_cooldown", "base": 2.0, "lv1": 1.76, "lv3": 1.52},
	{"path": "res://Player/Weapons/Modules/wmod_heat_throttle.tscn", "stat": "heat_per_shot", "base": 10.0, "lv1": 8.5, "lv3": 7.1},
	{"path": "res://Player/Weapons/Modules/wmod_expanded_magazine.tscn", "stat": "magazine_capacity", "base": 10.0, "lv1": 12.0, "lv3": 14.0},
	{"path": "res://Player/Weapons/Modules/wmod_fast_reload.tscn", "stat": "reload_duration_sec", "base": 5.0, "lv1": 4.25, "lv3": 3.55},
	{"path": "res://Player/Weapons/Modules/wmod_area_expander.tscn", "stat": "area_radius", "base": 100.0, "lv1": 115.0, "lv3": 129.0},
	{"path": "res://Player/Weapons/Modules/wmod_impact_coil.tscn", "stat": "knockback", "base": 100.0, "lv1": 125.0, "lv3": 145.0},
	{"path": "res://Player/Weapons/Modules/wmod_multi_launcher.tscn", "stat": "projectile_count", "base": 1.0, "lv1": 2.0, "lv3": 3.0},
	{"path": "res://Player/Weapons/Modules/wmod_diffusion_nozzle.tscn", "stat": "cone_half_angle_deg", "base": 40.0, "lv1": 46.0, "lv3": 51.6},
]

var _weapon: Ranger

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	_weapon = _create_test_weapon()
	get_tree().root.add_child(_weapon)
	await get_tree().process_frame

	for case_data in MODULE_CASES:
		await _test_module_case(case_data)
	await _test_area_effect_runtime()
	_test_knockback_runtime()
	_test_projectile_directions()
	_test_branch_centered_shot_directions()
	_test_shotgun_centered_spread()

	_weapon.queue_free()
	InventoryData.reset_runtime_state()
	PlayerData.reset_runtime_state()
	print("WeaponNumericModuleTest: PASS")
	get_tree().quit(0)

func _test_module_case(case_data: Dictionary) -> void:
	var module := _instantiate_module(str(case_data.path))
	InventoryData.add_child(module)
	module.reparent(_weapon.modules)
	await get_tree().process_frame
	var stat_name := str(case_data.stat)
	var base_value := float(case_data.base)
	_assert_approx(
		_weapon.get_runtime_stat_value(stat_name, base_value),
		float(case_data.lv1),
		"%s level 1" % module.get_module_display_name()
	)
	module.set_module_level(3)
	_assert_approx(
		_weapon.get_runtime_stat_value(stat_name, base_value),
		float(case_data.lv3),
		"%s level 3" % module.get_module_display_name()
	)
	if stat_name == "magazine_capacity" and _weapon.get_effective_magazine_capacity() != int(case_data.lv3):
		_fail("Expanded Magazine was not reflected by the ammo controller.")
	if stat_name == "reload_duration_sec":
		_assert_approx(
			_weapon.ammo_controller.get_effective_reload_duration(),
			float(case_data.lv3),
			"Fast Reload ammo controller duration"
		)
	module.reparent(InventoryData)
	await get_tree().process_frame
	_assert_approx(
		_weapon.get_runtime_stat_value(stat_name, base_value),
		base_value,
		"%s unequipped" % module.get_module_display_name()
	)
	module.queue_free()

func _test_area_effect_runtime() -> void:
	var module := _instantiate_module("res://Player/Weapons/Modules/wmod_area_expander.tscn")
	module.set_module_level(3)
	_weapon.modules.add_child(module)
	var scene := load("res://Utility/area_effect/area_effect.tscn") as PackedScene
	var area := scene.instantiate() as AreaEffect
	area.radius = 100.0
	area.source_node = _weapon
	area.source_category = DamageData.SOURCE_PLAYER_WEAPON
	get_tree().root.add_child(area)
	await get_tree().process_frame
	_assert_approx(area.radius, 129.0, "Area effect runtime radius")
	area.queue_free()
	module.queue_free()
	await get_tree().process_frame

func _test_knockback_runtime() -> void:
	var module := _instantiate_module("res://Player/Weapons/Modules/wmod_impact_coil.tscn")
	module.set_module_level(3)
	_weapon.modules.add_child(module)
	var data := DamageManager.build_damage_data(
		_weapon,
		1,
		Attack.TYPE_PHYSICAL,
		{"amount": 100.0, "angle": Vector2.RIGHT},
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.PROJECTILE
	)
	_assert_approx(float(data.knock_back.amount), 145.0, "Impact coil runtime knockback")
	module.queue_free()

func _test_projectile_directions() -> void:
	var module := _instantiate_module("res://Player/Weapons/Modules/wmod_multi_launcher.tscn")
	_weapon.modules.add_child(module)
	var even_directions := _weapon.branch_runtime.get_branch_shot_directions(Vector2.RIGHT)
	if even_directions.size() != 2:
		_fail("Multi Launcher expected 2 level-1 directions, got %d." % even_directions.size())
	_assert_first_direction(even_directions, Vector2.RIGHT, "Multi Launcher level-1 centered direction")
	module.set_module_level(3)
	var directions := _weapon.branch_runtime.get_branch_shot_directions(Vector2.RIGHT)
	if directions.size() != 3:
		_fail("Multi Launcher expected 3 directions, got %d." % directions.size())
	_assert_first_direction(directions, Vector2.RIGHT, "Multi Launcher level-3 centered direction")
	var shotgun_directions := _weapon.branch_runtime.get_branch_shot_directions(Vector2.RIGHT, 5)
	if shotgun_directions.size() != 7:
		_fail("Multi Launcher expected 7 directions from a base count of 5, got %d." % shotgun_directions.size())
	_assert_first_direction(shotgun_directions, Vector2.RIGHT, "Multi Launcher shotgun centered direction")
	module.queue_free()

func _test_branch_centered_shot_directions() -> void:
	var gatling := MachineGunGatlingBranch.new()
	_assert_first_direction(gatling.get_shot_directions(Vector2.RIGHT, 2), Vector2.RIGHT, "Gatling even centered direction")
	gatling.queue_free()
	var salvo := RocketSalvoBranch.new()
	_assert_first_direction(salvo.get_shot_directions(Vector2.RIGHT, 2), Vector2.RIGHT, "Rocket salvo even centered direction")
	salvo.queue_free()
	var spear := SpearMultiPierceBranch.new()
	_assert_first_direction(spear.get_shot_directions(Vector2.RIGHT, 4), Vector2.RIGHT, "Spear multi-pierce even centered direction")
	spear.queue_free()

func _test_shotgun_centered_spread() -> void:
	var shotgun := SHOTGUN_SCENE.instantiate()
	var directions_variant: Variant = shotgun.call("_build_spread_directions", Vector2.RIGHT, 4, 30.0)
	var directions := directions_variant as Array
	if directions.size() != 4:
		shotgun.queue_free()
		_fail("Shotgun expected 4 spread directions, got %d." % directions.size())
	_assert_first_direction(directions, Vector2.RIGHT, "Shotgun even centered spread")
	shotgun.queue_free()

func _create_test_weapon() -> Ranger:
	var weapon := TEST_WEAPON_SCRIPT.new() as Ranger
	weapon.name = "WeaponNumericModuleTestWeapon"
	weapon.delivery_type_flags = 1 | 8
	weapon.magazine_capacity = 10
	weapon.reload_duration_sec = 5.0
	weapon.heat_per_shot = 10.0
	weapon.base_damage = 10
	weapon.base_speed = 100
	weapon.base_projectile_hits = 1
	weapon.base_attack_cooldown = 2.0
	var modules := WeaponModules.new()
	modules.name = "Modules"
	modules.weapon_traits = 16
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

func _assert_approx(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s expected %.3f, got %.3f." % [label, expected, actual])

func _assert_first_direction(directions: Array, expected: Vector2, label: String) -> void:
	if directions.is_empty():
		_fail("%s returned no directions." % label)
	var actual := (directions[0] as Vector2).normalized()
	var target := expected.normalized()
	if not actual.is_equal_approx(target):
		_fail("%s expected first direction %s, got %s." % [label, target, actual])

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
	assert(false, message)
