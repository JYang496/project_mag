extends RefCounted
class_name UiDirtySignalController

var owner_ui: UI
var passive_status_signal_weapons: Array[Node] = []
var _inventory_refresh_queued := false

func bind(ui: UI) -> void:
	owner_ui = ui

func connect_ui_dirty_signals() -> void:
	if owner_ui == null:
		return
	if not InventoryData.inventory_changed.is_connected(_on_inventory_changed):
		InventoryData.inventory_changed.connect(_on_inventory_changed)
	if not InventoryData.notification_requested.is_connected(_on_inventory_notification):
		InventoryData.notification_requested.connect(_on_inventory_notification)
	if not InventoryData.weapon_replacement_requested.is_connected(_on_weapon_replacement_requested):
		InventoryData.weapon_replacement_requested.connect(_on_weapon_replacement_requested)
	var weapon_list_changed := Callable(self, "_on_player_weapon_list_changed")
	if not PlayerData.weapon_list_changed.is_connected(weapon_list_changed):
		PlayerData.weapon_list_changed.connect(weapon_list_changed)
	var main_weapon_changed := Callable(self, "_on_main_weapon_index_changed")
	if not PlayerData.main_weapon_index_changed.is_connected(main_weapon_changed):
		PlayerData.main_weapon_index_changed.connect(main_weapon_changed)
	var health_changed := Callable(self, "_on_player_health_changed")
	if not PlayerData.player_health_changed.is_connected(health_changed):
		PlayerData.player_health_changed.connect(health_changed)
	var gold_changed := Callable(self, "_on_player_gold_changed")
	if not PlayerData.player_gold_changed.is_connected(gold_changed):
		PlayerData.player_gold_changed.connect(gold_changed)
	var temporary_modules_changed := Callable(self, "_on_inventory_modules_changed")
	if not InventoryData.temporary_modules_changed.is_connected(temporary_modules_changed):
		InventoryData.temporary_modules_changed.connect(temporary_modules_changed)
	var weapon_storage_changed := Callable(self, "_on_inventory_weapon_storage_changed")
	if not InventoryData.weapon_storage_changed.is_connected(weapon_storage_changed):
		InventoryData.weapon_storage_changed.connect(weapon_storage_changed)
	rebind_weapon_passive_status_signals()

func disconnect_ui_dirty_signals() -> void:
	for binding in [
		[InventoryData.inventory_changed, _on_inventory_changed],
		[InventoryData.notification_requested, _on_inventory_notification],
		[InventoryData.weapon_replacement_requested, _on_weapon_replacement_requested],
	]:
		if binding[0].is_connected(binding[1]):
			binding[0].disconnect(binding[1])
	var weapon_list_changed := Callable(self, "_on_player_weapon_list_changed")
	if PlayerData.weapon_list_changed.is_connected(weapon_list_changed):
		PlayerData.weapon_list_changed.disconnect(weapon_list_changed)
	var main_weapon_changed := Callable(self, "_on_main_weapon_index_changed")
	if PlayerData.main_weapon_index_changed.is_connected(main_weapon_changed):
		PlayerData.main_weapon_index_changed.disconnect(main_weapon_changed)
	var health_changed := Callable(self, "_on_player_health_changed")
	if PlayerData.player_health_changed.is_connected(health_changed):
		PlayerData.player_health_changed.disconnect(health_changed)
	var gold_changed := Callable(self, "_on_player_gold_changed")
	if PlayerData.player_gold_changed.is_connected(gold_changed):
		PlayerData.player_gold_changed.disconnect(gold_changed)
	var temporary_modules_changed := Callable(self, "_on_inventory_modules_changed")
	if InventoryData.temporary_modules_changed.is_connected(temporary_modules_changed):
		InventoryData.temporary_modules_changed.disconnect(temporary_modules_changed)
	var weapon_storage_changed := Callable(self, "_on_inventory_weapon_storage_changed")
	if InventoryData.weapon_storage_changed.is_connected(weapon_storage_changed):
		InventoryData.weapon_storage_changed.disconnect(weapon_storage_changed)

func rebind_weapon_passive_status_signals() -> void:
	disconnect_weapon_passive_status_signals()
	for weapon_variant in PlayerData.player_weapon_list:
		var weapon := weapon_variant as Node
		if weapon == null or not is_instance_valid(weapon):
			continue
		_connect_weapon_passive_status_signal(weapon, "passive_triggered")
		_connect_weapon_passive_status_signal(weapon, "weapon_reload_completed")
		_connect_weapon_passive_status_signal(weapon, "weapon_role_changed")
		_connect_weapon_passive_status_signal(weapon, "shoot")
		passive_status_signal_weapons.append(weapon)

func disconnect_weapon_passive_status_signals() -> void:
	var callback := Callable(self, "_on_weapon_passive_status_signal")
	for weapon in passive_status_signal_weapons:
		if weapon == null or not is_instance_valid(weapon):
			continue
		for signal_name in ["passive_triggered", "weapon_reload_completed", "weapon_role_changed", "shoot"]:
			if weapon.has_signal(signal_name) and weapon.is_connected(signal_name, callback):
				weapon.disconnect(signal_name, callback)
	passive_status_signal_weapons.clear()

func connect_weapon_passive_status_signal(weapon: Node, signal_name: String) -> void:
	_connect_weapon_passive_status_signal(weapon, signal_name)

func _connect_weapon_passive_status_signal(weapon: Node, signal_name: String) -> void:
	if not weapon.has_signal(signal_name):
		return
	var callback := Callable(self, "_on_weapon_passive_status_signal")
	if not weapon.is_connected(signal_name, callback):
		weapon.connect(signal_name, callback)

func _on_player_weapon_list_changed() -> void:
	if owner_ui == null:
		return
	owner_ui._mark_weapon_passive_panel_dirty()
	owner_ui._mark_shop_purchase_action_dirty()
	owner_ui._mark_hud_inventory_dirty()
	owner_ui._mark_hud_weapon_dirty()
	owner_ui._mark_upgrade_action_dirty()
	owner_ui._mark_warehouse_action_dirty()
	rebind_weapon_passive_status_signals()

func _on_main_weapon_index_changed(_old_index: int, _new_index: int, _step: int) -> void:
	if owner_ui == null:
		return
	owner_ui._mark_weapon_passive_panel_dirty()
	owner_ui._mark_hud_weapon_dirty()

func _on_player_health_changed(_current_hp: int, _max_hp: int) -> void:
	if owner_ui != null:
		owner_ui._mark_hud_hp_dirty()

func _on_player_gold_changed(_value: int) -> void:
	if owner_ui == null:
		return
	owner_ui._mark_hud_inventory_dirty()
	owner_ui._mark_shop_purchase_action_dirty()
	owner_ui._mark_upgrade_action_dirty()
	owner_ui._mark_warehouse_action_dirty()

func _on_inventory_modules_changed() -> void:
	if owner_ui == null:
		return
	owner_ui._mark_hud_inventory_dirty()
	owner_ui._mark_upgrade_action_dirty()
	owner_ui._mark_warehouse_action_dirty()
	owner_ui._mark_weapon_passive_panel_dirty()

func _on_inventory_weapon_storage_changed() -> void:
	if owner_ui == null:
		return
	owner_ui._mark_hud_inventory_dirty()
	owner_ui._mark_upgrade_action_dirty()
	owner_ui._mark_warehouse_action_dirty()

func _on_weapon_passive_status_signal(_arg1: Variant = null, _arg2: Variant = null, _arg3: Variant = null) -> void:
	if owner_ui == null:
		return
	owner_ui._mark_weapon_passive_panel_dirty()
	owner_ui._mark_hud_weapon_dirty()

func _on_inventory_changed() -> void:
	if _inventory_refresh_queued:
		return
	_inventory_refresh_queued = true
	_refresh_inventory_views.call_deferred()

func _refresh_inventory_views() -> void:
	_inventory_refresh_queued = false
	if not is_instance_valid(owner_ui) or not owner_ui.is_inside_tree():
		return
	if owner_ui.module_warehouse_controller:
		owner_ui.module_warehouse_controller.update_modules()
	if owner_ui.purchase_management_controller:
		owner_ui.purchase_management_controller.update_shop()
	if owner_ui.upgrade_management_controller:
		owner_ui.upgrade_management_controller.update_upg()
	owner_ui.refresh_border()

func _on_inventory_notification(message: String, duration: float) -> void:
	if is_instance_valid(owner_ui):
		owner_ui.show_item_message(message, duration)

func _on_weapon_replacement_requested(weapon: Weapon, on_complete: Callable, request: Dictionary) -> void:
	if is_instance_valid(owner_ui) and not bool(request["opened"]):
		request["opened"] = owner_ui.request_weapon_replacement(weapon, false, on_complete)
