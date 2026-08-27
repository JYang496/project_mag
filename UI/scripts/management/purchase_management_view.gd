extends Control
class_name PurchaseManagementView

const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")
const WEAPON_STAT_FORMATTER := preload("res://UI/scripts/presentation/weapon_stat_formatter.gd")

@onready var shop_mode_buttons: HBoxContainer = $ShopModeButtons
@onready var shop_weapon_mode_button: Button = $ShopModeButtons/BuyWeaponModeButton
@onready var shop_module_mode_button: Button = $ShopModeButtons/BuyModuleModeButton
@onready var shop: VBoxContainer = $Shop
@onready var shop_refresh_button: Button = $ShopRefreshButton
@onready var shop_purchase_button: Button = $ShopPurchaseButton
@onready var shop_back_button: Button = $BackToPurchaseMenu
@onready var shop_detail_panel: PanelContainer = $ShopDetailPanel
@onready var shop_detail_title: Label = $ShopDetailPanel/Margin/Root/Title
@onready var shop_detail_subtitle: Label = $ShopDetailPanel/Margin/Root/Subtitle
@onready var shop_detail_scroll: ScrollContainer = $ShopDetailPanel/Margin/Root/DetailScroll
@onready var shop_detail_body: VBoxContainer = $ShopDetailPanel/Margin/Root/DetailScroll/DetailBody

var owner_ui: Node
var controller: PurchaseManagementController
var weapon_shop: VBoxContainer
var module_shop: VBoxContainer
var purchase_action_button: Button
var purchase_mode: StringName = &"weapon"
var hover_item: Dictionary = {}
var selected_item: Dictionary = {}

func bind(owner_ui: Node, purchase_controller: PurchaseManagementController = null) -> void:
	if owner_ui == null:
		return
	self.owner_ui = owner_ui
	controller = purchase_controller
	if controller != null:
		var weapon_pressed := Callable(controller, "on_weapon_mode_pressed")
		var module_pressed := Callable(controller, "on_module_mode_pressed")
		if not shop_weapon_mode_button.pressed.is_connected(weapon_pressed):
			shop_weapon_mode_button.pressed.connect(weapon_pressed)
		if not shop_module_mode_button.pressed.is_connected(module_pressed):
			shop_module_mode_button.pressed.connect(module_pressed)
	if owner_ui.get("rest_area_ui_controller") != null:
		var back_pressed := Callable(owner_ui.rest_area_ui_controller, "back_to_purchase_primary_menu")
		if not shop_back_button.pressed.is_connected(back_pressed):
			shop_back_button.pressed.connect(back_pressed)
	owner_ui.call("_style_management_button", shop_weapon_mode_button, true)
	owner_ui.call("_style_management_button", shop_module_mode_button)
	owner_ui.call("_style_management_button", shop_refresh_button)
	owner_ui.call("_style_management_button", shop_purchase_button, true)
	owner_ui.call("_style_management_button", shop_back_button)
	_connect_outcome_refresh_signals()

func _exit_tree() -> void:
	_disconnect_outcome_refresh_signals()

func _connect_outcome_refresh_signals() -> void:
	var callback := Callable(self, "_on_shop_outcome_state_changed")
	for source_signal in [PlayerData.weapon_list_changed, InventoryData.weapon_storage_changed, InventoryData.weapon_cores_changed]:
		if not source_signal.is_connected(callback):
			source_signal.connect(callback)

func _disconnect_outcome_refresh_signals() -> void:
	var callback := Callable(self, "_on_shop_outcome_state_changed")
	for source_signal in [PlayerData.weapon_list_changed, InventoryData.weapon_storage_changed, InventoryData.weapon_cores_changed]:
		if source_signal.is_connected(callback):
			source_signal.disconnect(callback)

func _on_shop_outcome_state_changed() -> void:
	if weapon_shop == null or not is_instance_valid(weapon_shop):
		return
	for child in weapon_shop.get_children():
		if child.has_method("refresh_obtain_presentation"):
			child.call("refresh_obtain_presentation")
	selected_item = _rebuild_live_item_data(selected_item)
	hover_item = _rebuild_live_item_data(hover_item)
	refresh_detail()
	refresh_purchase_action()

func _rebuild_live_item_data(item_data: Dictionary) -> Dictionary:
	if item_data.is_empty():
		return {}
	var slot := item_data.get("slot", null) as Node
	if slot == null or not is_instance_valid(slot) or not slot.has_method("_build_shop_item_data"):
		return {}
	return slot.call("_build_shop_item_data") as Dictionary

func set_shop_context(weapon_shop_list: VBoxContainer, action_button: Button) -> void:
	weapon_shop = weapon_shop_list
	purchase_action_button = action_button

func set_module_shop(module_shop_list: VBoxContainer) -> void:
	module_shop = module_shop_list

func apply_purchase_mode(mode: StringName) -> void:
	purchase_mode = &"module" if mode == &"module" else &"weapon"
	if weapon_shop:
		weapon_shop.visible = purchase_mode == &"weapon"
	if module_shop:
		var module_scroll := module_shop.get_parent() as Control
		if module_scroll:
			module_scroll.visible = purchase_mode == &"module"
	shop_detail_panel.visible = true
	shop_weapon_mode_button.button_pressed = purchase_mode == &"weapon"
	shop_module_mode_button.button_pressed = purchase_mode == &"module"
	if owner_ui:
		owner_ui.call(
			"_refresh_mode_button_styles",
			shop_weapon_mode_button,
			shop_module_mode_button,
			purchase_mode == &"weapon"
		)
	hover_item = {}
	selected_item = {}
	clear_slot_selection()
	refresh_detail()
	refresh_purchase_action()

func get_purchase_mode() -> StringName:
	return purchase_mode

func get_hover_item() -> Dictionary:
	return hover_item.duplicate(true)

func get_selected_item() -> Dictionary:
	return selected_item.duplicate(true)

func set_hover_item(item_data: Dictionary) -> void:
	hover_item = item_data.duplicate(true)
	refresh_detail()

func clear_hover_item(item_data: Dictionary = {}) -> void:
	if item_data.is_empty():
		hover_item = {}
	elif _items_match(hover_item, item_data):
		hover_item = {}
	refresh_detail()

func set_selected_item(item_data: Dictionary) -> void:
	selected_item = item_data.duplicate(true)
	apply_selection_highlight(selected_item)
	refresh_detail()
	refresh_purchase_action()

func clear_selected_item(item_data: Dictionary = {}) -> void:
	if item_data.is_empty():
		selected_item = {}
		clear_slot_selection()
	elif _items_match(selected_item, item_data):
		selected_item = {}
		clear_slot_selection()
	refresh_detail()
	refresh_purchase_action()

func purchase_selected_item() -> bool:
	if selected_item.is_empty():
		_show_message(LocalizationManager.tr_key("ui.shop.select_first", "Select an item first."), 1.3)
		return false
	var slot := selected_item.get("slot", null) as Node
	if slot == null or not is_instance_valid(slot):
		selected_item = {}
		clear_slot_selection()
		refresh_detail()
		refresh_purchase_action()
		return false
	if not slot.has_method("try_purchase"):
		return false
	var purchased := bool(slot.call("try_purchase"))
	if purchased:
		selected_item = {}
		hover_item = {}
		clear_slot_selection()
		refresh_detail()
	refresh_purchase_action()
	return purchased

func apply_selection_highlight(item_data: Dictionary) -> void:
	clear_slot_selection()
	var slot := item_data.get("slot", null) as Node
	if slot != null and is_instance_valid(slot) and slot.has_method("set_selected"):
		slot.call("set_selected", true)

func clear_slot_selection() -> void:
	if weapon_shop:
		for child in weapon_shop.get_children():
			if child.has_method("set_selected"):
				child.call("set_selected", false)
	if module_shop:
		for child in module_shop.get_children():
			if child.has_method("set_selected"):
				child.call("set_selected", false)

func refresh_purchase_action() -> void:
	if purchase_action_button == null or not is_instance_valid(purchase_action_button):
		return
	var selected_slot := selected_item.get("slot", null) as Node
	var has_selection := selected_slot != null and is_instance_valid(selected_slot)
	var can_buy := false
	if has_selection and selected_slot.has_method("can_purchase"):
		can_buy = bool(selected_slot.call("can_purchase"))
	purchase_action_button.disabled = not can_buy
	var selected_name := str(selected_item.get("name", ""))
	if selected_name == "":
		purchase_action_button.text = LocalizationManager.tr_key("ui.shop.buy.select", "Buy")
	else:
		var prediction := selected_item.get("obtain_prediction", {}) as Dictionary
		if str(prediction.get("result", "")) == "dismantled_to_core":
			purchase_action_button.text = LocalizationManager.tr_format("ui.shop.buy_core", {"name": selected_name}, "Buy %s Core" % selected_name)
		else:
			purchase_action_button.text = LocalizationManager.tr_format("ui.shop.buy.item", {"name": selected_name}, "Buy %s" % selected_name)

func refresh_detail() -> void:
	if shop_detail_title == null or shop_detail_body == null:
		return
	var active := hover_item if not hover_item.is_empty() else selected_item
	if active.is_empty():
		clear_detail()
		return
	var prediction := active.get("obtain_prediction", {}) as Dictionary
	var becomes_core := str(prediction.get("result", "")) == "dismantled_to_core"
	var active_name := str(active.get("name", ""))
	shop_detail_title.text = LocalizationManager.tr_format("ui.shop.core.named_title", {"name": active_name}, "%s Core" % active_name) if becomes_core else active_name
	shop_detail_title.add_theme_color_override("font_color", Color(0.94, 0.58, 0.18, 1.0) if becomes_core else active.get("rarity_color", Color(0.86, 0.94, 1.0)))
	shop_detail_subtitle.text = LocalizationManager.tr_key("ui.shop.core.detail_subtitle", "Purchase yields a weapon core for manual fusion.") if becomes_core else str(active.get("description", ""))
	_clear_container(shop_detail_body)
	match str(active.get("type", "")):
		"weapon":
			_fill_weapon_detail(active)
		"module":
			_fill_module_detail(active)
		_:
			clear_detail()

func clear_detail() -> void:
	if shop_detail_title:
		shop_detail_title.text = ""
	if shop_detail_subtitle:
		shop_detail_subtitle.text = ""
	if shop_detail_body:
		_clear_container(shop_detail_body)

func _fill_weapon_detail(item_data: Dictionary) -> void:
	var weapon_def := item_data.get("definition", null) as WeaponDefinition
	if weapon_def == null:
		return
	var display_model = item_data.get("display_model", null)
	if display_model == null:
		display_model = WEAPON_DISPLAY_BUILDER.build_from_definition(weapon_def)
	var prediction := item_data.get("obtain_prediction", {}) as Dictionary
	var becomes_core := str(prediction.get("result", "")) == "dismantled_to_core"
	if becomes_core:
		var preview := WeaponObtainPreviewFormatter.format_obtain_preview("", str(item_data.get("name", "")), prediction)
		_add_detail_section(LocalizationManager.tr_key("ui.shop.core.purchase_result", "Purchase Result"), preview)
		var usages := prediction.get("usable_branches", []) as Array
		var branch_names := PackedStringArray()
		for usage_variant in usages:
			var usage := usage_variant as Dictionary
			var usage_weapon := DataHandler.read_weapon_data(str(usage.get("weapon_id", ""))) as WeaponDefinition
			if usage_weapon == null: continue
			var usage_branch := DataHandler.read_weapon_branch_definition(usage_weapon.scene_path, str(usage.get("branch_id", "")))
			if usage_branch: branch_names.append("%s · %s" % [LocalizationManager.get_weapon_name_by_id(usage_weapon.weapon_id, usage_weapon.weapon_id), LocalizationManager.get_branch_display_name(usage_branch)])
		if not branch_names.is_empty():
			_add_detail_section(LocalizationManager.tr_key("ui.reward.core.usable_by_label", "Usable By"), "\n".join(branch_names))
	_add_detail_section(LocalizationManager.tr_key("ui.service.detail.purchase_price", "Purchase Price"), str(int(item_data.get("price", 0))))
	_add_detail_section(
		LocalizationManager.tr_key("ui.shop.core.source_weapon_type", "Source Weapon Type") if becomes_core else LocalizationManager.tr_key("ui.service.detail.weapon_type", "Weapon Type"),
		display_model.taxonomy_text()
	)
	if not display_model.current_stats.is_empty():
		_add_detail_section(
			LocalizationManager.tr_key("ui.shop.core.source_weapon_stats", "Source Weapon Stats") if becomes_core else LocalizationManager.tr_key("ui.weapon.detail.core_stats", "Core Stats"),
			WEAPON_STAT_FORMATTER.format_summary(display_model.current_stats, 4, "\n")
		)
	var level_rows := _build_weapon_level_rows(weapon_def)
	if not level_rows.is_empty():
		_add_collapsible_detail_section(
			LocalizationManager.tr_key("ui.service.detail.levels_and_costs", "Level Stats / Upgrade Cost"),
			level_rows
		)
	if not display_model.available_branches.is_empty():
		var branch_lines := PackedStringArray()
		for branch_data in display_model.available_branches:
			var branch_name := str(branch_data.get("name", ""))
			var branch_desc := str(branch_data.get("description", ""))
			var unlock_text := LocalizationManager.tr_format(
				"ui.weapon.fuse_value",
				{"fuse": int(branch_data.get("unlock_fuse", 0))},
				"Fuse %d" % int(branch_data.get("unlock_fuse", 0))
			)
			branch_lines.append("%s  [%s]\n%s" % [branch_name, unlock_text, branch_desc])
		_add_collapsible_detail_section(
			LocalizationManager.tr_key("ui.service.detail.branches", "Branches"),
			branch_lines
		)

func _fill_module_detail(item_data: Dictionary) -> void:
	var module_instance := item_data.get("module", null) as Module
	if module_instance == null or not is_instance_valid(module_instance):
		return
	_add_detail_section(LocalizationManager.tr_key("ui.service.detail.install_targets", "Compatible Weapons"), _format_module_install_targets(module_instance))
	_add_detail_section(LocalizationManager.tr_key("ui.service.detail.purchase_price", "Purchase Price"), str(int(item_data.get("price", 0))))
	_add_detail_header(LocalizationManager.tr_key("ui.service.detail.levels_and_costs", "Level Stats / Upgrade Cost"))
	var original_level := int(module_instance.module_level)
	for level in range(1, Module.MAX_LEVEL + 1):
		module_instance.set_module_level(level)
		var effects := module_instance.get_effect_descriptions()
		var upgrade_price := "-" if level >= Module.MAX_LEVEL else str(_get_module_upgrade_cost(module_instance))
		_add_detail_text(LocalizationManager.tr_format(
			"ui.service.detail.upgrade_row",
			{"level": level, "price": upgrade_price, "effects": "\n".join(effects)},
			"Lv.%d  Upgrade: %s\n%s" % [level, upgrade_price, "\n".join(effects)]
		))
	module_instance.set_module_level(original_level)

func _build_weapon_level_rows(weapon_def: WeaponDefinition) -> PackedStringArray:
	var rows := PackedStringArray()
	if weapon_def.scene == null:
		return rows
	var weapon := weapon_def.scene.instantiate() as Weapon
	if weapon == null:
		return rows
	var weapon_data_variant: Variant = weapon.get("weapon_data")
	if not (weapon_data_variant is Dictionary):
		weapon.queue_free()
		return rows
	var weapon_data := weapon_data_variant as Dictionary
	var keys: Array = weapon_data.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for key in keys:
		var level_data := weapon.get_weapon_level_data(key, weapon_data)
		if level_data.is_empty():
			continue
		var upgrade_price := "-" if int(key) >= keys.size() else str(_get_weapon_upgrade_cost(weapon_def))
		rows.append(LocalizationManager.tr_format(
			"ui.service.detail.upgrade_row",
			{"level": str(key), "price": upgrade_price, "effects": _format_stat_dictionary(level_data)},
			"Lv.%s  Upgrade: %s\n%s" % [str(key), upgrade_price, _format_stat_dictionary(level_data)]
		))
	weapon.queue_free()
	return rows

func _format_stat_dictionary(data: Dictionary) -> String:
	return WEAPON_STAT_FORMATTER.format_dictionary(data)

func _format_stat_label(key: String) -> String:
	return WEAPON_STAT_FORMATTER.format_label(key)

func _format_weapon_definition_types(weapon_def: WeaponDefinition) -> String:
	if weapon_def == null:
		return LocalizationManager.tr_key("ui.service.value.unknown", "Unknown")
	return WEAPON_DISPLAY_BUILDER.build_from_definition(weapon_def).taxonomy_text()

func _format_module_install_targets(module_instance: Module) -> String:
	var parts := PackedStringArray()
	for value in module_instance.get_normalized_required_weapon_traits():
		parts.append(_format_type_name(str(value)))
	for value in module_instance.get_normalized_required_delivery_types():
		parts.append(_format_type_name(str(value)))
	for value in module_instance.get_normalized_required_weapon_capabilities():
		parts.append(_format_type_name(str(value)))
	return " / ".join(parts) if not parts.is_empty() else LocalizationManager.tr_key("ui.service.value.any_weapon", "Any Weapon")

func _format_type_name(value: String) -> String:
	return LocalizationManager.get_module_term(StringName(value), value.replace("_", " ").capitalize())

func _get_weapon_upgrade_cost(weapon_def: WeaponDefinition) -> int:
	if weapon_def == null:
		return 0
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_weapon_upgrade_gold(int(weapon_def.price))
	return maxi(1, int(round(float(weapon_def.price) * 0.5)))

func _get_module_upgrade_cost(module_instance: Module) -> int:
	if module_instance == null:
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
	_add_detail_header(title)
	_add_detail_text(value)

func _add_detail_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.63, 0.86, 0.95))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_detail_body.add_child(label)

func _add_detail_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.92))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_detail_body.add_child(label)


func _add_collapsible_detail_section(title: String, lines: PackedStringArray, expanded: bool = false) -> void:
	if shop_detail_body == null or lines.is_empty():
		return
	var toggle := Button.new()
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.text = ("▼ " if expanded else "▶ ") + title
	toggle.add_theme_font_size_override("font_size", 15)
	toggle.add_theme_color_override("font_color", Color(0.63, 0.86, 0.95))
	shop_detail_body.add_child(toggle)
	var body := VBoxContainer.new()
	body.visible = expanded
	body.add_theme_constant_override("separation", 6)
	shop_detail_body.add_child(body)
	for line in lines:
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.92))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(label)
	toggle.pressed.connect(func() -> void:
		body.visible = not body.visible
		toggle.text = ("▼ " if body.visible else "▶ ") + title
	)

func _items_match(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	return str(a.get("type", "")) == str(b.get("type", "")) and str(a.get("id", "")) == str(b.get("id", ""))

func _show_message(text: String, duration: float) -> void:
	if owner_ui and owner_ui.has_method("show_item_message"):
		owner_ui.call("show_item_message", text, duration)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
