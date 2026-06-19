extends RefCounted
class_name PurchaseManagementController

const PURCHASE_MANAGEMENT_VIEW_PATH := "res://UI/scenes/management/purchase_management_view.tscn"
const MODULE_SHOP_LIST_VIEW_PATH := "res://UI/scenes/management/module_shop_list_view.tscn"
const SHOP_MODULE_SLOT_PATH := "res://UI/scenes/shop_module_slot.tscn"

var owner_ui: UI
var purchase_panel: Panel
var purchase_management_view
var module_shop_list_view
var shop: VBoxContainer
var equipped_shop: GridContainer
var shop_refresh_button: Button
var shop_sell_button: Button
var shop_cancel_button: Button
var shop_confirm_button: Button
var shop_back_button: Button
var shop_sell_summary_panel: PanelContainer
var shop_sell_summary_title: Label
var shop_sell_summary_hint: Label
var shop_sell_summary_list: VBoxContainer
var shop_sell_summary_total: Label
var shop_sell_summary_modules: Label
var module_shop: VBoxContainer
var shop_mode_buttons: HBoxContainer
var shop_weapon_mode_button: Button
var shop_module_mode_button: Button
var shop_detail_panel: PanelContainer
var shop_detail_title: Label
var shop_detail_subtitle: Label
var shop_detail_body: VBoxContainer
var shop_detail_scroll: ScrollContainer
var shop_sell_mode_active := false
var purchase_mode: StringName = &"weapon"
var hover_item: Dictionary = {}
var selected_item: Dictionary = {}

func bind(ui: UI, panel: Panel) -> void:
	owner_ui = ui
	purchase_panel = panel

func ensure_view() -> bool:
	if purchase_management_view != null and is_instance_valid(purchase_management_view):
		return true
	var view_scene := load(PURCHASE_MANAGEMENT_VIEW_PATH) as PackedScene
	purchase_management_view = view_scene.instantiate() as Control if view_scene else null
	if purchase_management_view == null:
		push_warning("Failed to create PurchaseManagementView.")
		return false
	purchase_panel.add_child(purchase_management_view)
	purchase_management_view.bind(owner_ui, self)
	_bind_view_fields()
	_sync_public_fields_to_owner()
	purchase_management_view.set_shop_context(shop, shop_sell_button)
	if owner_ui != null and shop_refresh_button != null:
		var reset_callable := Callable(shop_refresh_button, "_on_ui_reset_cost")
		if not owner_ui.reset_cost.is_connected(reset_callable):
			owner_ui.reset_cost.connect(reset_callable)
	return true

func init_sell_summary() -> void:
	if ensure_view():
		refresh_sell_summary()

func set_sell_mode(enabled: bool) -> void:
	if not ensure_view():
		return
	shop_sell_mode_active = enabled
	owner_ui.shop_sell_mode_active = enabled
	purchase_management_view.set_sell_mode_active(enabled)
	InventoryData.clear_on_select()
	for slot: EquipmentSlotShop in equipped_shop.get_children():
		slot.sell_mode = enabled
		slot.reset_sell_status()
	shop_sell_button.visible = not enabled
	if shop_confirm_button:
		shop_confirm_button.visible = enabled
	shop_cancel_button.visible = enabled
	if shop_back_button:
		shop_back_button.visible = not enabled
	if shop_refresh_button:
		shop_refresh_button.visible = not enabled
	shop.visible = not enabled
	if module_shop:
		var module_scroll := module_shop.get_parent() as Control
		if module_scroll:
			module_scroll.visible = not enabled
	if shop_mode_buttons:
		shop_mode_buttons.visible = not enabled
	if shop_detail_panel:
		shop_detail_panel.visible = not enabled
	if shop_sell_summary_panel:
		shop_sell_summary_panel.visible = enabled
	refresh_mode_title()
	refresh_sell_summary()
	if not enabled:
		apply_purchase_mode(purchase_mode)

func refresh_mode_title() -> void:
	var shop_title := purchase_panel.get_node_or_null("Title") as Label
	if shop_title:
		shop_title.text = LocalizationManager.tr_key(
			"ui.shop.sell.panel_title" if shop_sell_mode_active else "ui.panel.purchase",
			"Sell Weapons" if shop_sell_mode_active else "Purchase"
		)

func refresh_sell_summary() -> void:
	if shop_sell_summary_list == null:
		return
	for child in shop_sell_summary_list.get_children():
		shop_sell_summary_list.remove_child(child)
		child.queue_free()
	var total_gold := 0
	var module_count := 0
	var valid_count := 0
	for weapon_ref in InventoryData.ready_to_sell_list:
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon):
			continue
		valid_count += 1
		var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
		var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		var base_price := int(weapon_def.price) if weapon_def else 0
		var gold := GlobalVariables.economy_data.get_duplicate_weapon_gold(base_price) \
			if GlobalVariables.economy_data else EconomyConfig.new().get_duplicate_weapon_gold(base_price)
		var weapon_modules := weapon.get_module_count()
		total_gold += gold
		module_count += weapon_modules
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = LocalizationManager.tr_format(
			"ui.shop.sell.row",
			{
				"name": LocalizationManager.get_weapon_name_from_node(weapon),
				"level": int(weapon.level),
				"fuse": int(weapon.fuse),
				"gold": gold,
				"modules": weapon_modules,
			},
			"%s  Lv.%d  Fuse %d  |  +%d Gold  |  %d modules" % [
				LocalizationManager.get_weapon_name_from_node(weapon),
				int(weapon.level),
				int(weapon.fuse),
				gold,
				weapon_modules,
			]
		)
		shop_sell_summary_list.add_child(row)
	if valid_count == 0:
		var empty := Label.new()
		empty.text = LocalizationManager.tr_key(
			"ui.shop.sell.empty",
			"Click a weapon on the right to mark it for sale."
		)
		empty.modulate = Color(0.68, 0.72, 0.76)
		shop_sell_summary_list.add_child(empty)
	shop_sell_summary_modules.text = LocalizationManager.tr_format(
		"ui.shop.sell.modules",
		{"count": module_count},
		"Equipped modules moved to temporary storage: %d" % module_count
	)
	shop_sell_summary_total.text = LocalizationManager.tr_format(
		"ui.shop.sell.total",
		{"count": valid_count, "gold": total_gold},
		"Selected: %d    Total refund: +%d Gold" % [valid_count, total_gold]
	)
	if shop_confirm_button:
		shop_confirm_button.disabled = valid_count == 0

func refresh_items_for_prepare() -> void:
	if not ensure_view():
		return
	if shop_refresh_button != null and shop_refresh_button.has_method("refresh_shop_items"):
		shop_refresh_button.call("refresh_shop_items")
		return
	for slot in shop.get_children():
		var shop_slot := slot as ShopWeaponSlot
		if shop_slot == null:
			continue
		shop_slot.new_item()
		shop_slot.update()
	if module_shop:
		for slot in module_shop.get_children():
			if slot.has_method("new_item"):
				slot.call("new_item")
			if slot.has_method("update"):
				slot.call("update")

func update_shop() -> void:
	if not ensure_view():
		return
	for eq in equipped_shop.get_children():
		eq.update()
	for sh in shop.get_children():
		sh.update()
	if module_shop:
		for module_slot in module_shop.get_children():
			if module_slot.has_method("update"):
				module_slot.call("update")

func ensure_module_shop() -> bool:
	if module_shop != null:
		return true
	if not ensure_view():
		return false
	apply_shop_list_layout()
	equipped_shop.visible = false
	var view_scene := load(MODULE_SHOP_LIST_VIEW_PATH) as PackedScene
	module_shop_list_view = view_scene.instantiate() as ScrollContainer if view_scene else null
	if module_shop_list_view == null:
		push_warning("Failed to create ModuleShopListView.")
		return false
	purchase_management_view.add_child(module_shop_list_view)
	var module_slot_scene := load(SHOP_MODULE_SLOT_PATH) as PackedScene
	if module_slot_scene == null:
		push_warning("Failed to load ShopModuleSlot scene.")
		return false
	module_shop_list_view.populate_slots(module_slot_scene)
	module_shop = module_shop_list_view.module_shop
	purchase_management_view.set_module_shop(module_shop)
	_sync_public_fields_to_owner()
	return true

func apply_shop_list_layout() -> void:
	if shop == null:
		return
	shop.custom_minimum_size = Vector2(500, 405)
	shop.position = Vector2(25, 104)
	shop.size = Vector2(500, 419)
	shop.add_theme_constant_override("separation", 8)

func on_weapon_mode_pressed() -> void:
	apply_purchase_mode(&"weapon")

func on_module_mode_pressed() -> void:
	ensure_module_shop()
	apply_purchase_mode(&"module")

func mark_purchase_action_dirty() -> void:
	if owner_ui != null:
		owner_ui._mark_shop_purchase_action_dirty()

func apply_purchase_mode(mode: StringName) -> void:
	if not ensure_view():
		return
	purchase_mode = &"module" if mode == &"module" else &"weapon"
	apply_shop_list_layout()
	purchase_management_view.set_sell_mode_active(shop_sell_mode_active)
	purchase_management_view.set_shop_context(shop, shop_sell_button)
	if module_shop:
		purchase_management_view.set_module_shop(module_shop)
	purchase_management_view.apply_purchase_mode(purchase_mode)
	sync_view_state()
	_sync_public_fields_to_owner()

func set_hover_item(item_data: Dictionary) -> void:
	if ensure_view():
		purchase_management_view.set_hover_item(item_data)
		sync_view_state()

func clear_hover_item(item_data: Dictionary = {}) -> void:
	if ensure_view():
		purchase_management_view.clear_hover_item(item_data)
		sync_view_state()

func set_selected_item(item_data: Dictionary) -> void:
	if ensure_view():
		purchase_management_view.set_selected_item(item_data)
		sync_view_state()

func clear_selected_item(item_data: Dictionary = {}) -> void:
	if ensure_view():
		purchase_management_view.clear_selected_item(item_data)
		sync_view_state()

func purchase_selected_item() -> bool:
	if not ensure_view():
		return false
	var purchased := bool(purchase_management_view.purchase_selected_item())
	sync_view_state()
	return purchased

func apply_selection_highlight(item_data: Dictionary) -> void:
	if ensure_view():
		purchase_management_view.apply_selection_highlight(item_data)
		sync_view_state()

func clear_slot_selection() -> void:
	if ensure_view():
		purchase_management_view.clear_slot_selection()

func refresh_purchase_action() -> void:
	if purchase_management_view and is_instance_valid(purchase_management_view):
		purchase_management_view.refresh_purchase_action()
		sync_view_state()

func refresh_detail() -> void:
	if purchase_management_view and is_instance_valid(purchase_management_view):
		purchase_management_view.refresh_detail()
		sync_view_state()

func clear_detail() -> void:
	if purchase_management_view and is_instance_valid(purchase_management_view):
		purchase_management_view.clear_detail()

func refresh_texts() -> void:
	refresh_mode_title()
	if owner_ui.shop_instruction_label:
		owner_ui.shop_instruction_label.text = ""
		owner_ui.shop_instruction_label.visible = false
	if shop_weapon_mode_button:
		shop_weapon_mode_button.text = LocalizationManager.tr_key("ui.purchase.weapons", "购买武器")
	if shop_module_mode_button:
		shop_module_mode_button.text = LocalizationManager.tr_key("ui.purchase.modules", "购买模组")
	if shop_sell_button:
		shop_sell_button.text = LocalizationManager.tr_key("ui.shop.buy", "购买")
	if shop_cancel_button:
		shop_cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	if shop_sell_summary_title:
		shop_sell_summary_title.text = LocalizationManager.tr_key("ui.shop.sell.title", "Weapons Marked for Sale")
	if shop_sell_summary_hint:
		shop_sell_summary_hint.text = LocalizationManager.tr_key(
			"ui.shop.sell.hint",
			"Select weapons on the right. Confirming sells all marked weapons."
		)
	if equipped_shop:
		for slot: EquipmentSlotShop in equipped_shop.get_children():
			slot.refresh_sell_label_text()
	refresh_sell_summary()
	if shop_confirm_button:
		shop_confirm_button.text = LocalizationManager.tr_key("ui.panel.confirm", "Confirm")
	if shop_refresh_button:
		if shop_refresh_button.has_method("refresh_button_label"):
			shop_refresh_button.call("refresh_button_label")
		else:
			shop_refresh_button.text = LocalizationManager.tr_key("ui.panel.refresh", "Refresh")
	var merchant_subtitle := owner_ui.purchase_primary_panel.get_node_or_null("SubTitle") as Label
	if merchant_subtitle:
		merchant_subtitle.text = LocalizationManager.tr_key(
			"ui.merchant.purchase.subtitle",
			"选择购买类别"
		)
	var merchant_title := owner_ui.purchase_primary_panel.get_node_or_null("Title") as Label
	if merchant_title:
		merchant_title.text = LocalizationManager.tr_key("ui.merchant.purchase.title", "购买")
	var buy_button := owner_ui.purchase_primary_panel.get_node_or_null("OpenBuyButton") as Button
	if buy_button:
		buy_button.text = LocalizationManager.tr_key("ui.purchase.weapons", "购买武器")
	var warehouse_button := owner_ui.purchase_primary_panel.get_node_or_null("OpenSellButton") as Button
	if warehouse_button:
		warehouse_button.visible = true
		warehouse_button.text = LocalizationManager.tr_key("ui.purchase.modules", "购买模组")

	sync_primary_menu_style()

func sync_primary_menu_style() -> void:
	if owner_ui != null and owner_ui.has_method("_style_primary_menu_controls"):
		owner_ui.call("_style_primary_menu_controls")

func sync_view_state() -> void:
	if purchase_management_view == null or not is_instance_valid(purchase_management_view):
		return
	purchase_mode = purchase_management_view.get_purchase_mode()
	hover_item = purchase_management_view.get_hover_item()
	selected_item = purchase_management_view.get_selected_item()
	if owner_ui != null:
		owner_ui._shop_purchase_mode = purchase_mode
		owner_ui._shop_hover_item = hover_item
		owner_ui._shop_selected_item = selected_item

func _bind_view_fields() -> void:
	shop = purchase_management_view.shop
	equipped_shop = purchase_management_view.equipped_shop
	shop_refresh_button = purchase_management_view.shop_refresh_button
	shop_sell_button = purchase_management_view.shop_sell_button
	shop_cancel_button = purchase_management_view.shop_cancel_button
	shop_confirm_button = purchase_management_view.shop_confirm_button
	shop_back_button = purchase_management_view.shop_back_button
	shop_mode_buttons = purchase_management_view.shop_mode_buttons
	shop_weapon_mode_button = purchase_management_view.shop_weapon_mode_button
	shop_module_mode_button = purchase_management_view.shop_module_mode_button
	shop_detail_panel = purchase_management_view.shop_detail_panel
	shop_detail_title = purchase_management_view.shop_detail_title
	shop_detail_subtitle = purchase_management_view.shop_detail_subtitle
	shop_detail_scroll = purchase_management_view.shop_detail_scroll
	shop_detail_body = purchase_management_view.shop_detail_body
	shop_sell_summary_panel = purchase_management_view.shop_sell_summary_panel
	shop_sell_summary_title = purchase_management_view.shop_sell_summary_title
	shop_sell_summary_hint = purchase_management_view.shop_sell_summary_hint
	shop_sell_summary_list = purchase_management_view.shop_sell_summary_list
	shop_sell_summary_modules = purchase_management_view.shop_sell_summary_modules
	shop_sell_summary_total = purchase_management_view.shop_sell_summary_total

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui.purchase_management_view = purchase_management_view
	owner_ui.module_shop_list_view = module_shop_list_view
	owner_ui.shop = shop
	owner_ui.equipped_shop = equipped_shop
	owner_ui.shop_refresh_button = shop_refresh_button
	owner_ui.shop_sell_button = shop_sell_button
	owner_ui.shop_cancel_button = shop_cancel_button
	owner_ui.shop_confirm_button = shop_confirm_button
	owner_ui.shop_back_button = shop_back_button
	owner_ui.shop_sell_summary_panel = shop_sell_summary_panel
	owner_ui.shop_sell_summary_title = shop_sell_summary_title
	owner_ui.shop_sell_summary_hint = shop_sell_summary_hint
	owner_ui.shop_sell_summary_list = shop_sell_summary_list
	owner_ui.shop_sell_summary_modules = shop_sell_summary_modules
	owner_ui.shop_sell_summary_total = shop_sell_summary_total
	owner_ui.module_shop = module_shop
	owner_ui.shop_mode_buttons = shop_mode_buttons
	owner_ui.shop_weapon_mode_button = shop_weapon_mode_button
	owner_ui.shop_module_mode_button = shop_module_mode_button
	owner_ui.shop_detail_panel = shop_detail_panel
	owner_ui.shop_detail_title = shop_detail_title
	owner_ui.shop_detail_subtitle = shop_detail_subtitle
	owner_ui.shop_detail_scroll = shop_detail_scroll
	owner_ui.shop_detail_body = shop_detail_body

