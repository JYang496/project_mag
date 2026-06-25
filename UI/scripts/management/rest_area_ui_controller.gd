extends RefCounted
class_name RestAreaUiController

const PRIMARY_MENU_ANIM_TIME := 0.2
const SERVICE_MENU_IDS: Array[StringName] = [&"purchase", &"upgrade", &"warehouse", &"board_edit"]

var owner_ui: UI
var shell: RestAreaManagementShell
var layout_controller: UiLayoutController
var active := false
var primary_menu_id: StringName = &""

func bind(ui: UI, management_shell: RestAreaManagementShell, ui_layout_controller: UiLayoutController = null) -> void:
	owner_ui = ui
	shell = management_shell
	layout_controller = ui_layout_controller
	sync_state_from_owner()

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
				owner_ui.purchase_primary_panel.get_node_or_null("OpenSellButton") as Button,
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
	return []

func open_menu(menu_id: StringName) -> void:
	menu_id = _normalize_menu_id(menu_id)
	active = true
	primary_menu_id = menu_id
	_sync_state_to_shell()
	_sync_public_fields_to_owner()
	PlayerData.is_interacting = true
	if not _open_primary_menu_by_id(menu_id):
		purchase_menu_in()

func open_board_edit_panel() -> bool:
	active = true
	primary_menu_id = &"board_edit"
	_sync_state_to_shell()
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

func purchase_panel_in() -> void:
	if owner_ui.purchase_management_root == null:
		return
	if owner_ui.is_branch_selection_blocking_interactions():
		owner_ui.show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return
	owner_ui.purchase_management_controller.set_sell_mode(false)
	owner_ui.purchase_management_controller.update_shop()
	owner_ui._mark_shop_purchase_action_dirty()
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
	_sync_state_to_shell()
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
	owner_ui._init_purchase_management_controller()
	owner_ui.purchase_management_controller.refresh_items_for_prepare()
	owner_ui._mark_shop_purchase_action_dirty()

func upgrade_panel_in() -> void:
	if owner_ui.is_branch_selection_blocking_interactions():
		owner_ui.show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return
	owner_ui.upgrade_management_controller.apply_mode(owner_ui._upgrade_mode)
	owner_ui.upgrade_management_controller.update_upg()
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
	if not owner_ui.is_rest_area_module_management_available():
		owner_ui._show_module_rest_area_only_message()
		return
	if tab != &"":
		owner_ui.module_warehouse_controller.open_tab(tab)
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
		if shell != null:
			shell.clear_module_state_if_active()
		PlayerData.is_interacting = false
	_sync_state_to_shell()
	_sync_public_fields_to_owner()

func open_purchase_weapon_panel() -> void:
	var should_wait := owner_ui.purchase_primary_root != null and owner_ui.purchase_primary_root.visible
	_hide_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)
	if should_wait:
		await owner_ui.get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	purchase_panel_in()
	owner_ui.purchase_management_controller.apply_purchase_mode(&"weapon")

func open_purchase_module_panel() -> void:
	var should_wait := owner_ui.purchase_primary_root != null and owner_ui.purchase_primary_root.visible
	_hide_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)
	if should_wait:
		await owner_ui.get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	owner_ui.purchase_management_controller.ensure_module_shop()
	purchase_panel_in()
	owner_ui.purchase_management_controller.apply_purchase_mode(&"module")

func open_purchase_sell_panel() -> void:
	var should_wait := owner_ui.purchase_primary_root != null and owner_ui.purchase_primary_root.visible
	_hide_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)
	if should_wait:
		await owner_ui.get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	warehouse_panel_in(&"weapon")

func close_purchase_panel() -> void:
	purchase_panel_out()

func back_to_purchase_primary_menu() -> void:
	purchase_panel_out()
	_show_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)

func open_upgrade_panel(mode: StringName = &"weapon") -> void:
	var should_wait := owner_ui.upgrade_primary_root != null and owner_ui.upgrade_primary_root.visible
	_hide_primary_menu(&"upgrade", owner_ui.upgrade_primary_root, owner_ui.upgrade_primary_panel)
	if should_wait:
		await owner_ui.get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	owner_ui.upgrade_management_controller.apply_mode(mode)
	upgrade_panel_in()

func close_upgrade_panel() -> void:
	upgrade_panel_out()

func back_to_upgrade_primary_menu() -> void:
	upgrade_panel_out()
	_show_primary_menu(&"upgrade", owner_ui.upgrade_primary_root, owner_ui.upgrade_primary_panel)

func open_warehouse_management_panel() -> void:
	if not owner_ui.is_rest_area_module_management_available():
		owner_ui._show_module_rest_area_only_message()
		return
	var should_wait := owner_ui.warehouse_primary_root != null and owner_ui.warehouse_primary_root.visible
	_hide_primary_menu(&"warehouse", owner_ui.warehouse_primary_root, owner_ui.warehouse_primary_panel)
	if should_wait:
		await owner_ui.get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	warehouse_panel_in(&"module")

func open_warehouse_weapon_panel() -> void:
	var should_wait := owner_ui.warehouse_primary_root != null and owner_ui.warehouse_primary_root.visible
	_hide_primary_menu(&"warehouse", owner_ui.warehouse_primary_root, owner_ui.warehouse_primary_panel)
	if should_wait:
		await owner_ui.get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	warehouse_panel_in(&"weapon")

func close_warehouse_panel() -> void:
	warehouse_panel_out()

func back_to_warehouse_primary_menu() -> void:
	if owner_ui.module_equip_selection_panel and owner_ui.module_equip_selection_panel.visible:
		owner_ui.module_equip_selection_panel.close_without_assignment()
	warehouse_panel_out()
	_show_primary_menu(&"warehouse", owner_ui.warehouse_primary_root, owner_ui.warehouse_primary_panel)

func open_cell_grid_panel() -> void:
	var should_wait := owner_ui.board_edit_primary_root != null and owner_ui.board_edit_primary_root.visible
	_hide_primary_menu(&"board_edit", owner_ui.board_edit_primary_root, owner_ui.board_edit_primary_panel)
	if should_wait:
		await owner_ui.get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	if not owner_ui.open_board_edit_panel():
		back_to_board_primary_menu()

func open_cell_task_panel() -> void:
	var should_wait := owner_ui.board_edit_primary_root != null and owner_ui.board_edit_primary_root.visible
	_hide_primary_menu(&"board_edit", owner_ui.board_edit_primary_root, owner_ui.board_edit_primary_panel)
	if should_wait:
		await owner_ui.get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	if not owner_ui.open_cell_management_panel(&"task"):
		back_to_board_primary_menu()

func back_to_board_primary_menu() -> void:
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel):
		owner_ui.cell_management_panel.call("close_panel")
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel):
		owner_ui.board_edit_panel.call("close_panel")
	_show_primary_menu(&"board_edit", owner_ui.board_edit_primary_root, owner_ui.board_edit_primary_panel)

func close_purchase_menu() -> void:
	if not active:
		return
	purchase_menu_out()
	_clear_active()

func close_primary_menu() -> void:
	if not active:
		return
	match primary_menu_id:
		&"board_edit":
			_hide_primary_menu(&"board_edit", owner_ui.board_edit_primary_root, owner_ui.board_edit_primary_panel)
			if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel):
				owner_ui.cell_management_panel.call("close_panel")
			if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel):
				owner_ui.board_edit_panel.call("close_panel")
		&"upgrade":
			upgrade_menu_out()
		&"warehouse":
			warehouse_menu_out()
		_:
			purchase_menu_out()
	_clear_active()

func is_purchase_active() -> bool:
	_sync_state_from_shell()
	_sync_public_fields_to_owner()
	return active

func set_management_root_visible(root_id: StringName, visible: bool) -> void:
	var root := _get_management_root(root_id)
	if root:
		root.visible = visible

func set_primary_root_visible(root_id: StringName, visible: bool) -> void:
	var root := _get_primary_root(root_id)
	if root:
		root.visible = visible

func is_menu_visible() -> bool:
	_sync_state_from_shell()
	var visible := false
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
		visible = true
		_sync_public_fields_to_owner()
		return visible
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
		visible = true
		_sync_public_fields_to_owner()
		return visible
	if shell != null:
		visible = shell.is_menu_visible(
			is_primary_menu_open() or is_secondary_menu_open(),
			owner_ui.weapon_warehouse_panel,
			owner_ui.module_equip_selection_panel
		)
	else:
		visible = active and _has_open_rest_area_menu()
	if not visible and primary_menu_id == &"board_edit":
		_clear_active()
		return false
	_sync_public_fields_to_owner()
	return visible

func is_zone_navigation_allowed() -> bool:
	_sync_state_from_shell()
	if owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
		_sync_public_fields_to_owner()
		return false
	if owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
		_sync_public_fields_to_owner()
		return false
	var allowed := true
	if shell != null:
		allowed = shell.is_zone_navigation_allowed(
			owner_ui.purchase_primary_root,
			owner_ui.upgrade_primary_root,
			owner_ui.warehouse_primary_root,
			owner_ui.board_edit_primary_root
		)
	else:
		allowed = _is_zone_navigation_allowed_without_shell()
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
	sync_state_from_owner()
	if primary_menu_id == &"board_edit" and owner_ui.board_edit_panel and is_instance_valid(owner_ui.board_edit_panel) and owner_ui.board_edit_panel.visible:
		if owner_ui.board_edit_panel.has_method("clear_selection_if_any") and bool(owner_ui.board_edit_panel.call("clear_selection_if_any")):
			return true
		return owner_ui.request_close_board_edit_panel(true)
	if primary_menu_id == &"board_edit" and owner_ui.cell_management_panel and is_instance_valid(owner_ui.cell_management_panel) and owner_ui.cell_management_panel.visible:
		if owner_ui.cell_management_panel.has_method("cancel_menu_level") and bool(owner_ui.cell_management_panel.call("cancel_menu_level")):
			return true
		return owner_ui.request_close_cell_management_panel()
	if owner_ui._cancel_top_level_non_battle_ui():
		sync_state_from_owner()
		return true
	if not active:
		return false
	return cancel_menu_level()

func cancel_menu_level() -> bool:
	sync_state_from_owner()
	if primary_menu_id == &"purchase":
		if owner_ui.weapon_warehouse_panel and owner_ui.weapon_warehouse_panel.visible:
			owner_ui.weapon_warehouse_panel.close_panel()
			_show_primary_menu(&"purchase", owner_ui.purchase_primary_root, owner_ui.purchase_primary_panel)
			return true
		if owner_ui.purchase_management_root and owner_ui.purchase_management_root.visible:
			if owner_ui.shop_sell_mode_active:
				owner_ui.purchase_management_controller.set_sell_mode(false)
				return true
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
	for root in [owner_ui.purchase_management_root, owner_ui.upgrade_management_root, owner_ui.warehouse_management_root]:
		if root and is_instance_valid(root) and root.visible:
			return true
	return false

func _show_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	_ensure_layout_controller()
	if layout_controller != null:
		layout_controller.show_primary_menu(menu_id, root, panel)

func _open_primary_menu_by_id(menu_id: StringName) -> bool:
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

func _stop_primary_menu_tween(menu_id: StringName) -> void:
	_ensure_layout_controller()
	if layout_controller != null:
		layout_controller.stop_primary_menu_tween(menu_id)

func _ensure_layout_controller() -> void:
	if layout_controller != null or owner_ui == null:
		return
	owner_ui._init_ui_layout_controller()
	layout_controller = owner_ui.ui_layout_controller

func sync_state_from_owner() -> void:
	if owner_ui == null:
		return
	active = owner_ui._rest_area_menu_active
	primary_menu_id = _normalize_menu_id(owner_ui._rest_area_primary_menu_id)
	_sync_state_to_shell()

func _clear_active() -> void:
	PlayerData.is_interacting = false
	active = false
	primary_menu_id = &""
	_sync_state_to_shell()
	_sync_public_fields_to_owner()

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
	return false

func _sync_state_from_shell() -> void:
	if shell == null:
		return
	active = shell.active
	primary_menu_id = _normalize_menu_id(shell.primary_menu_id)

func _sync_state_to_shell() -> void:
	if shell == null:
		return
	shell.active = active
	shell.primary_menu_id = primary_menu_id

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

