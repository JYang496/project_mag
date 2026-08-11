extends Control

const PANEL_SCENE := preload("res://UI/scenes/module_equip_selection_panel.tscn")
const MACHINE_GUN_SCENE := preload("res://Player/Weapons/Instances/machine_gun.tscn")
const CHARGED_BLASTER_SCENE := preload("res://Player/Weapons/Instances/charged_blaster.tscn")
const LASER_SCENE := preload("res://Player/Weapons/Instances/laser.tscn")
const DASH_BLADE_SCENE := preload("res://Player/Weapons/Instances/dash_blade.tscn")
const MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_corrosive_touch_energy.tscn")
const INSTALLED_MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")

var _fixtures: Array[Node] = []

func _ready() -> void:
	LocalizationManager.set_locale("zh_CN")
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.008, 0.018, 0.028, 1.0)
	add_child(background)
	var showcase_weapons: Array[Weapon] = []
	for scene in [MACHINE_GUN_SCENE, CHARGED_BLASTER_SCENE, LASER_SCENE, DASH_BLADE_SCENE]:
		var weapon := scene.instantiate() as Weapon
		_fixtures.append(weapon)
		add_child(weapon)
		weapon.visible = false
		PlayerData.player_weapon_list.append(weapon)
		showcase_weapons.append(weapon)
	var installed_module := INSTALLED_MODULE_SCENE.instantiate() as Module
	_fixtures.append(installed_module)
	showcase_weapons[1].modules.add_child(installed_module)
	var module_instance := MODULE_SCENE.instantiate() as Module
	_fixtures.append(module_instance)
	add_child(module_instance)
	module_instance.visible = false
	InventoryData.temporary_modules.append(module_instance)
	var panel := PANEL_SCENE.instantiate() as ModuleEquipSelectionPanel
	add_child(panel)
	panel.open_for_module(module_instance, Callable(), true)

func _exit_tree() -> void:
	InventoryData.reset_runtime_state()
	PlayerData.reset_runtime_state()
