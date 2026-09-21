extends Control

const MODULE_SCENES: Array[PackedScene] = [
	preload("res://Player/Weapons/Modules/wmod_dash_impact.tscn"),
	preload("res://Player/Weapons/Modules/wmod_frost_resonance.tscn"),
	preload("res://Player/Weapons/Modules/wmod_skill_overdrive.tscn"),
]
const REWARD_PANEL_SCRIPT := preload("res://UI/components/RewardSelectionPanel/RewardSelectionPanel.gd")
const RARITY_UTIL := preload("res://data/LootRarity.gd")

var _modules: Array[Module] = []
var _previous_weapons: Array = []
var _reward_builder: Node

func _ready() -> void:
	_previous_weapons = PlayerData.player_weapon_list.duplicate()
	_prepare_fixtures()
	await get_tree().process_frame
	_build_gallery()

func _prepare_fixtures() -> void:
	for scene in MODULE_SCENES:
		var module := scene.instantiate() as Module
		module.visible = false
		%Fixtures.add_child(module)
		_modules.append(module)
	var weapon := (load("res://Player/Weapons/Instances/machine_gun.tscn") as PackedScene).instantiate() as Weapon
	weapon.visible = false
	%Fixtures.add_child(weapon)
	PlayerData.player_weapon_list = [weapon]

func _build_gallery() -> void:
	var title := Label.new()
	title.text = "技能触发模块 / SKILL TRIGGER MODULES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("a8e6ff"))
	%Content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "奖励卡中的触发条件、效果摘要、稀有度与安装语义"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("86a6b0"))
	%Content.add_child(subtitle)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	%Content.add_child(row)
	_reward_builder = REWARD_PANEL_SCRIPT.new()
	for index in _modules.size():
		var reward := RewardInfo.new()
		reward.module_scene = MODULE_SCENES[index]
		reward.module_level = index + 1
		reward.rarity = _modules[index].get_rarity()
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(370, 540)
		row.add_child(column)
		var caption := Label.new()
		caption.text = LocalizationManager.get_module_name(_modules[index])
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 17)
		caption.add_theme_color_override("font_color", RARITY_UTIL.get_color(reward.rarity))
		column.add_child(caption)
		var card := _reward_builder.call("_build_reward_card_button", reward, index) as Button
		card.custom_minimum_size = Vector2(370, 500)
		column.add_child(card)

func _exit_tree() -> void:
	PlayerData.player_weapon_list = _previous_weapons
	_modules.clear()
	if _reward_builder != null and is_instance_valid(_reward_builder):
		_reward_builder.free()
	_reward_builder = null
