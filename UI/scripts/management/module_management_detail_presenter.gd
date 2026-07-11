extends RefCounted
class_name ModuleManagementDetailPresenter

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const MODULE_FIT_FORMATTER := preload("res://UI/scripts/module_fit_formatter.gd")
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")

var owner_view: Node
var detail_title: Label
var detail_subtitle: Label
var detail_body: VBoxContainer

func bind(view: Node, title: Label, subtitle: Label, body: VBoxContainer) -> void:
	owner_view = view
	detail_title = title
	detail_subtitle = subtitle
	detail_body = body

func set_detail_nodes(title: Label, subtitle: Label, body: VBoxContainer) -> void:
	detail_title = title
	detail_subtitle = subtitle
	detail_body = body

func refresh_weapon_detail(selected_equipped_weapon: Weapon, selected_stored_weapon: Weapon) -> void:
	var active_weapon := selected_stored_weapon if selected_stored_weapon != null else selected_equipped_weapon
	if active_weapon == null or not is_instance_valid(active_weapon):
		_set_empty_detail(
			LocalizationManager.tr_key("ui.warehouse.detail.empty", "Select an item"),
			LocalizationManager.tr_key("ui.weapon.warehouse.select_hint", "Select a held weapon to store, or a stored weapon to equip or exchange.")
		)
		return
	detail_title.text = LocalizationManager.get_weapon_instance_display_name(active_weapon)
	detail_title.add_theme_color_override("font_color", get_weapon_rarity_color(active_weapon))
	detail_subtitle.text = _get_weapon_location(active_weapon)
	_add_detail_line(
		LocalizationManager.tr_key("ui.common.level", "Level"),
		"Lv.%d/%d" % [int(active_weapon.level), int(active_weapon.max_level)]
	)
	_add_detail_line(LocalizationManager.tr_key("ui.weapon.fuse", "Fuse"), str(int(active_weapon.fuse)))
	_add_detail_line(
		LocalizationManager.tr_key("ui.weapon.modules", "Modules"),
		LocalizationManager.tr_key("ui.weapon.warehouse.modules_removed", "Stored weapons do not keep modules.")
	)
	_add_detail_text(build_weapon_param_summary(active_weapon))

func refresh_module_detail(selected_module: Module, selected_equipped_module: Module, selected_equipped_module_weapon: Weapon) -> void:
	var active_module := selected_module if selected_module != null else selected_equipped_module
	if active_module == null or not is_instance_valid(active_module):
		_set_empty_detail(
			LocalizationManager.tr_key("ui.warehouse.detail.empty", "Select an item"),
			LocalizationManager.tr_key("ui.module.select_prompt", "Select a temporary module, then click a compatible weapon slot.")
		)
		return
	detail_title.text = LocalizationManager.get_module_name(active_module)
	detail_title.add_theme_color_override("font_color", RARITY_UTIL.get_color(active_module.get_rarity()))
	detail_subtitle.text = _get_module_location(active_module, selected_equipped_module_weapon)
	_add_detail_line(
		LocalizationManager.tr_key("ui.common.level", "Level"),
		"Lv.%d/%d" % [int(active_module.module_level), Module.MAX_LEVEL]
	)
	_add_detail_line(
		LocalizationManager.tr_key("ui.common.rarity", "Rarity"),
		RARITY_UTIL.get_display_name(active_module.get_rarity())
	)
	_add_detail_line(
		LocalizationManager.tr_key("ui.module.install_targets", "Install Targets"),
		format_module_install_targets(active_module)
	)
	var fit_weapon := selected_equipped_module_weapon if selected_equipped_module_weapon != null else MODULE_FIT_FORMATTER.get_current_weapon()
	var fit_data: Dictionary = MODULE_FIT_FORMATTER.build_display_data(active_module, fit_weapon)
	var effect_chips: Array = fit_data.get("effect_chips", [])
	_add_detail_line(
		LocalizationManager.tr_key("ui.module.fit.label", "Fit"),
		str(fit_data.get("fit_label", LocalizationManager.tr_key("ui.module.fit.no_weapon", "No current weapon")))
	)
	if not effect_chips.is_empty():
		_add_detail_chip_row(effect_chips)
	for warning in fit_data.get("fit_warnings", PackedStringArray()):
		_add_detail_line(LocalizationManager.tr_key("ui.common.warning", "Warning"), str(warning))
	for description in active_module.get_effect_descriptions():
		var line := str(description)
		if MODULE_FIT_FORMATTER.filter_effect_description(line):
			_add_detail_text(line)

func get_module_texture(module_instance: Module) -> Texture2D:
	if module_instance == null or not is_instance_valid(module_instance):
		return null
	var sprite_node := module_instance.get_node_or_null("%Sprite")
	if sprite_node and sprite_node is Sprite2D:
		return (sprite_node as Sprite2D).texture
	if module_instance.get("sprite") is Sprite2D:
		return (module_instance.get("sprite") as Sprite2D).texture
	return null

func get_weapon_rarity(weapon: Weapon) -> String:
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	return weapon_def.get_rarity() if weapon_def else RARITY_UTIL.COMMON

func get_weapon_rarity_color(weapon: Weapon) -> Color:
	return RARITY_UTIL.get_color(get_weapon_rarity(weapon))

func build_weapon_param_summary(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return ""
	var weapon_data_variant: Variant = weapon.get("weapon_data")
	if not (weapon_data_variant is Dictionary):
		return ""
	var current_data := weapon.get_weapon_level_data(weapon.level, weapon_data_variant as Dictionary)
	var keys := ["damage", "fire_interval_sec", "ammo", "speed", "projectile_hits", "bullet_count"]
	var parts := PackedStringArray()
	for key in keys:
		if current_data.has(key):
			parts.append("%s: %s" % [key, str(current_data[key])])
	return "  ".join(parts)

func format_module_install_targets(module_instance: Module) -> String:
	if module_instance == null or not is_instance_valid(module_instance):
		return ""
	var parts := PackedStringArray()
	for value in module_instance.get_normalized_required_weapon_traits():
		parts.append(LocalizationManager.get_module_term(StringName(value), str(value).replace("_", " ").capitalize()))
	for value in module_instance.get_normalized_required_delivery_types():
		parts.append(LocalizationManager.get_module_term(StringName(value), str(value).replace("_", " ").capitalize()))
	for value in module_instance.get_normalized_required_weapon_capabilities():
		parts.append(LocalizationManager.get_module_term(StringName(value), str(value).replace("_", " ").capitalize()))
	if parts.is_empty():
		return LocalizationManager.tr_key("ui.shop.module.any_weapon", "Any weapon")
	return " / ".join(parts)

func _set_empty_detail(title: String, subtitle: String) -> void:
	detail_title.text = title
	detail_subtitle.text = subtitle

func _get_weapon_location(weapon: Weapon) -> String:
	if PlayerData.player_weapon_list.has(weapon):
		return LocalizationManager.tr_key("ui.weapon.location.equipped", "Held weapon")
	return LocalizationManager.tr_key("ui.weapon.location.stored", "Stored weapon")

func _get_module_location(module_instance: Module, selected_equipped_module_weapon: Weapon) -> String:
	if InventoryData.temporary_modules.has(module_instance):
		return LocalizationManager.tr_key("ui.module.location.temporary", "Temporary module")
	if selected_equipped_module_weapon:
		return LocalizationManager.tr_format(
			"ui.module.location.weapon",
			{"weapon": LocalizationManager.get_weapon_instance_display_name(selected_equipped_module_weapon)},
			"Installed on weapon"
		)
	return ""

func _add_detail_line(label: String, value: String) -> void:
	_add_detail_text("%s: %s" % [label, value])

func _add_detail_text(text: String) -> void:
	if text == "" or detail_body == null:
		return
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.9))
	detail_body.add_child(label)

func _add_detail_chip_row(chips: Array) -> void:
	if chips.is_empty() or detail_body == null:
		return
	var row := BUILD_TAG_DISPLAY.make_chip_row(chips, 5)
	detail_body.add_child(row)
