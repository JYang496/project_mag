extends Control
class_name PurchaseManagementView

@onready var shop_mode_buttons: HBoxContainer = $ShopModeButtons
@onready var shop_weapon_mode_button: Button = $ShopModeButtons/BuyWeaponModeButton
@onready var shop_module_mode_button: Button = $ShopModeButtons/BuyModuleModeButton
@onready var shop: VBoxContainer = $Shop
@onready var equipped_shop: GridContainer = $Equipped
@onready var shop_refresh_button: Button = $ShopRefreshButton
@onready var shop_sell_button: Button = $ShopSellButton
@onready var shop_cancel_button: Button = $ShopCancelButton
@onready var shop_confirm_button: Button = $ShopConfirmButton
@onready var shop_back_button: Button = $BackToPurchaseMenu
@onready var shop_detail_panel: PanelContainer = $ShopDetailPanel
@onready var shop_detail_title: Label = $ShopDetailPanel/Margin/Root/Title
@onready var shop_detail_subtitle: Label = $ShopDetailPanel/Margin/Root/Subtitle
@onready var shop_detail_scroll: ScrollContainer = $ShopDetailPanel/Margin/Root/DetailScroll
@onready var shop_detail_body: VBoxContainer = $ShopDetailPanel/Margin/Root/DetailScroll/DetailBody
@onready var shop_sell_summary_panel: PanelContainer = $ShopSellSummary
@onready var shop_sell_summary_title: Label = $ShopSellSummary/Margin/Content/Title
@onready var shop_sell_summary_hint: Label = $ShopSellSummary/Margin/Content/Hint
@onready var shop_sell_summary_list: VBoxContainer = $ShopSellSummary/Margin/Content/ListScroll/List
@onready var shop_sell_summary_modules: Label = $ShopSellSummary/Margin/Content/Modules
@onready var shop_sell_summary_total: Label = $ShopSellSummary/Margin/Content/Total

var owner_ui: Node
var controller: PurchaseManagementController
var weapon_shop: VBoxContainer
var module_shop: VBoxContainer
var purchase_action_button: Button
var sell_mode_active := false
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
	owner_ui.call("_style_management_button", shop_sell_button)
	owner_ui.call("_style_management_button", shop_cancel_button)
	owner_ui.call("_style_management_button", shop_confirm_button, true)
	owner_ui.call("_style_management_button", shop_back_button)

func set_shop_context(weapon_shop_list: VBoxContainer, action_button: Button) -> void:
	weapon_shop = weapon_shop_list
	purchase_action_button = action_button

func set_module_shop(module_shop_list: VBoxContainer) -> void:
	module_shop = module_shop_list

func set_sell_mode_active(enabled: bool) -> void:
	sell_mode_active = enabled
	if equipped_shop:
		equipped_shop.visible = enabled
	if enabled:
		hover_item = {}
		selected_item = {}
		clear_slot_selection()

func apply_purchase_mode(mode: StringName) -> void:
	purchase_mode = &"module" if mode == &"module" else &"weapon"
	var show_purchase := not sell_mode_active
	if equipped_shop:
		equipped_shop.visible = sell_mode_active
	if weapon_shop:
		weapon_shop.visible = show_purchase and purchase_mode == &"weapon"
	if module_shop:
		var module_scroll := module_shop.get_parent() as Control
		if module_scroll:
			module_scroll.visible = show_purchase and purchase_mode == &"module"
	shop_detail_panel.visible = show_purchase
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
	if sell_mode_active:
		return
	var selected_slot := selected_item.get("slot", null) as Node
	var has_selection := selected_slot != null and is_instance_valid(selected_slot)
	var can_buy := false
	if has_selection and selected_slot.has_method("can_purchase"):
		can_buy = bool(selected_slot.call("can_purchase"))
	purchase_action_button.disabled = not can_buy
	var selected_name := str(selected_item.get("name", ""))
	if selected_name == "":
		purchase_action_button.text = LocalizationManager.tr_key("ui.shop.buy.select", "购买")
	else:
		purchase_action_button.text = LocalizationManager.tr_format("ui.shop.buy.item", {"name": selected_name}, "购买")

func refresh_detail() -> void:
	if shop_detail_title == null or shop_detail_body == null:
		return
	var active := hover_item if not hover_item.is_empty() else selected_item
	if active.is_empty():
		clear_detail()
		return
	shop_detail_title.text = str(active.get("name", ""))
	shop_detail_title.add_theme_color_override("font_color", active.get("rarity_color", Color(0.86, 0.94, 1.0)))
	shop_detail_subtitle.text = str(active.get("description", ""))
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
	_add_detail_section("武器类型", _format_weapon_definition_types(weapon_def))
	_add_detail_section("购买价格", str(int(item_data.get("price", 0))))
	var level_rows := _build_weapon_level_rows(weapon_def)
	if not level_rows.is_empty():
		_add_detail_header("等级参数 / 升级价格")
		for row in level_rows:
			_add_detail_text(row)
	var branches := DataHandler.read_weapon_branch_options(str(weapon_def.scene_path), 999)
	if not branches.is_empty():
		_add_detail_header("分支选择")
		for branch_def in branches:
			var branch_name := LocalizationManager.get_branch_display_name(branch_def)
			var branch_desc := LocalizationManager.get_branch_description(branch_def)
			var unlock_text := "Fuse %d" % int(branch_def.unlock_fuse)
			_add_detail_text("%s  [%s]\n%s" % [branch_name, unlock_text, branch_desc])

func _fill_module_detail(item_data: Dictionary) -> void:
	var module_instance := item_data.get("module", null) as Module
	if module_instance == null or not is_instance_valid(module_instance):
		return
	_add_detail_section("可安装武器类型", _format_module_install_targets(module_instance))
	_add_detail_section("购买价格", str(int(item_data.get("price", 0))))
	_add_detail_header("等级参数 / 升级价格")
	var original_level := int(module_instance.module_level)
	for level in range(1, Module.MAX_LEVEL + 1):
		module_instance.set_module_level(level)
		var effects := module_instance.get_effect_descriptions()
		var upgrade_price := "-" if level >= Module.MAX_LEVEL else str(_get_module_upgrade_cost(module_instance))
		_add_detail_text("Lv.%d  升级: %s\n%s" % [level, upgrade_price, "\n".join(effects)])
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
		rows.append("Lv.%s  升级: %s\n%s" % [str(key), upgrade_price, _format_stat_dictionary(level_data)])
	weapon.queue_free()
	return rows

func _format_stat_dictionary(data: Dictionary) -> String:
	var parts := PackedStringArray()
	for key_variant in data.keys():
		var key := str(key_variant)
		parts.append("%s: %s" % [_format_stat_label(key), str(data[key_variant])])
	return " / ".join(parts)

func _format_stat_label(key: String) -> String:
	match key:
		"damage":
			return "伤害"
		"speed":
			return "速度"
		"projectile_hits":
			return "命中"
		"fire_interval_sec":
			return "间隔"
		"ammo":
			return "弹药"
		"bullet_count":
			return "弹数"
		"duration":
			return "持续"
		"hit_cd":
			return "命中间隔"
		"explosion_scale":
			return "爆炸"
		_:
			return key.replace("_", " ").capitalize()

func _format_weapon_definition_types(weapon_def: WeaponDefinition) -> String:
	if weapon_def == null or weapon_def.scene == null:
		return "未知"
	var weapon := weapon_def.scene.instantiate() as Weapon
	if weapon == null:
		return "未知"
	var parts := PackedStringArray()
	for value in weapon.get_explicit_weapon_traits():
		parts.append(_format_type_name(str(value)))
	for value in weapon.get_explicit_delivery_types():
		parts.append(_format_type_name(str(value)))
	for value in weapon.get_explicit_weapon_capabilities():
		parts.append(_format_type_name(str(value)))
	weapon.queue_free()
	return " / ".join(parts) if not parts.is_empty() else "通用"

func _format_module_install_targets(module_instance: Module) -> String:
	var parts := PackedStringArray()
	for value in module_instance.get_normalized_required_weapon_traits():
		parts.append(_format_type_name(str(value)))
	for value in module_instance.get_normalized_required_delivery_types():
		parts.append(_format_type_name(str(value)))
	for value in module_instance.get_normalized_required_weapon_capabilities():
		parts.append(_format_type_name(str(value)))
	return " / ".join(parts) if not parts.is_empty() else "任意武器"

func _format_type_name(value: String) -> String:
	match value:
		"physical":
			return "物理"
		"energy":
			return "能量"
		"fire":
			return "火焰"
		"freeze":
			return "冻结"
		"heat":
			return "热量"
		"charge":
			return "蓄能"
		"projectile":
			return "弹体"
		"melee_contact":
			return "近战"
		"beam":
			return "光束"
		"area":
			return "范围"
		"summon":
			return "召唤"
		"trap":
			return "陷阱"
		"support":
			return "支援"
		"movement":
			return "位移"
		_:
			return value.capitalize()

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
		return GlobalVariables.economy_data.get_module_upgrade_gold(int(module_instance.cost))
	return EconomyConfig.new().get_module_upgrade_gold(int(module_instance.cost))

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
