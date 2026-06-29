extends Node

const TEST_WEAPON_SCRIPT := preload("res://tests/fixtures/weapons/weapon_numeric_module_test_weapon.gd")
const MODULE_PATHS: PackedStringArray = [
	"res://Player/Weapons/Modules/wmod_battle_focus_buff.tscn",
	"res://Player/Weapons/Modules/wmod_bleed_edge_physical.tscn",
	"res://Player/Weapons/Modules/wmod_brittle_trigger_freeze.tscn",
	"res://Player/Weapons/Modules/wmod_chill_chain_freeze.tscn",
	"res://Player/Weapons/Modules/wmod_corrosive_touch_energy.tscn",
	"res://Player/Weapons/Modules/wmod_cryo_infuser_freeze.tscn",
	"res://Player/Weapons/Modules/wmod_dot_on_hit.tscn",
	"res://Player/Weapons/Modules/wmod_ember_mark_fire.tscn",
	"res://Player/Weapons/Modules/wmod_ice_prison_freeze.tscn",
	"res://Player/Weapons/Modules/wmod_lifesteal_on_hit.tscn",
	"res://Player/Weapons/Modules/wmod_lightning_chain_on_hit.tscn",
	"res://Player/Weapons/Modules/wmod_molten_splash_fire.tscn",
	"res://Player/Weapons/Modules/wmod_momentum_haste.tscn",
	"res://Player/Weapons/Modules/wmod_permafrost_field_freeze.tscn",
	"res://Player/Weapons/Modules/wmod_plague_seed_dot.tscn",
	"res://Player/Weapons/Modules/wmod_shatter_strike_freeze.tscn",
	"res://Player/Weapons/Modules/wmod_stun_on_hit.tscn",
	"res://Player/Weapons/Modules/wmod_subzero_extension_freeze.tscn",
	"res://Player/Weapons/Modules/wmod_vampiric_surge.tscn",
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

	for path in MODULE_PATHS:
		await _test_module_lifecycle(path)

	_weapon.queue_free()
	await get_tree().process_frame
	InventoryData.reset_runtime_state()
	PlayerData.reset_runtime_state()
	print("OnHitModuleLifecycleTest: PASS")
	get_tree().quit(0)

func _test_module_lifecycle(path: String) -> void:
	var module := _instantiate_module(path)
	if not (module is OnHitModule):
		_fail("%s does not inherit OnHitModule." % path)
	_weapon.modules.add_child(module)
	await get_tree().process_frame
	if _weapon.plugin_dispatcher.on_hit_plugins.size() != 1:
		_fail("%s registered more or less than once." % path)
	if _weapon.plugin_dispatcher.on_hit_plugins[0] != module:
		_fail("%s registered an unexpected plugin." % path)

	_weapon.plugin_dispatcher.apply_on_hit_plugins(null)
	module.queue_free()
	await get_tree().process_frame
	if not _weapon.plugin_dispatcher.on_hit_plugins.is_empty():
		_fail("%s remained registered after exiting the tree." % path)

func _create_test_weapon() -> Ranger:
	var weapon := TEST_WEAPON_SCRIPT.new() as Ranger
	weapon.name = "OnHitModuleLifecycleTestWeapon"
	weapon.delivery_type_flags = 1 | 2 | 4 | 8
	var modules := WeaponModules.new()
	modules.name = "Modules"
	modules.weapon_traits = 1 | 2 | 4 | 8 | 16 | 32
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

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
	assert(false, message)
