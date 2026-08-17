extends Control

const MODULE_SCENES: Array[PackedScene] = [
	preload("res://Player/Weapons/Modules/wmod_dash_impact.tscn"),
	preload("res://Player/Weapons/Modules/wmod_frost_resonance.tscn"),
	preload("res://Player/Weapons/Modules/wmod_skill_overdrive.tscn"),
]
const REWARD_PANEL_SCRIPT := preload("res://UI/scripts/reward_selection_panel.gd")
const SHOP_MODULE_SLOT_SCENE := preload("res://UI/scenes/shop_module_slot.tscn")
const CARD_FACTORY_SCRIPT := preload("res://UI/scripts/management/module_management_card_factory.gd")
const UPGRADE_VIEW_SCRIPT := preload("res://UI/scripts/management/upgrade_management_view.gd")
const RARITY_UTIL := preload("res://data/LootRarity.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _modules: Array[Module] = []
var _reward_builder: RewardSelectionPanel
var _previous_weapons: Array = []
var selected_module: Module

func _ready() -> void:
	TranslationServer.set_locale("zh_CN")
	_previous_weapons = PlayerData.player_weapon_list.duplicate()
	_prepare_fixtures()
	await get_tree().process_frame
	await _capture_reward_cards()
	await _capture_shop_cards()
	await _capture_warehouse_cards()
	await _capture_upgrade_cards()
	print("MODULE_CARD_SCREENSHOTS_READY")
	await TEST_TEARDOWN.finish(self, 0, _reset_runtime_state)

func _prepare_fixtures() -> void:
	for scene in MODULE_SCENES:
		var module := scene.instantiate() as Module
		module.visible = false
		%Fixtures.add_child(module)
		_modules.append(module)
	var pistol := (load("res://Player/Weapons/Instances/pistol.tscn") as PackedScene).instantiate() as Weapon
	pistol.visible = false
	%Fixtures.add_child(pistol)
	PlayerData.player_weapon_list = [pistol]
	PlayerData.player_gold = 9999

func _capture_reward_cards() -> void:
	_reset_page()
	_add_header("奖励选择卡 / REWARD CARDS", "技能触发模组作为战斗奖励时的完整信息层级")
	var row := _make_centered_row(18)
	%Content.add_child(row)
	_reward_builder = REWARD_PANEL_SCRIPT.new()
	for index in range(MODULE_SCENES.size()):
		var reward := RewardInfo.new()
		reward.module_scene = MODULE_SCENES[index]
		reward.module_level = index + 1
		reward.rarity = _modules[index].get_rarity()
		var card := _reward_builder.call("_build_reward_card_button", reward, index) as Button
		card.custom_minimum_size = Vector2(370, 580)
		row.add_child(card)
	await _save_screenshot("module_cards_reward.png")
	_reward_builder.free()
	_reward_builder = null

func _capture_shop_cards() -> void:
	_reset_page()
	_add_header("商店购买卡 / SHOP CARDS", "同一模组在购买列表中的名称、价格、效果与标签")
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(760, 0)
	stack.add_theme_constant_override("separation", 22)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	%Content.add_child(stack)
	for index in range(MODULE_SCENES.size()):
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 18)
		stack.add_child(entry)
		entry.add_child(_make_index_label(index))
		var slot := SHOP_MODULE_SLOT_SCENE.instantiate() as ShopModuleSlot
		slot.custom_minimum_size = Vector2(650, 126)
		entry.add_child(slot)
		await get_tree().process_frame
		slot.call("_clear_preview")
		slot.module_scene = MODULE_SCENES[index]
		slot.preview_module = MODULE_SCENES[index].instantiate() as Module
		slot.preview_module.set_module_level(index + 1)
		slot.price = 120 + index * 40
		slot.call("_refresh_labels")
		slot.refresh_affordability()
		slot.queue_redraw()
	await _save_screenshot("module_cards_shop.png")

func _capture_warehouse_cards() -> void:
	_reset_page()
	_add_header("仓库模组卡 / WAREHOUSE CARDS", "装备管理中用于选择和拖拽安装的模组卡")
	var factory = CARD_FACTORY_SCRIPT.new()
	factory.bind(self, self)
	var row := _make_centered_row(18)
	%Content.add_child(row)
	for index in range(_modules.size()):
		_modules[index].set_module_level(index + 1)
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(370, 0)
		column.add_theme_constant_override("separation", 10)
		row.add_child(column)
		column.add_child(_make_module_caption(_modules[index]))
		var card := factory.make_module_button(_modules[index], index == 0, func() -> void: pass)
		card.custom_minimum_size = Vector2(370, 150)
		column.add_child(card)
	await _save_screenshot("module_cards_warehouse.png")

func _capture_upgrade_cards() -> void:
	_reset_page()
	_add_header("模组升级卡 / UPGRADE CARDS", "升级列表中的等级、费用、图标与参数摘要")
	var view := UPGRADE_VIEW_SCRIPT.new() as UpgradeManagementView
	var row := _make_centered_row(18)
	%Content.add_child(row)
	for index in range(_modules.size()):
		var module := _modules[index]
		module.set_module_level(index + 1)
		var card := Button.new()
		card.custom_minimum_size = Vector2(370, 170)
		row.add_child(card)
		var sprite := module.get_node_or_null("%Sprite") as Sprite2D
		var item_data := {
			"name": LocalizationManager.get_module_name(module),
			"level": module.module_level,
			"max_level": Module.MAX_LEVEL,
			"price": 80 + index * 35,
			"icon": sprite.texture if sprite else null,
			"params": module.get_level_effect_description(),
			"location": "仓库",
			"rarity_color": RARITY_UTIL.get_color(module.get_rarity()),
		}
		view.call("_populate_module_card", card, item_data)
	await _save_screenshot("module_cards_upgrade.png")
	view.free()

func _reset_page() -> void:
	for child in %Content.get_children():
		%Content.remove_child(child)
		child.free()

func _reset_runtime_state() -> void:
	PlayerData.player_weapon_list = _previous_weapons
	_modules.clear()
	_reward_builder = null

func _add_header(title_text: String, subtitle_text: String) -> void:
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.68, 0.9, 1.0))
	%Content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.7, 0.76))
	%Content.add_child(subtitle)

func _make_centered_row(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", separation)
	return row

func _make_index_label(index: int) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(72, 0)
	label.text = "%02d" % (index + 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.55, 0.82, 0.94))
	return label

func _make_module_caption(module: Module) -> Label:
	var label := Label.new()
	label.text = LocalizationManager.get_module_name(module)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", RARITY_UTIL.get_color(module.get_rarity()))
	return label

func _get_module_texture(module: Module) -> Texture2D:
	var sprite := module.get_node_or_null("%Sprite") as Sprite2D
	return sprite.texture if sprite else null

func _format_module_install_targets(module: Module) -> String:
	var targets := PackedStringArray()
	for value in module.get_normalized_required_weapon_traits():
		targets.append(str(value))
	for value in module.get_normalized_required_delivery_types():
		targets.append(str(value))
	for value in module.get_normalized_required_weapon_capabilities():
		targets.append(str(value))
	return "任意武器" if targets.is_empty() else " / ".join(targets)

func _style_management_button(button: Button, selected: bool = false) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.12, 0.15, 0.98) if not selected else Color(0.12, 0.22, 0.28, 1.0)
	panel.border_color = Color(0.28, 0.5, 0.62, 0.9) if not selected else Color(0.45, 0.88, 1.0, 1.0)
	panel.set_border_width_all(2 if selected else 1)
	panel.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", panel)
	button.add_theme_stylebox_override("hover", panel)

func _save_screenshot(file_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output_dir := ProjectSettings.globalize_path("res://output/ui_validation/module_cards")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var error := get_viewport().get_texture().get_image().save_png(output_dir.path_join(file_name))
	if error != OK:
		push_error("Failed to save screenshot %s: %s" % [file_name, error_string(error)])
