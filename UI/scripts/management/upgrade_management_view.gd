extends Control
class_name UpgradeManagementView

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const UPGRADE_DETAIL_PRESENTER := preload("res://UI/scripts/management/upgrade_detail_presenter.gd")

@onready var upgrade_mode_buttons: HBoxContainer = $UpgradeModeButtons
@onready var upgrade_weapon_mode_button: Button = $UpgradeModeButtons/UpgradeWeaponModeButton
@onready var upgrade_module_mode_button: Button = $UpgradeModeButtons/UpgradeModuleModeButton
@onready var upgrade_item_scroll: ScrollContainer = $UpgradeItemScroll
@onready var upgrade_item_list: BoxContainer = $UpgradeItemScroll/UpgradeItemList
@onready var upgrade_detail_panel: PanelContainer = $UpgradeDetailPanel
@onready var upgrade_detail_title: Label = $UpgradeDetailPanel/Margin/Root/Title
@onready var upgrade_detail_subtitle: Label = $UpgradeDetailPanel/Margin/Root/Subtitle
@onready var upgrade_detail_body: VBoxContainer = $UpgradeDetailPanel/Margin/Root/DetailScroll/DetailBody
@onready var upgrade_action_button: Button = $UpgradeActionButton

var owner_ui: Node
var controller: UpgradeManagementController
var mode: StringName = &"weapon"
var hover_item: Dictionary = {}
var selected_item: Dictionary = {}
var selected_module: Module
var _detail_presenter

func bind(owner_ui: Node, upgrade_controller: UpgradeManagementController = null) -> void:
	if owner_ui == null:
		return
	self.owner_ui = owner_ui
	controller = upgrade_controller
	_ensure_detail_presenter()
	if controller != null:
		var weapon_pressed := Callable(controller, "on_weapon_mode_pressed")
		var module_pressed := Callable(controller, "on_module_mode_pressed")
		var action_pressed := Callable(controller, "on_action_pressed")
		if not upgrade_weapon_mode_button.pressed.is_connected(weapon_pressed):
			upgrade_weapon_mode_button.pressed.connect(weapon_pressed)
		if not upgrade_module_mode_button.pressed.is_connected(module_pressed):
			upgrade_module_mode_button.pressed.connect(module_pressed)
		if not upgrade_action_button.pressed.is_connected(action_pressed):
			upgrade_action_button.pressed.connect(action_pressed)
	owner_ui.call("_style_management_button", upgrade_weapon_mode_button, true)
	owner_ui.call("_style_management_button", upgrade_module_mode_button)
	owner_ui.call("_style_management_button", upgrade_action_button, true)

func set_state(new_mode: StringName, new_hover: Dictionary, new_selected: Dictionary, new_selected_module: Module) -> void:
	mode = &"module" if new_mode == &"module" else &"weapon"
	hover_item = new_hover.duplicate(true)
	selected_item = new_selected.duplicate(true)
	selected_module = new_selected_module

func get_mode() -> StringName:
	return mode

func get_hover_item() -> Dictionary:
	return hover_item.duplicate(true)

func get_selected_item() -> Dictionary:
	return selected_item.duplicate(true)

func get_selected_module() -> Module:
	return selected_module

func _ensure_detail_presenter() -> void:
	if _detail_presenter == null:
		_detail_presenter = UPGRADE_DETAIL_PRESENTER.new()
		_detail_presenter.bind(self, upgrade_detail_body)
	else:
		_detail_presenter.set_detail_body(upgrade_detail_body)

func apply_mode(new_mode: StringName) -> void:
	mode = &"module" if new_mode == &"module" else &"weapon"
	upgrade_weapon_mode_button.button_pressed = mode == &"weapon"
	upgrade_module_mode_button.button_pressed = mode == &"module"
	if owner_ui:
		owner_ui.call(
			"_refresh_mode_button_styles",
			upgrade_weapon_mode_button,
			upgrade_module_mode_button,
			mode == &"weapon"
		)
	hover_item = {}
	selected_item = {}
	if mode == &"weapon":
		selected_module = null
		InventoryData.on_select_upg = null
	else:
		InventoryData.on_select_upg = null
	refresh_template()

func refresh_template() -> void:
	if upgrade_item_list == null:
		return
	ensure_item_list_layout()
	_clear_container(upgrade_item_list)
	var items := build_items(mode)
	if items.is_empty():
		var empty := Label.new()
		empty.text = LocalizationManager.tr_key("ui.upgrade.empty", "No upgradeable items.")
		empty.add_theme_color_override("font_color", Color(0.72, 0.81, 0.86))
		upgrade_item_list.add_child(empty)
	if mode == &"module":
		var row: HBoxContainer
		for index in range(items.size()):
			if index % 2 == 0:
				row = create_module_row()
			add_item_row(items[index], row)
	else:
		for item_data in items:
			add_item_row(item_data)
	refresh_detail()
	refresh_action()

func ensure_item_list_layout() -> void:
	if upgrade_item_list is VBoxContainer:
		return
	if upgrade_item_list != null and is_instance_valid(upgrade_item_list):
		upgrade_item_scroll.remove_child(upgrade_item_list)
		upgrade_item_list.queue_free()
	var replacement: BoxContainer = VBoxContainer.new()
	replacement.name = "UpgradeItemList"
	replacement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replacement.add_theme_constant_override("separation", 8)
	upgrade_item_scroll.add_child(replacement)
	upgrade_item_list = replacement

func create_module_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "UpgradeModuleRow"
	row.custom_minimum_size = Vector2(500, 92)
	row.add_theme_constant_override("separation", 8)
	upgrade_item_list.add_child(row)
	return row

func build_items(item_mode: StringName) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if item_mode == &"weapon":
		for weapon_ref in PlayerData.player_weapon_list:
			var weapon := weapon_ref as Weapon
			if weapon == null or not is_instance_valid(weapon):
				continue
			output.append(_build_weapon_item_data(weapon, _get_weapon_location_text(weapon)))
		for weapon in InventoryData.get_stored_weapons():
			if weapon == null or not is_instance_valid(weapon):
				continue
			output.append(_build_weapon_item_data(weapon, _get_weapon_location_text(weapon)))
	else:
		for module_ref in InventoryData.get_all_owned_modules():
			var module_instance := module_ref as Module
			if module_instance == null or not is_instance_valid(module_instance):
				continue
			output.append(_build_module_item_data(module_instance, _get_module_location_text(module_instance)))
	return output

func add_item_row(item_data: Dictionary, parent_container: Container = null) -> void:
	var button := Button.new()
	button.text = ""
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var compact_module := str(item_data.get("type", "")) == "module" and mode == &"module"
	button.custom_minimum_size = Vector2(246, 92) if compact_module else Vector2(500, 92)
	button.pressed.connect(_on_item_selected.bind(item_data))
	button.mouse_entered.connect(_on_item_hovered.bind(item_data))
	button.mouse_exited.connect(_on_item_unhovered.bind(item_data))
	var target := parent_container if parent_container != null else upgrade_item_list
	target.add_child(button)
	_populate_item_row(button, item_data, compact_module)
	item_data["button"] = button
	if owner_ui:
		owner_ui.call("_style_management_button", button, items_match(selected_item, item_data))

func _populate_item_row(button: Button, item_data: Dictionary, compact_module: bool = false) -> void:
	if compact_module:
		_populate_module_card(button, item_data)
		return
	var margin := MarginContainer.new()
	margin.name = "RowMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var icon_rect := TextureRect.new()
	icon_rect.name = "ItemIcon"
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.custom_minimum_size = Vector2(72, 72)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = item_data.get("icon", null) as Texture2D
	row.add_child(icon_rect)

	var text_box := VBoxContainer.new()
	text_box.name = "TextBox"
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = str(item_data.get("name", ""))
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", item_data.get("rarity_color", Color(0.86, 0.94, 1.0)))
	text_box.add_child(title)

	var level := int(item_data.get("level", 0))
	var max_level := int(item_data.get("max_level", 0))
	var price := int(item_data.get("price", 0))
	var price_text := "-" if level >= max_level else str(price)
	var level_label := Label.new()
	level_label.name = "LevelAndCost"
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.text = "Lv.%d/%d    %s" % [
		level,
		max_level,
		LocalizationManager.tr_format("ui.upgrade.cost", {"value": price_text}, "Cost: %s" % price_text),
	]
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.9))
	text_box.add_child(level_label)

	var params := Label.new()
	params.name = "CurrentParams"
	params.mouse_filter = Control.MOUSE_FILTER_IGNORE
	params.text = str(item_data.get("params", ""))
	params.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	params.add_theme_font_size_override("font_size", 12)
	params.add_theme_color_override("font_color", Color(0.82, 0.88, 0.9))
	text_box.add_child(params)

	var location := Label.new()
	location.name = "Location"
	location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location.text = str(item_data.get("location", ""))
	location.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	location.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	location.custom_minimum_size = Vector2(128, 0)
	location.add_theme_font_size_override("font_size", 13)
	location.add_theme_color_override("font_color", Color(0.9, 0.78, 0.42))
	row.add_child(location)

func _populate_module_card(button: Button, item_data: Dictionary) -> void:
	var margin := MarginContainer.new()
	margin.name = "RowMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	button.add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Row"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 1)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.name = "Top"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 4)
	root.add_child(top)

	var icon_rect := TextureRect.new()
	icon_rect.name = "ItemIcon"
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = item_data.get("icon", null) as Texture2D
	top.add_child(icon_rect)

	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = str(item_data.get("name", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", item_data.get("rarity_color", Color(0.86, 0.94, 1.0)))
	top.add_child(title)

	var level := int(item_data.get("level", 0))
	var max_level := int(item_data.get("max_level", 0))
	var price := int(item_data.get("price", 0))
	var price_text := "-" if level >= max_level else str(price)
	var level_label := Label.new()
	level_label.name = "LevelAndCost"
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.text = "Lv.%d/%d  %s" % [level, max_level, price_text]
	level_label.clip_text = true
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.9))
	root.add_child(level_label)

	var location := Label.new()
	location.name = "Location"
	location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location.text = str(item_data.get("location", ""))
	location.clip_text = true
	location.add_theme_font_size_override("font_size", 10)
	location.add_theme_color_override("font_color", Color(0.9, 0.78, 0.42))
	root.add_child(location)

	var params := Label.new()
	params.name = "CurrentParams"
	params.mouse_filter = Control.MOUSE_FILTER_IGNORE
	params.text = str(item_data.get("params", ""))
	params.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	params.add_theme_font_size_override("font_size", 10)
	params.add_theme_color_override("font_color", Color(0.82, 0.88, 0.9))
	root.add_child(params)

func _on_item_hovered(item_data: Dictionary) -> void:
	hover_item = item_data.duplicate(true)
	refresh_detail()
	_sync_controller_state()

func _on_item_unhovered(item_data: Dictionary) -> void:
	if items_match(hover_item, item_data):
		hover_item = {}
	refresh_detail()
	_sync_controller_state()

func _on_item_selected(item_data: Dictionary) -> void:
	selected_item = item_data.duplicate(true)
	if str(item_data.get("type", "")) == "weapon":
		InventoryData.on_select_upg = item_data.get("weapon", null) as Weapon
		selected_module = null
	else:
		selected_module = item_data.get("module", null) as Module
		InventoryData.on_select_upg = null
	refresh_template()
	_sync_controller_state()

func refresh_detail() -> void:
	if upgrade_detail_title == null or upgrade_detail_body == null:
		return
	_ensure_detail_presenter()
	var active := hover_item if not hover_item.is_empty() else selected_item
	if active.is_empty():
		upgrade_detail_title.text = ""
		upgrade_detail_subtitle.text = ""
		_clear_container(upgrade_detail_body)
		return
	upgrade_detail_title.text = str(active.get("name", ""))
	upgrade_detail_title.add_theme_color_override("font_color", active.get("rarity_color", Color(0.86, 0.94, 1.0)))
	upgrade_detail_subtitle.text = str(active.get("description", ""))
	_clear_container(upgrade_detail_body)
	if str(active.get("type", "")) == "weapon":
		_fill_weapon_detail(active)
	else:
		_fill_module_detail(active)

func trigger_action() -> bool:
	return try_upgrade_selected_item()

func try_upgrade_selected_item() -> bool:
	if selected_item.is_empty():
		_show_message(LocalizationManager.tr_key("ui.upgrade.select_first", "Select an item first."), 1.3)
		return false
	if str(selected_item.get("type", "")) == "weapon":
		return _try_upgrade_weapon(selected_item)
	return _try_upgrade_module(selected_item)

func _try_upgrade_weapon(item_data: Dictionary) -> bool:
	var weapon := item_data.get("weapon", null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		return false
	if int(weapon.level) >= int(weapon.max_level):
		_show_message(LocalizationManager.tr_key("ui.upgrade.fully_upgraded", "Fully upgraded."), 1.4)
		return false
	var price := _get_weapon_upgrade_price(weapon)
	if PlayerData.player_gold < price:
		_show_message(LocalizationManager.tr_key("ui.shop.not_enough_gold", "Not enough gold."), 1.4)
		return false
	PlayerData.player_gold -= price
	weapon.set_level(int(weapon.level) + 1)
	if controller != null:
		controller.update_upg()
	return true

func _try_upgrade_module(item_data: Dictionary) -> bool:
	var module_instance := item_data.get("module", null) as Module
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	var result := InventoryData.upgrade_module_with_gold(module_instance)
	if not result.get("ok", false):
		_show_message(str(result.get("reason", "")), 1.6)
		return false
	if controller != null:
		controller.update_upg()
	return true

func refresh_action() -> void:
	if upgrade_action_button == null:
		return
	var ready := false
	var price := 0
	if not selected_item.is_empty():
		if str(selected_item.get("type", "")) == "weapon":
			var weapon := selected_item.get("weapon", null) as Weapon
			ready = weapon != null and is_instance_valid(weapon) and int(weapon.level) < int(weapon.max_level)
			price = _get_weapon_upgrade_price(weapon) if ready else 0
		else:
			var module_instance := selected_item.get("module", null) as Module
			ready = module_instance != null and is_instance_valid(module_instance) and int(module_instance.module_level) < Module.MAX_LEVEL
			price = _get_module_upgrade_price(module_instance) if ready else 0
	upgrade_action_button.disabled = not ready or PlayerData.player_gold < price
	upgrade_action_button.text = LocalizationManager.tr_format(
		"ui.upgrade.action_price",
		{"value": price},
		"Upgrade: %s" % price
	) if ready else LocalizationManager.tr_key("ui.upgrade.action_empty", "Upgrade")

func _build_weapon_item_data(weapon: Weapon, location_text: String = "") -> Dictionary:
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	var rarity := weapon_def.get_rarity() if weapon_def else RARITY_UTIL.COMMON
	return {
		"type": "weapon",
		"id": str(weapon.get_instance_id()),
		"weapon": weapon,
		"name": LocalizationManager.get_weapon_name_from_node(weapon),
		"description": LocalizationManager.get_weapon_description_from_definition(weapon_def) if weapon_def else "",
		"level": int(weapon.level),
		"max_level": int(weapon.max_level),
		"price": _get_weapon_upgrade_price(weapon),
		"icon": weapon.sprite.texture if weapon.sprite else null,
		"params": _build_weapon_param_summary(weapon),
		"location": location_text,
		"rarity_color": RARITY_UTIL.get_color(rarity),
	}

func _build_module_item_data(module_instance: Module, location_text: String = "") -> Dictionary:
	var rarity := module_instance.get_rarity()
	return {
		"type": "module",
		"id": str(module_instance.get_instance_id()),
		"module": module_instance,
		"name": LocalizationManager.get_module_name(module_instance),
		"description": "\n".join(module_instance.get_effect_descriptions()),
		"level": int(module_instance.module_level),
		"max_level": Module.MAX_LEVEL,
		"price": _get_module_upgrade_price(module_instance),
		"icon": _get_module_texture(module_instance),
		"params": _build_module_param_summary(module_instance),
		"location": location_text,
		"rarity_color": RARITY_UTIL.get_color(rarity),
	}

func _build_weapon_param_summary(weapon: Weapon) -> String:
	_ensure_detail_presenter()
	return _detail_presenter.build_weapon_param_summary(weapon)

func _build_module_param_summary(module_instance: Module) -> String:
	_ensure_detail_presenter()
	return _detail_presenter.build_module_param_summary(module_instance)

func _get_weapon_location_text(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return ""
	var equipped_index := PlayerData.player_weapon_list.find(weapon)
	if equipped_index >= 0:
		return LocalizationManager.tr_format(
			"ui.service.location.equipped_slot",
			{"slot": equipped_index + 1},
			"Equipped %d" % (equipped_index + 1)
		)
	if InventoryData.weapon_storage.has(weapon):
		return LocalizationManager.tr_key("ui.service.location.storage", "Storage")
	return LocalizationManager.tr_key("ui.service.value.unknown", "Unknown")

func _get_module_location_text(module_instance: Module) -> String:
	if module_instance == null or not is_instance_valid(module_instance):
		return ""
	if InventoryData.temporary_modules.has(module_instance):
		return LocalizationManager.tr_key("ui.service.location.temporary_storage", "Temporary Storage")
	var owner := _resolve_module_owner_weapon(module_instance)
	if owner != null:
		var weapon_name := LocalizationManager.get_weapon_name_from_node(owner)
		if PlayerData.player_weapon_list.has(owner):
			return LocalizationManager.tr_format(
				"ui.service.location.equipped_weapon",
				{"weapon": weapon_name},
				"Equipped: %s" % weapon_name
			)
		if InventoryData.weapon_storage.has(owner):
			return LocalizationManager.tr_format(
				"ui.service.location.stored_weapon",
				{"weapon": weapon_name},
				"Stored Weapon: %s" % weapon_name
			)
		return weapon_name
	return LocalizationManager.tr_key("ui.service.value.unknown", "Unknown")

func _resolve_module_owner_weapon(module_instance: Module) -> Weapon:
	var current: Node = module_instance
	while current:
		if current is Weapon:
			return current as Weapon
		current = current.get_parent()
	return null

func _get_module_texture(module_instance: Module) -> Texture2D:
	if module_instance == null or not is_instance_valid(module_instance):
		return null
	var sprite := module_instance.get_node_or_null("%Sprite") as Sprite2D
	return sprite.texture if sprite else null

func items_match(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	return str(a.get("type", "")) == str(b.get("type", "")) and str(a.get("id", "")) == str(b.get("id", ""))

func _fill_weapon_detail(item_data: Dictionary) -> void:
	_ensure_detail_presenter()
	_detail_presenter.fill_weapon_detail(item_data)

func _fill_module_detail(item_data: Dictionary) -> void:
	_ensure_detail_presenter()
	_detail_presenter.fill_module_detail(item_data)

func _format_stat_dictionary(data: Dictionary) -> String:
	_ensure_detail_presenter()
	return _detail_presenter.format_stat_dictionary(data)

func _format_stat_label(key: String) -> String:
	_ensure_detail_presenter()
	return _detail_presenter.format_stat_label(key)

func _format_weapon_definition_types(weapon_def: WeaponDefinition) -> String:
	_ensure_detail_presenter()
	return _detail_presenter.format_weapon_definition_types(weapon_def)

func _format_module_install_targets(module_instance: Module) -> String:
	_ensure_detail_presenter()
	return _detail_presenter.format_module_install_targets(module_instance)

func _format_type_name(value: String) -> String:
	_ensure_detail_presenter()
	return _detail_presenter.format_type_name(value)

func _get_weapon_upgrade_price(weapon: Weapon) -> int:
	if weapon == null or not is_instance_valid(weapon):
		return 0
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null:
		return 0
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_weapon_upgrade_gold(int(weapon_def.price))
	return maxi(1, int(round(float(weapon_def.price) * 0.5)))

func _get_module_upgrade_price(module_instance: Module) -> int:
	if module_instance == null or not is_instance_valid(module_instance):
		return 0
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_module_upgrade_gold(int(module_instance.cost))
	return EconomyConfig.new().get_module_upgrade_gold(int(module_instance.cost))

func _add_detail_section(title: String, value: String) -> void:
	_ensure_detail_presenter()
	_detail_presenter.call("_add_detail_section", title, value)

func _add_detail_header(text: String) -> void:
	_ensure_detail_presenter()
	_detail_presenter.call("_add_detail_header", text)

func _add_detail_text(text: String) -> void:
	_ensure_detail_presenter()
	_detail_presenter.call("_add_detail_text", text)

func _show_message(text: String, duration: float) -> void:
	if owner_ui and owner_ui.has_method("show_item_message"):
		owner_ui.call("show_item_message", text, duration)

func _sync_controller_state() -> void:
	if controller != null:
		controller.sync_view_state()

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
