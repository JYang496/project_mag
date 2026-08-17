extends RefCounted
class_name RestAreaUiController

const PRIMARY_MENU_ANIM_TIME := 0.2
const SERVICE_MENU_IDS: Array[StringName] = [&"purchase", &"upgrade", &"warehouse", &"board_edit", &"battle_start"]
const SECONDARY_SERVICE_MENU_IDS: Array[StringName] = [&"purchase", &"upgrade", &"warehouse"]
const SECONDARY_MENU_DIM_OVERLAY_NAME := "SecondaryMenuDimOverlay"
const SECONDARY_MENU_DIM_COLOR := Color(0.0, 0.0, 0.0, 0.42)
const INPUT_PROMPT_ATLAS := preload("res://asset/images/ui/input_prompts/kenney_pixel/input_prompts_tilemap.png")
const INPUT_PROMPT_TILE_SIZE := 16
const INPUT_PROMPT_TILE_STRIDE := 17
const SERVICE_NAV_ICON_SIZE := 24.0
const KEY_Q_PROMPT_COORD := Vector2i(17, 2)
const KEY_E_PROMPT_COORD := Vector2i(19, 2)

var owner_ui: UI
var shell: RestAreaManagementShell
var layout_controller: UiLayoutController
var active := false
var primary_menu_id: StringName = &""
var _secondary_menu_dim_overlay: ColorRect
var _menu_transition_locked := false
var _service_navigation_banner: PanelContainer
var _service_navigation_content: HBoxContainer

func bind(ui: UI, management_shell: RestAreaManagementShell, ui_layout_controller: UiLayoutController = null) -> void:
	owner_ui = ui
	shell = management_shell
	layout_controller = ui_layout_controller
	_sync_public_fields_to_owner()
	sync_secondary_menu_dim_overlay()
	_ensure_service_navigation_headers()

func set_layout_controller(ui_layout_controller: UiLayoutController) -> void:
	layout_controller = ui_layout_controller

func get_registered_service_menu_ids() -> Array[StringName]:
	return SERVICE_MENU_IDS.duplicate()

func get_service_primary_root(menu_id: StringName) -> Control:
	return _get_primary_root(menu_id)

func get_service_primary_panel(menu_id: StringName) -> Control:
	return _get_primary_panel(menu_id)

func get_service_primary_buttons(menu_id: StringName) -> Array:
	match _normalize_menu_id(menu_id):
		&"purchase":
			return [
				owner_ui.purchase_primary_panel.get_node_or_null("OpenBuyButton") as Button,
				owner_ui.purchase_primary_panel.get_node_or_null("OpenBuyModuleButton") as Button,
			]
		&"upgrade":
			return [
				owner_ui.upgrade_primary_panel.get_node_or_null("OpenUpgradeButton") as Button,
				owner_ui.upgrade_module_button,
			]
		&"warehouse":
			return [
				owner_ui.weapon_warehouse_button,
				owner_ui.warehouse_primary_panel.get_node_or_null("OpenModuleButton") as Button,
			]
		&"board_edit":
			return [
				owner_ui.board_edit_primary_panel.get_node_or_null("OpenGridManagementButton") as Button,
				owner_ui.board_edit_primary_panel.get_node_or_null("OpenTaskManagementButton") as Button,
			]
		&"battle_start":
			return [
				owner_ui.battle_start_primary_panel.get_node_or_null("StartBattleButton") as Button,
			]
	return []

func open_menu(menu_id: StringName) -> void:
	if _menu_transition_locked and active:
		return
	menu_id = _normalize_menu_id(menu_id)
	if menu_id == &"purchase" and not PhaseManager.is_full_shop_open():
		owner_ui.show_item_message(LocalizationManager.tr_key("ui.shop.closed_until_cycle", "Full shop opens after every third battle."), 1.8)
		return
	active = true
	primary_menu_id = menu_id
	_sync_public_fields_to_owner()
	PlayerData.is_interacting = true
	if not _open_primary_menu_by_id(menu_id):
		purchase_menu_in()
	_refresh_service_navigation_headers()

func switch_service(direction: int) -> bool:
	if PhaseManager.current_state() != PhaseManager.REST or not is_secondary_service_navigation_active() \
			or _menu_transition_locked:
		return false
	var reason := _get_service_switch_block_reason()
	if reason != "":
		owner_ui.show_item_message(reason, 1.8)
		return true
	var current_index := SECONDARY_SERVICE_MENU_IDS.find(_normalize_menu_id(primary_menu_id))
	if current_index < 0:
		return false
	var target_id := SECONDARY_SERVICE_MENU_IDS[posmod(
		current_index + signi(direction), SECONDARY_SERVICE_MENU_IDS.size()
	)]
	if target_id == &"purchase" and not PhaseManager.is_full_shop_open():
		owner_ui.show_item_message(LocalizationManager.tr_key("ui.shop.closed_until_cycle", "Full shop opens after every third battle."), 1.8)
		return true
	_menu_transition_locked = true
	_perform_secondary_service_switch.call_deferred(target_id)
	return true

func _perform_secondary_service_switch(target_id: StringName) -> void:
	var item_mode := _get_management_item_mode()
	for root in [owner_ui.purchase_management_root, owner_ui.upgrade_management_root, owner_ui.warehouse_management_root]:
		if root != null and is_instance_valid(root):
			root.visible = false
	if owner_ui.weapon_warehouse_panel and owner_ui.weapon_warehouse_panel.visible:
		owner_ui.weapon_warehouse_panel.close_panel()
	if owner_ui.module_equip_selection_panel and owner_ui.module_equip_selection_panel.visible:
		owner_ui.module_equip_selection_panel.close_without_assignment()
	active = true
	primary_menu_id = target_id
	PlayerData.is_interacting = true
	_sync_public_fields_to_owner()
	match target_id:
		&"purchase":
			owner_ui.ensure_purchase_management()
			owner_ui.purchase_management_controller.update_shop()
			if item_mode == &"module":
				owner_ui.purchase_management_controller.ensure_module_shop()
			owner_ui.purchase_management_controller.apply_purchase_mode(item_mode)
			owner_ui._mark_shop_purchase_action_dirty()
			owner_ui.purchase_management_root.visible = true
		&"upgrade":
			owner_ui.ensure_upgrade_management()
			owner_ui.upgrade_management_controller.apply_mode(item_mode)
			owner_ui.upgrade_management_controller.update_upg()
			owner_ui.upgrade_management_root.visible = true
		&"warehouse":
			owner_ui.ensure_warehouse_management()
			owner_ui.module_warehouse_controller.open_tab(item_mode)
			owner_ui.module_warehouse_controller.update_modules()
			owner_ui.warehouse_management_root.visible = true
	_sync_world_service_selection(target_id)
	sync_secondary_menu_dim_overlay()
	_menu_transition_locked = false
	_refresh_service_navigation_headers()

func _get_service_switch_block_reason() -> String:
	if owner_ui.is_branch_selection_blocking_interactions():
		return LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first.")
	if owner_ui.has_method("has_pending_blocking_transaction") and bool(owner_ui.call("has_pending_blocking_transaction")):
		return LocalizationManager.tr_key("ui.management.reason.pending_transaction", "Finish or cancel the current transaction first.")
	if not InventoryData.pending_transactions.is_empty():
		return LocalizationManager.tr_key("ui.management.reason.pending_transaction", "Finish or cancel the current transaction first.")
	if CellEffectRuntime.has_pending_edits():
		return LocalizationManager.tr_key("ui.management.reason.pending_edits", "Finish or cancel pending board edits first.")
	if owner_ui.is_world_interaction_blocked() and not is_primary_menu_open() and not is_secondary_menu_open():
		return LocalizationManager.tr_key("ui.management.reason.modal_open", "Close the current dialog first.")
	return ""

func _sync_world_service_selection(menu_id: StringName) -> void:
	var zone_by_menu := {&"purchase": 0, &"upgrade": 1, &"warehouse": 2, &"board_edit": 6, &"battle_start": 4}
	var rest_area := _find_active_rest_area()
	if rest_area != null and rest_area.has_method("sync_selected_service_zone"):
		rest_area.call("sync_selected_service_zone", int(zone_by_menu.get(menu_id, 4)))

func _ensure_service_navigation_headers() -> void:
	if _service_navigation_banner == null and owner_ui != null and owner_ui.gui_root != null:
		_service_navigation_banner = PanelContainer.new()
		_service_navigation_banner.name = "RestServiceNavigationBanner"
		_service_navigation_banner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_service_navigation_banner.offset_left = -370.0
		_service_navigation_banner.offset_top = 14.0
		_service_navigation_banner.offset_right = -18.0
		_service_navigation_banner.offset_bottom = 48.0
		_service_navigation_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_service_navigation_banner.z_index = 20
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.065, 0.085, 0.92)
		style.border_color = Color(0.20, 0.62, 0.78, 0.74)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 4.0
		style.content_margin_bottom = 4.0
		_service_navigation_banner.add_theme_stylebox_override("panel", style)
		_service_navigation_content = HBoxContainer.new()
		_service_navigation_content.name = "Content"
		_service_navigation_content.alignment = BoxContainer.ALIGNMENT_CENTER
		_service_navigation_content.add_theme_constant_override("separation", 5)
		_service_navigation_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_service_navigation_banner.add_child(_service_navigation_content)
		owner_ui.gui_root.add_child(_service_navigation_banner)
	_refresh_service_navigation_headers()

func _refresh_service_navigation_headers() -> void:
	if _service_navigation_banner == null:
		return
	var host := _get_secondary_navigation_host()
	var should_show := is_secondary_service_navigation_active() and host != null
	_service_navigation_banner.visible = should_show
	if not should_show:
		return
	if _service_navigation_banner.get_parent() != host:
		_service_navigation_banner.reparent(host)
	_service_navigation_banner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_service_navigation_banner.offset_left = -370.0
	_service_navigation_banner.offset_top = 14.0
	_service_navigation_banner.offset_right = -18.0
	_service_navigation_banner.offset_bottom = 48.0
	for child in _service_navigation_content.get_children():
		child.queue_free()
	_service_navigation_content.add_child(_make_navigation_key_icon(KEY_Q_PROMPT_COORD, "Q"))
	for index in range(SECONDARY_SERVICE_MENU_IDS.size()):
		var menu_id := SECONDARY_SERVICE_MENU_IDS[index]
		_service_navigation_content.add_child(_make_navigation_label(
			_service_display_name(menu_id),
			menu_id == _normalize_menu_id(primary_menu_id)
		))
		if index < SECONDARY_SERVICE_MENU_IDS.size() - 1:
			_service_navigation_content.add_child(_make_navigation_label("/", false))
	_service_navigation_content.add_child(_make_navigation_key_icon(KEY_E_PROMPT_COORD, "E"))

func is_secondary_service_navigation_active() -> bool:
	return active and is_secondary_menu_open() \
			and SECONDARY_SERVICE_MENU_IDS.has(_normalize_menu_id(primary_menu_id)) \
			and get_secondary_menu_context() == _normalize_menu_id(primary_menu_id)

func _get_secondary_navigation_host() -> Control:
	if not SECONDARY_SERVICE_MENU_IDS.has(_normalize_menu_id(primary_menu_id)):
		return null
	var root := _get_management_root(primary_menu_id)
	if root == null or not is_instance_valid(root) or not root.visible:
		return null
	return root.get_node_or_null("Panel") as Control

func _make_navigation_key_icon(coord: Vector2i, accessible_name: String) -> TextureRect:
	var texture := AtlasTexture.new()
	texture.atlas = INPUT_PROMPT_ATLAS
	texture.region = Rect2(
		coord.x * INPUT_PROMPT_TILE_STRIDE,
		coord.y * INPUT_PROMPT_TILE_STRIDE,
		INPUT_PROMPT_TILE_SIZE,
		INPUT_PROMPT_TILE_SIZE
	)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(SERVICE_NAV_ICON_SIZE, SERVICE_NAV_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = accessible_name
	return icon

func _make_navigation_label(value: String, current: bool) -> Label:
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30, 1.0) if current else Color(0.68, 0.88, 1.0, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _get_management_item_mode() -> StringName:
	if owner_ui != null and owner_ui.has_method("get_management_item_mode"):
		return owner_ui.call("get_management_item_mode") as StringName
	return &"weapon"

func _set_management_item_mode(mode: StringName) -> StringName:
	var normalized := &"module" if mode == &"module" else &"weapon"
	if owner_ui != null and owner_ui.has_method("set_management_item_mode"):
		owner_ui.call("set_management_item_mode", normalized)
	return normalized

func _service_display_name(menu_id: StringName) -> String:
	match menu_id:
		&"purchase": return LocalizationManager.tr_key("ui.rest.zone.purchase.title", "Purchase")
		&"upgrade": return LocalizationManager.tr_key("ui.rest.zone.combined_upgrade.title", "Upgrade")
		&"warehouse": return LocalizationManager.tr_key("ui.rest.zone.warehouses.title", "Warehouse")
		&"board_edit": return LocalizationManager.tr_key("ui.rest.zone.board.title", "Board")
		_: return LocalizationManager.tr_key("ui.rest.zone.battle.title", "Protocol")

func open_board_edit_panel() -> bool:
	if _menu_transition_locked and active:
		return false
	active = true
	primary_menu_id = &"board_edit"
	_sync_public_fields_to_owner()
	PlayerData.is_interacting = true
	if not _open_primary_menu_by_id(&"board_edit"):
		_clear_active()
		return false
	return true

func _close_all_rest_area_panels() -> void:
	if owner_ui.weapon_warehouse_panel:
		owner_ui.weapon_warehouse_panel.close_panel()
	if owner_ui.module_equip_selection_panel and owner_ui.module_equip_selection_panel.visible:
		owner_ui.module_equip_selection_panel.close_without_assignment()
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel):
		owner_ui.cell_management_panel.call("close_panel")
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel):
		owner_ui.board_edit_panel.call("close_panel")
	for menu_id in SERVICE_MENU_IDS:
		var root := _get_primary_root(menu_id)
		if root:
			root.visible = false
	for root in [owner_ui.purchase_management_root, owner_ui.upgrade_management_root, owner_ui.warehouse_management_root]:
		if root:
			root.visible = false
	InventoryData.clear_on_select()
	sync_secondary_menu_dim_overlay()

func purchase_panel_in() -> void:
	if owner_ui.purchase_management_root == null:
		return
	if owner_ui.is_branch_selection_blocking_interactions():
		owner_ui.show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return
	owner_ui.purchase_management_controller.update_shop()
	owner_ui._mark_shop_purchase_action_dirty()
	if not _menu_transition_locked:
		set_primary_root_visible(&"purchase", false)
	set_management_root_visible(&"purchase", true)

func purchase_panel_out() -> void:
	set_management_root_visible(&"purchase", false)
	owner_ui._mark_shop_purchase_action_dirty()
	InventoryData.clear_on_select()
	owner_ui.refresh_border()

func purchase_menu_in() -> void:
	_open_primary_menu_by_id(&"purchase")

func purchase_menu_out() -> void:
	_hide_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)
	if owner_ui.weapon_warehouse_panel:
		owner_ui.weapon_warehouse_panel.close_panel()
	purchase_panel_out()
	active = false
	if primary_menu_id == &"purchase":
		primary_menu_id = &""
	_sync_public_fields_to_owner()

func warehouse_back_to_purchase() -> void:
	if owner_ui.weapon_warehouse_panel:
		owner_ui.weapon_warehouse_panel.close_panel()
	warehouse_panel_out()
	purchase_panel_out()
	if primary_menu_id == &"warehouse":
		_show_primary_menu(&"warehouse", owner_ui.warehouse_primary_root, owner_ui.warehouse_primary_panel)
	else:
		_show_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)

func reset_purchase_refresh_cost() -> void:
	owner_ui.reset_cost.emit()
	refresh_shop_items_for_prepare()

func refresh_shop_items_for_prepare() -> void:
	if owner_ui.management_shell_view == null or owner_ui.purchase_panel == null:
		owner_ui._purchase_prepare_refresh_pending = true
		owner_ui._mark_shop_purchase_action_dirty()
		return
	owner_ui._init_purchase_management_controller()
	owner_ui.purchase_management_controller.refresh_items_for_prepare()
	owner_ui._mark_shop_purchase_action_dirty()

func upgrade_panel_in() -> void:
	if owner_ui.is_branch_selection_blocking_interactions():
		owner_ui.show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return
	owner_ui.upgrade_management_controller.apply_mode(_get_management_item_mode())
	owner_ui.upgrade_management_controller.update_upg()
	if not _menu_transition_locked:
		set_primary_root_visible(&"upgrade", false)
	set_management_root_visible(&"upgrade", true)

func upgrade_panel_out() -> void:
	set_management_root_visible(&"upgrade", false)
	InventoryData.clear_on_select()
	owner_ui._upgrade_hover_item = {}
	owner_ui._upgrade_selected_item = {}
	owner_ui.refresh_border()

func upgrade_menu_in() -> void:
	_open_primary_menu_by_id(&"upgrade")

func upgrade_menu_out() -> void:
	_hide_primary_menu(&"upgrade", owner_ui.upgrade_primary_root, owner_ui.upgrade_primary_panel)
	upgrade_panel_out()

func warehouse_menu_in() -> void:
	_open_primary_menu_by_id(&"warehouse")

func warehouse_menu_out() -> void:
	_hide_primary_menu(&"warehouse", owner_ui.warehouse_primary_root, owner_ui.warehouse_primary_panel)
	warehouse_panel_out()
	if owner_ui.module_equip_selection_panel and owner_ui.module_equip_selection_panel.visible:
		owner_ui.module_equip_selection_panel.close_without_assignment()
	InventoryData.clear_on_select()

func warehouse_panel_in(tab: StringName = &"") -> void:
	if not is_module_management_available():
		owner_ui._show_module_rest_area_only_message()
		return
	owner_ui.module_warehouse_controller.open_tab(tab if tab != &"" else _get_management_item_mode())
	owner_ui.module_warehouse_controller.update_modules()
	set_management_root_visible(&"warehouse", true)

func warehouse_panel_out() -> void:
	set_management_root_visible(&"warehouse", false)

func close_module_management_ui() -> void:
	if owner_ui.module_equip_selection_panel and owner_ui.module_equip_selection_panel.visible:
		owner_ui.module_equip_selection_panel.close_without_assignment()
	set_management_root_visible(&"warehouse", false)
	set_primary_root_visible(&"warehouse", false)
	InventoryData.clear_on_select()
	if primary_menu_id == &"warehouse":
		_stop_primary_menu_tween(&"warehouse")
		active = false
		primary_menu_id = &""
		PlayerData.is_interacting = false
	_sync_public_fields_to_owner()

func open_purchase_weapon_panel() -> void:
	if not PhaseManager.is_full_shop_open():
		owner_ui.show_item_message(LocalizationManager.tr_key("ui.shop.closed_until_cycle", "Full shop opens after every third battle."), 1.8)
		return
	var item_mode := _set_management_item_mode(&"weapon")
	owner_ui.ensure_purchase_management()
	if _menu_transition_locked or owner_ui.is_branch_selection_blocking_interactions():
		if owner_ui.is_branch_selection_blocking_interactions():
			owner_ui.show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return
	_menu_transition_locked = true
	_hide_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)
	purchase_panel_in()
	owner_ui.purchase_management_controller.apply_purchase_mode(item_mode)
	await _animate_secondary_root_in(owner_ui.purchase_management_root)
	_menu_transition_locked = false

func open_purchase_module_panel() -> void:
	if not PhaseManager.is_full_shop_open():
		owner_ui.show_item_message(LocalizationManager.tr_key("ui.shop.closed_until_cycle", "Full shop opens after every third battle."), 1.8)
		return
	var item_mode := _set_management_item_mode(&"module")
	owner_ui.ensure_purchase_management()
	if _menu_transition_locked or owner_ui.is_branch_selection_blocking_interactions():
		if owner_ui.is_branch_selection_blocking_interactions():
			owner_ui.show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return
	_menu_transition_locked = true
	_hide_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)
	owner_ui.purchase_management_controller.ensure_module_shop()
	purchase_panel_in()
	owner_ui.purchase_management_controller.apply_purchase_mode(item_mode)
	await _animate_secondary_root_in(owner_ui.purchase_management_root)
	_menu_transition_locked = false

func close_purchase_panel() -> void:
	purchase_panel_out()

func back_to_purchase_primary_menu() -> void:
	if _menu_transition_locked:
		return
	_menu_transition_locked = true
	var tween := _animate_secondary_root_out(owner_ui.purchase_management_root)
	_show_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)
	if tween != null:
		await tween.finished
	purchase_panel_out()
	_menu_transition_locked = false

func open_upgrade_panel(mode: StringName = &"weapon") -> void:
	mode = _set_management_item_mode(mode)
	owner_ui.ensure_upgrade_management()
	if _menu_transition_locked or owner_ui.is_branch_selection_blocking_interactions():
		if owner_ui.is_branch_selection_blocking_interactions():
			owner_ui.show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return
	_menu_transition_locked = true
	_hide_primary_menu(&"upgrade", owner_ui.upgrade_primary_root, owner_ui.upgrade_primary_panel)
	owner_ui.upgrade_management_controller.apply_mode(mode)
	upgrade_panel_in()
	await _animate_secondary_root_in(owner_ui.upgrade_management_root)
	_menu_transition_locked = false

func close_upgrade_panel() -> void:
	upgrade_panel_out()

func back_to_upgrade_primary_menu() -> void:
	if _menu_transition_locked:
		return
	_menu_transition_locked = true
	var tween := _animate_secondary_root_out(owner_ui.upgrade_management_root)
	_show_primary_menu(&"upgrade", owner_ui.upgrade_primary_root, owner_ui.upgrade_primary_panel)
	if tween != null:
		await tween.finished
	upgrade_panel_out()
	_menu_transition_locked = false

func open_warehouse_management_panel() -> void:
	_set_management_item_mode(&"module")
	owner_ui.ensure_warehouse_management()
	if _menu_transition_locked:
		return
	if not is_module_management_available():
		owner_ui._show_module_rest_area_only_message()
		return
	_menu_transition_locked = true
	_hide_primary_menu(&"warehouse", owner_ui.warehouse_primary_root, owner_ui.warehouse_primary_panel)
	warehouse_panel_in(&"module")
	await _animate_secondary_root_in(owner_ui.warehouse_management_root)
	_menu_transition_locked = false

func open_warehouse_weapon_panel() -> void:
	_set_management_item_mode(&"weapon")
	owner_ui.ensure_warehouse_management()
	if _menu_transition_locked:
		return
	if not is_module_management_available():
		owner_ui._show_module_rest_area_only_message()
		return
	_menu_transition_locked = true
	_hide_primary_menu(&"warehouse", owner_ui.warehouse_primary_root, owner_ui.warehouse_primary_panel)
	warehouse_panel_in(&"weapon")
	await _animate_secondary_root_in(owner_ui.warehouse_management_root)
	_menu_transition_locked = false

func close_warehouse_panel() -> void:
	warehouse_panel_out()

func back_to_warehouse_primary_menu() -> void:
	if _menu_transition_locked:
		return
	_menu_transition_locked = true
	if owner_ui.module_equip_selection_panel and owner_ui.module_equip_selection_panel.visible:
		owner_ui.module_equip_selection_panel.close_without_assignment()
	var tween := _animate_secondary_root_out(owner_ui.warehouse_management_root)
	_show_primary_menu(&"warehouse", owner_ui.warehouse_primary_root, owner_ui.warehouse_primary_panel)
	if tween != null:
		await tween.finished
	warehouse_panel_out()
	_menu_transition_locked = false

func open_cell_grid_panel() -> void:
	if _menu_transition_locked:
		return
	_menu_transition_locked = true
	_hide_primary_menu(&"board_edit", owner_ui.board_edit_primary_root, owner_ui.board_edit_primary_panel)
	if not owner_ui.open_board_edit_panel():
		_show_primary_menu(&"board_edit", owner_ui.board_edit_primary_root, owner_ui.board_edit_primary_panel)
		_menu_transition_locked = false
		return
	await _animate_secondary_root_in(owner_ui.board_edit_panel)
	sync_secondary_menu_dim_overlay()
	_menu_transition_locked = false

func open_cell_task_panel() -> void:
	if _menu_transition_locked:
		return
	_menu_transition_locked = true
	_hide_primary_menu(&"board_edit", owner_ui.board_edit_primary_root, owner_ui.board_edit_primary_panel)
	if not owner_ui.open_cell_management_panel(&"task"):
		_show_primary_menu(&"board_edit", owner_ui.board_edit_primary_root, owner_ui.board_edit_primary_panel)
		_menu_transition_locked = false
		return
	await _animate_secondary_root_in(owner_ui.cell_management_panel)
	sync_secondary_menu_dim_overlay()
	_menu_transition_locked = false

func back_to_board_primary_menu() -> void:
	if _menu_transition_locked:
		return
	_menu_transition_locked = true
	var visible_panel := _get_visible_board_secondary_panel()
	var tween := _animate_secondary_root_out(visible_panel)
	_show_primary_menu(&"board_edit", owner_ui.board_edit_primary_root, owner_ui.board_edit_primary_panel)
	if tween != null:
		await tween.finished
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel):
		owner_ui.cell_management_panel.call("close_panel")
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel):
		owner_ui.board_edit_panel.call("close_panel")
	sync_secondary_menu_dim_overlay()
	_menu_transition_locked = false

func start_battle_from_primary_menu() -> void:
	if _menu_transition_locked:
		return
	var root := owner_ui.battle_start_primary_root
	if root:
		root.visible = false
	_clear_active()
	var rest_area := _find_active_rest_area()
	if rest_area != null and rest_area.has_method("_on_start_battle_button_activated"):
		rest_area.call("_on_start_battle_button_activated")

func close_purchase_menu() -> void:
	if not active:
		return
	purchase_menu_out()
	_clear_active()

func close_primary_menu() -> void:
	if _menu_transition_locked or not active:
		return
	_menu_transition_locked = true
	var primary_close_started := false
	var closing_menu_id := primary_menu_id
	_clear_active()
	match closing_menu_id:
		&"board_edit":
			var board_tween := _animate_secondary_root_out(_get_visible_board_secondary_panel())
			if board_tween != null:
				await board_tween.finished
			else:
				_hide_primary_menu(&"board_edit", owner_ui.board_edit_primary_root, owner_ui.board_edit_primary_panel)
				primary_close_started = true
			if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel):
				owner_ui.cell_management_panel.call("close_panel")
			if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel):
				owner_ui.board_edit_panel.call("close_panel")
		&"upgrade":
			if owner_ui.upgrade_management_root and owner_ui.upgrade_management_root.visible:
				var upgrade_tween := _animate_secondary_root_out(owner_ui.upgrade_management_root)
				if upgrade_tween != null:
					await upgrade_tween.finished
				upgrade_panel_out()
			else:
				upgrade_menu_out()
				primary_close_started = true
		&"warehouse":
			if owner_ui.warehouse_management_root and owner_ui.warehouse_management_root.visible:
				var warehouse_tween := _animate_secondary_root_out(owner_ui.warehouse_management_root)
				if warehouse_tween != null:
					await warehouse_tween.finished
				warehouse_panel_out()
			else:
				warehouse_menu_out()
				primary_close_started = true
		&"battle_start":
			_hide_primary_menu(&"battle_start", owner_ui.battle_start_primary_root, owner_ui.battle_start_primary_panel)
			primary_close_started = true
		_:
			if owner_ui.purchase_management_root and owner_ui.purchase_management_root.visible:
				var purchase_tween := _animate_secondary_root_out(owner_ui.purchase_management_root)
				if purchase_tween != null:
					await purchase_tween.finished
				purchase_panel_out()
			else:
				purchase_menu_out()
				primary_close_started = true
	if primary_close_started:
		await owner_ui.get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	_menu_transition_locked = false

func is_purchase_active() -> bool:
	_sync_public_fields_to_owner()
	return active

func set_management_root_visible(root_id: StringName, visible: bool) -> void:
	var root := _get_management_root(root_id)
	if root:
		root.visible = visible
	sync_secondary_menu_dim_overlay()
	_refresh_service_navigation_headers()

func sync_secondary_menu_dim_overlay() -> void:
	if owner_ui == null:
		return
	var overlay := _ensure_secondary_menu_dim_overlay()
	if overlay == null:
		return
	overlay.visible = is_secondary_menu_open()
	if overlay.visible:
		_send_secondary_menu_dim_overlay_to_back()

func set_primary_root_visible(root_id: StringName, visible: bool) -> void:
	var root := _get_primary_root(root_id)
	if root:
		root.visible = visible
	_refresh_service_navigation_headers()

func is_menu_visible() -> bool:
	var visible := false
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
		visible = true
		_sync_public_fields_to_owner()
		return visible
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
		visible = true
		_sync_public_fields_to_owner()
		return visible
	visible = _has_open_rest_area_menu()
	if not visible and active:
		_clear_active()
		return false
	_sync_public_fields_to_owner()
	return visible

func is_zone_navigation_allowed() -> bool:
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
		_sync_public_fields_to_owner()
		return false
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
		_sync_public_fields_to_owner()
		return false
	var allowed := _is_zone_navigation_allowed_without_shell()
	_sync_public_fields_to_owner()
	return allowed

func is_module_management_available() -> bool:
	if owner_ui == null:
		return false
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return false
	for node in owner_ui.get_tree().get_nodes_in_group("rest_area"):
		if node and is_instance_valid(node) and node.has_method("is_module_management_available"):
			if bool(node.call("is_module_management_available")):
				return true
	return false

func handle_right_cancel() -> bool:
	if _menu_transition_locked:
		return true
	if primary_menu_id == &"board_edit" and owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
		if owner_ui.board_edit_panel.has_method("clear_selection_if_any") and bool(owner_ui.board_edit_panel.call("clear_selection_if_any")):
			return true
		return owner_ui.request_close_board_edit_panel(true)
	if primary_menu_id == &"board_edit" and owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
		if owner_ui.cell_management_panel.has_method("cancel_menu_level") and bool(owner_ui.cell_management_panel.call("cancel_menu_level")):
			return true
		return owner_ui.request_close_cell_management_panel()
	if owner_ui._cancel_top_level_non_battle_ui():
		_sync_public_fields_to_owner()
		return true
	if not active:
		return false
	return cancel_menu_level()

func cancel_menu_level() -> bool:
	if primary_menu_id == &"purchase":
		if owner_ui.weapon_warehouse_panel and owner_ui.weapon_warehouse_panel.visible:
			owner_ui.weapon_warehouse_panel.close_panel()
			_show_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)
			return true
		if owner_ui.purchase_management_root and owner_ui.purchase_management_root.visible:
			back_to_purchase_primary_menu()
			return true
		if owner_ui.purchase_primary_root and owner_ui.purchase_primary_root.visible:
			close_primary_menu()
			return true
	elif primary_menu_id == &"upgrade":
		if owner_ui.upgrade_management_root and owner_ui.upgrade_management_root.visible:
			back_to_upgrade_primary_menu()
			return true
		if owner_ui.upgrade_primary_root and owner_ui.upgrade_primary_root.visible:
			close_primary_menu()
			return true
	elif primary_menu_id == &"warehouse":
		if owner_ui.weapon_warehouse_panel and owner_ui.weapon_warehouse_panel.visible:
			owner_ui.weapon_warehouse_panel.close_panel()
			_show_primary_menu(&"warehouse", owner_ui.warehouse_primary_root, owner_ui.warehouse_primary_panel)
			return true
		if owner_ui.module_equip_selection_panel and owner_ui.module_equip_selection_panel.visible:
			owner_ui.module_equip_selection_panel.close_without_assignment()
			return true
		if owner_ui.warehouse_management_root and owner_ui.warehouse_management_root.visible:
			back_to_warehouse_primary_menu()
			return true
		if owner_ui.warehouse_primary_root and owner_ui.warehouse_primary_root.visible:
			close_primary_menu()
			return true
	elif primary_menu_id == &"board_edit":
		if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
			if owner_ui.board_edit_panel.has_method("clear_selection_if_any") and bool(owner_ui.board_edit_panel.call("clear_selection_if_any")):
				return true
			back_to_board_primary_menu()
			return true
		if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
			if owner_ui.cell_management_panel.has_method("cancel_menu_level") and bool(owner_ui.cell_management_panel.call("cancel_menu_level")):
				return true
			return owner_ui.request_close_cell_management_panel()
		if owner_ui.board_edit_primary_root and owner_ui.board_edit_primary_root.visible:
			close_primary_menu()
			return true
		_clear_active()
		return true
	elif primary_menu_id == &"battle_start":
		if owner_ui.battle_start_primary_root and owner_ui.battle_start_primary_root.visible:
			close_primary_menu()
			return true
	return false

func is_primary_menu_open() -> bool:
	for menu_id in SERVICE_MENU_IDS:
		var root := _get_primary_root(menu_id)
		if root and is_instance_valid(root) and root.visible:
			return true
	return false

func is_secondary_menu_open() -> bool:
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
		return true
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
		return true
	if owner_ui.weapon_warehouse_panel and is_instance_valid(owner_ui.weapon_warehouse_panel) and owner_ui.weapon_warehouse_panel.visible:
		return true
	for root in [owner_ui.purchase_management_root, owner_ui.upgrade_management_root, owner_ui.warehouse_management_root]:
		if root and is_instance_valid(root) and root.visible:
			return true
	return false

func get_secondary_menu_context() -> StringName:
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
		return &"grid_management"
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
		return &"task_management"
	if owner_ui.weapon_warehouse_panel and is_instance_valid(owner_ui.weapon_warehouse_panel) and owner_ui.weapon_warehouse_panel.visible:
		return &"warehouse"
	if owner_ui.purchase_management_root and is_instance_valid(owner_ui.purchase_management_root) and owner_ui.purchase_management_root.visible:
		return &"purchase"
	if owner_ui.upgrade_management_root and is_instance_valid(owner_ui.upgrade_management_root) and owner_ui.upgrade_management_root.visible:
		return &"upgrade"
	if owner_ui.warehouse_management_root and is_instance_valid(owner_ui.warehouse_management_root) and owner_ui.warehouse_management_root.visible:
		return &"warehouse"
	if owner_ui.module_equip_selection_panel and is_instance_valid(owner_ui.module_equip_selection_panel) and owner_ui.module_equip_selection_panel.visible:
		return &"warehouse"
	return &""

func is_world_interaction_blocking_panel_visible() -> bool:
	return is_secondary_menu_open()

func get_secondary_menu_dim_overlay() -> ColorRect:
	return _ensure_secondary_menu_dim_overlay()

func _show_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	_ensure_layout_controller()
	if layout_controller != null:
		layout_controller.show_primary_menu(menu_id, root, panel)

func _open_primary_menu_by_id(menu_id: StringName) -> bool:
	if PhaseManager.current_state() != PhaseManager.REST:
		return false
	if owner_ui != null and owner_ui.is_world_interaction_blocked():
		return false
	menu_id = _normalize_menu_id(menu_id)
	var root := _get_primary_root(menu_id)
	var panel := _get_primary_panel(menu_id)
	if root == null or panel == null:
		return false
	_prepare_primary_menu_open(menu_id)
	_show_primary_menu(menu_id, root, panel)
	return true

func _hide_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	_ensure_layout_controller()
	if layout_controller != null:
		layout_controller.hide_primary_menu(menu_id, root, panel)

func _animate_secondary_root_in(root: Control) -> void:
	_ensure_layout_controller()
	if root == null:
		return
	if layout_controller == null:
		root.visible = true
		return
	var tween := layout_controller.show_secondary_menu(root)
	if tween != null:
		await tween.finished

func _animate_secondary_root_out(root: Control) -> Tween:
	_ensure_layout_controller()
	if root == null:
		return null
	if layout_controller == null:
		root.visible = false
		return null
	return layout_controller.hide_secondary_menu(root)

func _get_visible_board_secondary_panel() -> Control:
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
		return owner_ui.board_edit_panel
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
		return owner_ui.cell_management_panel
	return null

func _stop_primary_menu_tween(menu_id: StringName) -> void:
	_ensure_layout_controller()
	if layout_controller != null:
		layout_controller.stop_primary_menu_tween(menu_id)

func _ensure_layout_controller() -> void:
	if layout_controller != null or owner_ui == null:
		return
	owner_ui._init_ui_layout_controller()
	layout_controller = owner_ui.ui_layout_controller

func _ensure_secondary_menu_dim_overlay() -> ColorRect:
	if _secondary_menu_dim_overlay != null and is_instance_valid(_secondary_menu_dim_overlay):
		return _secondary_menu_dim_overlay
	if owner_ui == null or owner_ui.gui_root == null:
		return null
	var existing := owner_ui.gui_root.get_node_or_null(SECONDARY_MENU_DIM_OVERLAY_NAME) as ColorRect
	if existing != null:
		_secondary_menu_dim_overlay = existing
	else:
		_secondary_menu_dim_overlay = ColorRect.new()
		_secondary_menu_dim_overlay.name = SECONDARY_MENU_DIM_OVERLAY_NAME
		_secondary_menu_dim_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_secondary_menu_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_secondary_menu_dim_overlay.z_index = -50
		owner_ui.gui_root.add_child(_secondary_menu_dim_overlay)
	_secondary_menu_dim_overlay.color = SECONDARY_MENU_DIM_COLOR
	_secondary_menu_dim_overlay.visible = false
	_send_secondary_menu_dim_overlay_to_back()
	return _secondary_menu_dim_overlay

func _send_secondary_menu_dim_overlay_to_back() -> void:
	if _secondary_menu_dim_overlay == null or not is_instance_valid(_secondary_menu_dim_overlay):
		return
	if _secondary_menu_dim_overlay.get_parent() == owner_ui.gui_root:
		owner_ui.gui_root.move_child(_secondary_menu_dim_overlay, 0)

func _clear_active() -> void:
	PlayerData.is_interacting = false
	active = false
	primary_menu_id = &""
	_sync_public_fields_to_owner()
	_refresh_service_navigation_headers()

func _has_open_rest_area_menu() -> bool:
	if not active:
		return false
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
		return true
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
		return true
	if is_primary_menu_open() or is_secondary_menu_open():
		return true
	if owner_ui.weapon_warehouse_panel and is_instance_valid(owner_ui.weapon_warehouse_panel) and owner_ui.weapon_warehouse_panel.visible:
		return true
	if owner_ui.module_equip_selection_panel and is_instance_valid(owner_ui.module_equip_selection_panel) and owner_ui.module_equip_selection_panel.visible:
		return true
	return false

func _is_zone_navigation_allowed_without_shell() -> bool:
	if TaskRewardManager.is_reward_blocking_interactions():
		return false
	if not active:
		return true
	if primary_menu_id == &"purchase" and owner_ui.purchase_primary_root and owner_ui.purchase_primary_root.visible:
		return true
	if primary_menu_id == &"upgrade" and owner_ui.upgrade_primary_root and owner_ui.upgrade_primary_root.visible:
		return true
	if primary_menu_id == &"warehouse" and owner_ui.warehouse_primary_root and owner_ui.warehouse_primary_root.visible:
		return true
	if primary_menu_id == &"board_edit" and owner_ui.board_edit_primary_root and owner_ui.board_edit_primary_root.visible:
		return true
	if primary_menu_id == &"battle_start" and owner_ui.battle_start_primary_root and owner_ui.battle_start_primary_root.visible:
		return true
	return false

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui._rest_area_menu_active = active
	owner_ui._rest_area_primary_menu_id = primary_menu_id

func _normalize_menu_id(menu_id: StringName) -> StringName:
	match menu_id:
		&"merchant":
			return &"purchase"
		&"smith":
			return &"upgrade"
		&"module":
			return &"warehouse"
		&"board":
			return &"board_edit"
		&"battle":
			return &"battle_start"
		_:
			return menu_id

func _get_management_root(root_id: StringName) -> Control:
	match _normalize_menu_id(root_id):
		&"purchase":
			return owner_ui.purchase_management_root
		&"upgrade":
			return owner_ui.upgrade_management_root
		&"warehouse":
			return owner_ui.warehouse_management_root
		&"board_edit":
			return null
		&"battle_start":
			return null
		_:
			return null

func _get_primary_root(root_id: StringName) -> Control:
	match _normalize_menu_id(root_id):
		&"purchase":
			return owner_ui.purchase_primary_root
		&"upgrade":
			return owner_ui.upgrade_primary_root
		&"warehouse":
			return owner_ui.warehouse_primary_root
		&"board_edit":
			return owner_ui.board_edit_primary_root
		&"battle_start":
			return owner_ui.battle_start_primary_root
		_:
			return null

func _get_primary_panel(root_id: StringName) -> Control:
	match _normalize_menu_id(root_id):
		&"purchase":
			return owner_ui.purchase_primary_panel
		&"upgrade":
			return owner_ui.upgrade_primary_panel
		&"warehouse":
			return owner_ui.warehouse_primary_panel
		&"board_edit":
			return owner_ui.board_edit_primary_panel
		&"battle_start":
			return owner_ui.battle_start_primary_panel
		_:
			return null

func _prepare_primary_menu_open(menu_id: StringName) -> void:
	_close_all_rest_area_panels()
	match _normalize_menu_id(menu_id):
		&"purchase":
			purchase_panel_out()
		&"upgrade":
			upgrade_panel_out()
		&"warehouse":
			warehouse_panel_out()

func _find_active_rest_area() -> Node:
	if owner_ui == null:
		return null
	for node in owner_ui.get_tree().get_nodes_in_group("rest_area"):
		if node and is_instance_valid(node) and node.has_method("is_active") and bool(node.call("is_active")):
			return node
	return null
