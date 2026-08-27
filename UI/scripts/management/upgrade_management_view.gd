extends Control
class_name UpgradeManagementView

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const UPGRADE_DETAIL_PRESENTER := preload("res://UI/scripts/management/upgrade_detail_presenter.gd")
const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")
const WEAPON_DISPLAY_POLICY := preload("res://UI/scripts/presentation/weapon_display_policy.gd")
const WEAPON_STAT_FORMATTER := preload("res://UI/scripts/presentation/weapon_stat_formatter.gd")

@onready var upgrade_mode_buttons: HBoxContainer = $UpgradeModeButtons
@onready var service_tabs: HBoxContainer = $ServiceTabs
@onready var upgrade_tab_button: Button = $ServiceTabs/UpgradeTabButton
@onready var fusion_tab_button: Button = $ServiceTabs/FusionTabButton
@onready var upgrade_weapon_mode_button: Button = $UpgradeModeButtons/UpgradeWeaponModeButton
@onready var upgrade_module_mode_button: Button = $UpgradeModeButtons/UpgradeModuleModeButton
@onready var upgrade_item_scroll: ScrollContainer = $UpgradeItemScroll
@onready var upgrade_item_list: BoxContainer = $UpgradeItemScroll/UpgradeItemList
@onready var upgrade_detail_panel: PanelContainer = $UpgradeDetailPanel
@onready var upgrade_detail_title: Label = $UpgradeDetailPanel/Margin/Root/Title
@onready var upgrade_detail_subtitle: Label = $UpgradeDetailPanel/Margin/Root/Subtitle
@onready var upgrade_detail_scroll: ScrollContainer = $UpgradeDetailPanel/Margin/Root/DetailScroll
@onready var upgrade_detail_body: VBoxContainer = $UpgradeDetailPanel/Margin/Root/DetailScroll/DetailBody
@onready var upgrade_action_button: Button = $UpgradeActionButton

var owner_ui: Node
var controller: UpgradeManagementController
var mode: StringName = &"weapon"
var hover_item: Dictionary = {}
var selected_item: Dictionary = {}
var selected_module: Module
var service_mode: StringName = &"upgrade"
var selected_fusion_branch_id := ""
var selected_core_keys: Array[String] = []
var fusion_submit_pending := false
var _upgrade_saved_hover: Dictionary = {}
var _upgrade_saved_selected: Dictionary = {}
var _upgrade_saved_module: Module
var _detail_presenter

func bind(owner_ui: Node, upgrade_controller: UpgradeManagementController = null) -> void:
	if owner_ui == null:
		return
	self.owner_ui = owner_ui
	controller = upgrade_controller
	_ensure_detail_presenter()
	upgrade_tab_button.pressed.connect(set_service_mode.bind(&"upgrade"))
	fusion_tab_button.pressed.connect(set_service_mode.bind(&"fusion"))
	InventoryData.weapon_cores_changed.connect(_on_fusion_state_changed)
	InventoryData.weapon_fusion_changed.connect(_on_weapon_fusion_changed)
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
	owner_ui.call("_style_management_button", upgrade_tab_button, true)
	owner_ui.call("_style_management_button", fusion_tab_button)
	set_service_mode(&"upgrade")

func set_service_mode(new_mode: StringName) -> void:
	var next_mode: StringName = &"fusion" if new_mode == &"fusion" else &"upgrade"
	if next_mode == service_mode:
		refresh_template()
		return
	if next_mode == &"fusion":
		_upgrade_saved_hover = hover_item.duplicate(true)
		_upgrade_saved_selected = selected_item.duplicate(true)
		_upgrade_saved_module = selected_module
	else:
		hover_item = _upgrade_saved_hover.duplicate(true)
		selected_item = _upgrade_saved_selected.duplicate(true)
		selected_module = _upgrade_saved_module
	service_mode = next_mode
	upgrade_tab_button.button_pressed = service_mode == &"upgrade"
	fusion_tab_button.button_pressed = service_mode == &"fusion"
	upgrade_mode_buttons.visible = service_mode == &"upgrade"
	if owner_ui:
		owner_ui.call("_refresh_mode_button_styles", upgrade_tab_button, fusion_tab_button, service_mode == &"upgrade")
	hover_item = {}
	if service_mode == &"fusion":
		selected_module = null
		if str(selected_item.get("type", "")) != "weapon":
			selected_item = {}
		_reset_fusion_selection()
	refresh_template()

func get_service_mode() -> StringName:
	return service_mode

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
	var items := build_items(&"weapon" if service_mode == &"fusion" else mode)
	_rebind_active_items(items)
	if items.is_empty():
		var empty := Label.new()
		empty.text = LocalizationManager.tr_key("ui.upgrade.empty", "No upgradeable items.")
		empty.add_theme_color_override("font_color", Color(0.72, 0.81, 0.86))
		upgrade_item_list.add_child(empty)
	if service_mode == &"upgrade" and mode == &"module":
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

func _rebind_active_items(items: Array[Dictionary]) -> void:
	var refreshed_selected: Dictionary = {}
	var refreshed_hover: Dictionary = {}
	for item_data in items:
		if refreshed_selected.is_empty() and items_match(selected_item, item_data):
			refreshed_selected = item_data.duplicate(true)
		if refreshed_hover.is_empty() and items_match(hover_item, item_data):
			refreshed_hover = item_data.duplicate(true)
	selected_item = refreshed_selected
	hover_item = refreshed_hover

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
	var changed_fusion_weapon := service_mode == &"fusion" and not items_match(selected_item, item_data)
	selected_item = item_data.duplicate(true)
	if str(item_data.get("type", "")) == "weapon":
		InventoryData.on_select_upg = item_data.get("weapon", null) as Weapon
		selected_module = null
	else:
		selected_module = item_data.get("module", null) as Module
		InventoryData.on_select_upg = null
	if changed_fusion_weapon:
		_reset_fusion_selection()
	refresh_template()
	_sync_controller_state()

func refresh_detail() -> void:
	if upgrade_detail_title == null or upgrade_detail_body == null:
		return
	_ensure_detail_presenter()
	upgrade_detail_subtitle.visible = true
	var active := selected_item if service_mode == &"fusion" else (hover_item if not hover_item.is_empty() else selected_item)
	if active.is_empty():
		upgrade_detail_title.text = ""
		upgrade_detail_subtitle.text = ""
		_clear_container(upgrade_detail_body)
		return
	if service_mode == &"fusion":
		_fill_fusion_detail(active)
		upgrade_detail_scroll.scroll_vertical = 0
		return
	upgrade_detail_title.text = str(active.get("name", ""))
	upgrade_detail_title.add_theme_color_override("font_color", active.get("rarity_color", Color(0.86, 0.94, 1.0)))
	upgrade_detail_subtitle.text = str(active.get("description", ""))
	_clear_container(upgrade_detail_body)
	if str(active.get("type", "")) == "weapon":
		_fill_weapon_detail(active)
	else:
		_fill_module_detail(active)
	upgrade_detail_scroll.scroll_vertical = 0

func trigger_action() -> bool:
	if service_mode == &"fusion":
		return _commit_selected_fusion()
	return try_upgrade_selected_item()

func try_upgrade_selected_item() -> bool:
	if not PhaseManager.can_configure_loadout():
		_show_message(LocalizationManager.tr_key("ui.upgrade.rest_only", "Upgrades are only available during rest."), 1.6)
		return false
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
	if not PlayerData.spend_gold(price):
		return false
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
	if service_mode == &"fusion":
		var preview := _get_fusion_preview()
		upgrade_action_button.disabled = fusion_submit_pending or not bool(preview.get("ok", false)) or not PhaseManager.can_configure_loadout()
		upgrade_action_button.text = LocalizationManager.tr_key("ui.fusion.confirm", "Confirm Fusion")
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
	var display_model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon, true, location_text)
	return {
		"type": "weapon",
		"id": str(weapon.get_instance_id()),
		"weapon": weapon,
		"display_model": display_model,
		"name": display_model.display_name,
		"description": display_model.description,
		"level": display_model.level,
		"max_level": display_model.max_level,
		"price": _get_weapon_upgrade_price(weapon),
		"icon": display_model.icon,
		"params": WEAPON_STAT_FORMATTER.format_summary(
			display_model.current_stats,
			WEAPON_DISPLAY_POLICY.summary_limit(WEAPON_DISPLAY_POLICY.UPGRADE_LIST)
		),
		"location": location_text,
		"rarity_color": RARITY_UTIL.get_color(display_model.rarity),
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
		var weapon_name := LocalizationManager.get_weapon_instance_display_name(owner)
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
		return GlobalVariables.economy_data.get_module_upgrade_gold(
			int(module_instance.cost),
			int(module_instance.module_level)
		)
	return EconomyConfig.new().get_module_upgrade_gold(
		int(module_instance.cost),
		int(module_instance.module_level)
	)

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

func _reset_fusion_selection() -> void:
	selected_fusion_branch_id = ""
	selected_core_keys.clear()

func _get_selected_fusion_weapon() -> Weapon:
	if selected_item.is_empty() or str(selected_item.get("type", "")) != "weapon":
		return null
	var weapon := selected_item.get("weapon", null) as Weapon
	return weapon if weapon != null and is_instance_valid(weapon) else null

func _get_fusion_branch_options(weapon: Weapon) -> Array[WeaponBranchDefinition]:
	var output: Array[WeaponBranchDefinition] = []
	if weapon == null or int(weapon.fuse) >= Weapon.MAX_FUSE_LEVEL:
		return output
	if int(weapon.fuse) == 1:
		return weapon.branch_runtime.get_available_branch_options_for_fuse(2)
	if weapon.branch_runtime.branch_ids.size() == 1:
		var branch := DataHandler.read_weapon_branch_definition(weapon.scene_file_path, str(weapon.branch_runtime.branch_ids[0]))
		if branch != null:
			output.append(branch)
	return output

func _resolve_fusion_branch(weapon: Weapon) -> WeaponBranchDefinition:
	for branch in _get_fusion_branch_options(weapon):
		if str(branch.branch_id) == selected_fusion_branch_id:
			return branch
	return null

func _get_fusion_preview() -> Dictionary:
	var weapon := _get_selected_fusion_weapon()
	if weapon == null:
		return {"ok": false, "reason_code": "invalid_weapon", "required_core_count": 0, "required_level": 0}
	return InventoryData.preview_weapon_fusion(weapon, selected_fusion_branch_id, selected_core_keys)

func _fill_fusion_detail(item_data: Dictionary) -> void:
	var weapon := item_data.get("weapon", null) as Weapon
	upgrade_detail_title.text = str(item_data.get("name", ""))
	upgrade_detail_subtitle.text = ""
	upgrade_detail_subtitle.visible = false
	_clear_container(upgrade_detail_body)
	if weapon == null or not is_instance_valid(weapon):
		_add_fusion_label(LocalizationManager.tr_key("ui.fusion.select_weapon", "Select a weapon to fuse."), Color(0.95, 0.65, 0.45))
		return
	var target_fuse := int(weapon.fuse) + 1
	var required_level := 3 if target_fuse == 2 else 6
	var required_count := 2 if target_fuse == 2 else 3
	_add_fusion_status_row(int(weapon.level), required_level)
	_add_fusion_stage_indicator(int(weapon.fuse), mini(target_fuse, Weapon.MAX_FUSE_LEVEL))
	var existing_branch := LocalizationManager.tr_key("ui.fusion.none", "None")
	if not weapon.branch_runtime.branch_ids.is_empty():
		var existing_def := DataHandler.read_weapon_branch_definition(weapon.scene_file_path, str(weapon.branch_runtime.branch_ids[0]))
		if existing_def:
			existing_branch = LocalizationManager.get_branch_display_name(existing_def)
	_add_fusion_label(LocalizationManager.tr_format("ui.fusion.current_branch", {"branch": existing_branch}, "Current branch: %s" % existing_branch))
	if int(weapon.fuse) >= Weapon.MAX_FUSE_LEVEL:
		_add_fusion_label(LocalizationManager.tr_key("ui.fusion.maxed", "Fusion complete."), Color(0.55, 0.9, 0.65))
		return
	_add_fusion_step_header(1, LocalizationManager.tr_key("ui.fusion.step.select_branch", "Select Branch"))
	var options := _get_fusion_branch_options(weapon)
	if selected_fusion_branch_id == "" and options.size() == 1 and target_fuse == 3:
		selected_fusion_branch_id = str(options[0].branch_id)
	var branch_row := HBoxContainer.new()
	branch_row.name = "FusionBranchOptions"
	branch_row.add_theme_constant_override("separation", 8)
	upgrade_detail_body.add_child(branch_row)
	for branch in options:
		_add_fusion_branch_button(branch, target_fuse == 3, branch_row)
	var branch := _resolve_fusion_branch(weapon)
	if branch == null:
		_add_fusion_label(LocalizationManager.tr_key("ui.fusion.select_branch", "Select a branch to inspect its recipe."), Color(0.95, 0.78, 0.42))
		return
	var recipe := branch.get_normalized_fusion_required_tags()
	_add_fusion_label(LocalizationManager.get_branch_description(branch), Color(0.72, 0.81, 0.86), 12)
	if target_fuse == 3:
		_add_fusion_label(LocalizationManager.tr_key("ui.fusion.enhancement_preview", "Enhancement: strengthens this branch's own effects."), Color(0.58, 0.86, 1.0))
	var preview := _get_fusion_preview()
	_add_fusion_step_header(2, LocalizationManager.tr_key("ui.fusion.step.meet_conditions", "Meet Conditions"))
	var covered_tags := preview.get("covered_tags", []) as Array
	for tag in recipe:
		_add_fusion_condition_tile(str(tag), covered_tags.has(tag))
	_add_fusion_condition_tile(
		LocalizationManager.tr_format("ui.fusion.core_count", {"selected": selected_core_keys.size(), "required": required_count}, "Cores %d / %d" % [selected_core_keys.size(), required_count]),
		bool(preview.get("core_count_ok", false))
	)
	_add_fusion_label(LocalizationManager.tr_key("ui.fusion.core_inventory", "Core Inventory"), Color(0.58, 0.86, 1.0), 13)
	for stack in InventoryData.get_weapon_core_stacks():
		_add_fusion_core_row(stack, recipe, required_count)
	if not selected_core_keys.is_empty():
		_add_fusion_label(LocalizationManager.tr_format("ui.fusion.consume_detail", {"cores": " | ".join(selected_core_keys)}, "Consume: %s" % " | ".join(selected_core_keys)), Color(0.82, 0.88, 0.9))
	_add_fusion_step_header(3, LocalizationManager.tr_key("ui.fusion.step.confirm", "Confirm Fusion"))
	_add_fusion_label(LocalizationManager.tr_format(
		"ui.fusion.unlock_preview",
		{"branch": LocalizationManager.get_branch_display_name(branch)},
		"Unlock: %s" % LocalizationManager.get_branch_display_name(branch)
	), Color(0.55, 0.9, 0.65) if bool(preview.get("ok", false)) else Color(0.72, 0.81, 0.86), 14)
	var reason_code := str(preview.get("reason_code", "invalid_weapon"))
	if reason_code != "level_too_low":
		_add_fusion_label(_fusion_reason_text(reason_code), Color(0.55, 0.9, 0.65) if bool(preview.get("ok", false)) else Color(1.0, 0.58, 0.42), 12)

func _add_fusion_status_row(level: int, required_level: int) -> void:
	var row := HBoxContainer.new()
	row.name = "FusionLevelStatus"
	row.add_theme_constant_override("separation", 8)
	upgrade_detail_body.add_child(row)
	var level_label := Label.new()
	level_label.text = LocalizationManager.tr_format("ui.fusion.level", {"level": level, "required": required_level}, "Level %d / %d" % [level, required_level])
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	row.add_child(level_label)
	var level_ok := level >= required_level
	var state := Label.new()
	state.text = ("✓ %s" % LocalizationManager.tr_key("ui.fusion.level_ready", "Level Ready")) if level_ok else ("× %s" % LocalizationManager.tr_key("ui.fusion.reason.level_too_low", "Weapon level is too low."))
	state.add_theme_font_size_override("font_size", 13)
	state.add_theme_color_override("font_color", Color(0.55, 0.9, 0.65) if level_ok else Color(1.0, 0.36, 0.3))
	state.add_theme_stylebox_override("normal", _fusion_state_style(level_ok))
	row.add_child(state)

func _add_fusion_stage_indicator(current_fuse: int, target_fuse: int) -> void:
	var root := VBoxContainer.new()
	root.name = "FusionStageIndicator"
	root.add_theme_constant_override("separation", 4)
	upgrade_detail_body.add_child(root)
	var title := Label.new()
	title.text = LocalizationManager.tr_key("ui.fusion.stage", "Fusion Stage")
	title.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))
	title.add_theme_font_size_override("font_size", 14)
	root.add_child(title)
	var stages := HBoxContainer.new()
	stages.add_theme_constant_override("separation", 8)
	root.add_child(stages)
	for stage in range(1, Weapon.MAX_FUSE_LEVEL + 1):
		var pip := Label.new()
		pip.custom_minimum_size = Vector2(64, 34)
		pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pip.text = str(stage)
		pip.add_theme_font_size_override("font_size", 16)
		var color := Color(0.44, 0.52, 0.57)
		if stage == current_fuse:
			color = Color(1.0, 0.72, 0.16)
		elif stage == target_fuse:
			color = Color(0.34, 0.84, 1.0)
		pip.add_theme_color_override("font_color", color)
		pip.add_theme_stylebox_override("normal", _fusion_stage_style(color, stage == current_fuse))
		stages.add_child(pip)
	var caption := Label.new()
	caption.text = LocalizationManager.tr_format("ui.fusion.stage_progress", {"current": current_fuse, "target": target_fuse}, "Current %d · Target %d" % [current_fuse, target_fuse])
	caption.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))
	caption.add_theme_font_size_override("font_size", 12)
	root.add_child(caption)

func _add_fusion_step_header(step: int, text: String) -> void:
	var label := Label.new()
	label.name = "FusionStep%d" % step
	label.text = "%d  %s" % [step, text]
	label.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))
	label.add_theme_font_size_override("font_size", 15)
	upgrade_detail_body.add_child(label)

func _add_fusion_condition_tile(text: String, satisfied: bool) -> void:
	var label := Label.new()
	label.custom_minimum_size = Vector2(0, 34)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "  %s   %s %s" % [text, "✓" if satisfied else "×", LocalizationManager.tr_key("ui.fusion.satisfied", "Satisfied") if satisfied else LocalizationManager.tr_key("ui.fusion.unmet", "Unmet")]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.42, 0.94, 0.52) if satisfied else Color(1.0, 0.36, 0.3))
	label.add_theme_stylebox_override("normal", _fusion_state_style(satisfied))
	upgrade_detail_body.add_child(label)

func _fusion_state_style(satisfied: bool) -> StyleBoxFlat:
	var color := Color(0.16, 0.72, 0.28) if satisfied else Color(0.9, 0.18, 0.14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.1)
	style.border_color = Color(color.r, color.g, color.b, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	return style

func _fusion_stage_style(color: Color, filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.22 if filled else 0.07)
	style.border_color = color
	style.set_border_width_all(2 if filled else 1)
	style.set_corner_radius_all(3)
	return style

func _add_fusion_branch_button(branch: WeaponBranchDefinition, enhanced: bool, parent: Container) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var suffix := "  ·  %s" % LocalizationManager.tr_key("ui.fusion.enhance", "Enhance") if enhanced else ""
	button.text = "%s%s\n%s" % [LocalizationManager.get_branch_display_name(branch), suffix, _format_tags(branch.get_normalized_fusion_required_tags())]
	button.toggle_mode = true
	button.button_pressed = selected_fusion_branch_id == str(branch.branch_id)
	button.pressed.connect(_select_fusion_branch.bind(str(branch.branch_id)))
	parent.add_child(button)
	if owner_ui:
		owner_ui.call("_style_management_button", button, button.button_pressed)

func _select_fusion_branch(branch_id: String) -> void:
	if selected_fusion_branch_id != branch_id:
		selected_fusion_branch_id = branch_id
		_prune_selected_cores()
	refresh_detail()
	refresh_action()

func _add_fusion_core_row(stack: Dictionary, recipe: Array[StringName], required_count: int) -> void:
	var key := str(stack.get("key", ""))
	var tags: Array = stack.get("tags", [])
	var contribution: Array[StringName] = []
	for tag in tags:
		if recipe.has(tag): contribution.append(tag)
	var chosen := selected_core_keys.count(key)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	upgrade_detail_body.add_child(row)
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "%s  x%d\n%s: %s  ·  %s: %s  ·  %s: %d" % [
		_format_tags(tags), int(stack.get("count", 0)),
		LocalizationManager.tr_key("ui.fusion.contributes", "Contributes"), _format_tags(contribution),
		LocalizationManager.tr_key("ui.fusion.selected", "Selected"), str(chosen),
		LocalizationManager.tr_key("ui.fusion.available", "Available"), int(stack.get("count", 0))]
	info.add_theme_font_size_override("font_size", 12)
	row.add_child(info)
	var minus := Button.new()
	minus.text = "−"
	minus.disabled = chosen <= 0
	minus.pressed.connect(_change_core_selection.bind(key, -1))
	row.add_child(minus)
	var plus := Button.new()
	plus.text = "+"
	plus.disabled = contribution.is_empty() or chosen >= int(stack.get("count", 0)) or selected_core_keys.size() >= required_count
	plus.tooltip_text = LocalizationManager.tr_key("ui.fusion.unrelated", "This core does not contribute a required Tag.") if contribution.is_empty() else ""
	plus.pressed.connect(_change_core_selection.bind(key, 1))
	row.add_child(plus)

func _change_core_selection(key: String, delta: int) -> void:
	if delta < 0:
		selected_core_keys.erase(key)
	elif delta > 0:
		selected_core_keys.append(key)
	refresh_detail()
	refresh_action()

func _prune_selected_cores() -> void:
	var branch := _resolve_fusion_branch(_get_selected_fusion_weapon())
	if branch == null:
		selected_core_keys.clear()
		return
	var required := branch.get_normalized_fusion_required_tags()
	var valid: Array[String] = []
	var available: Dictionary = {}
	for stack in InventoryData.get_weapon_core_stacks(): available[str(stack.get("key", ""))] = stack
	for key in selected_core_keys:
		var stack := available.get(key, {}) as Dictionary
		var contributes := false
		for tag in stack.get("tags", []):
			if required.has(tag): contributes = true
		if contributes and valid.count(key) < int(stack.get("count", 0)): valid.append(key)
	selected_core_keys = valid

func _commit_selected_fusion() -> bool:
	if fusion_submit_pending or not PhaseManager.can_configure_loadout():
		_show_message(LocalizationManager.tr_key("ui.fusion.rest_only", "Fusion is only available during rest."), 1.6)
		return false
	var weapon := _get_selected_fusion_weapon()
	fusion_submit_pending = true
	refresh_action()
	var result := InventoryData.commit_weapon_fusion(weapon, selected_fusion_branch_id, selected_core_keys)
	fusion_submit_pending = false
	if not bool(result.get("ok", false)):
		_prune_selected_cores()
		_show_message(_fusion_reason_text(str(result.get("reason_code", "commit_failed"))), 1.8)
		refresh_template()
		return false
	_reset_fusion_selection()
	_show_message(LocalizationManager.tr_key("ui.fusion.success", "Fusion complete."), 1.6)
	refresh_template()
	return true

func _on_fusion_state_changed() -> void:
	if service_mode == &"fusion":
		_prune_selected_cores()
		refresh_template()

func _on_weapon_fusion_changed(_weapon: Weapon, _result: Dictionary) -> void:
	if service_mode == &"fusion": refresh_template()

func _add_fusion_header(text: String) -> void:
	_add_fusion_label(text, Color(0.58, 0.86, 1.0), 15)

func _add_fusion_label(text: String, color: Color = Color(0.82, 0.88, 0.9), size: int = 13) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	upgrade_detail_body.add_child(label)

func _format_tags(tags: Variant) -> String:
	var parts := PackedStringArray()
	if tags is Array:
		for tag in tags: parts.append(str(tag))
	return "—" if parts.is_empty() else ", ".join(parts)

func _fusion_reason_text(code: String) -> String:
	var fallbacks := {
		"ready": "Ready to fuse.", "fused": "Fusion complete.", "level_too_low": "Weapon level is too low.",
		"core_count_mismatch": "Select the required number of cores.", "tags_missing": "Selected cores do not cover every required Tag.",
		"core_unrelated": "Every selected core must contribute a required Tag.", "core_missing": "A selected core is no longer available.",
		"branch_not_found": "Select a fusion branch.", "branch_not_available": "This branch is not available.",
		"branch_mismatch": "Fuse 3 must enhance the existing branch.", "fusion_maxed": "Fusion complete.",
		"fusion_in_progress": "Fusion is already being submitted.", "commit_failed": "Fusion failed without consuming cores.",
		"invalid_weapon": "Select a weapon to fuse.", "weapon_not_owned": "This weapon is no longer owned."
	}
	return LocalizationManager.tr_key("ui.fusion.reason.%s" % code, str(fallbacks.get(code, code)))

func _sync_controller_state() -> void:
	if controller != null:
		controller.sync_view_state()

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
