extends RefCounted
class_name ModuleManagementActionPresenter

var owner_view: Node
var primary_action_button: Button
var secondary_action_button: Button
var status_label: Label

func bind(view: Node, primary_button: Button, secondary_button: Button, status: Label) -> void:
	owner_view = view
	primary_action_button = primary_button
	secondary_action_button = secondary_button
	status_label = status

func set_action_nodes(primary_button: Button, secondary_button: Button, status: Label) -> void:
	primary_action_button = primary_button
	secondary_action_button = secondary_button
	status_label = status

func refresh_weapon_action() -> void:
	if primary_action_button == null or secondary_action_button == null or status_label == null:
		return
	secondary_action_button.visible = false
	var selected_stored_weapon := _get_selected_stored_weapon()
	var selected_equipped_weapon := _get_selected_equipped_weapon()
	if selected_stored_weapon != null and is_instance_valid(selected_stored_weapon):
		if PlayerData.player_weapon_list.size() < PlayerData.max_weapon_num:
			primary_action_button.disabled = false
			primary_action_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.equip_empty", "Equip to Empty Slot")
			return
		primary_action_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.exchange_selected", "Exchange with Selected")
		if selected_equipped_weapon != null and is_instance_valid(selected_equipped_weapon):
			primary_action_button.disabled = false
			status_label.text = LocalizationManager.tr_format(
				"ui.weapon.warehouse.exchange_preview",
				{"stored": LocalizationManager.get_weapon_name_from_node(selected_stored_weapon), "equipped": LocalizationManager.get_weapon_name_from_node(selected_equipped_weapon)},
				"Exchange stored weapon with selected held weapon."
			)
		else:
			status_label.text = LocalizationManager.tr_key("ui.weapon.warehouse.select_exchange_target", "Select a held weapon on the left to exchange.")
		return
	if selected_equipped_weapon != null and is_instance_valid(selected_equipped_weapon):
		primary_action_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.store", "Store in Warehouse")
		primary_action_button.disabled = PlayerData.player_weapon_list.size() <= 1
		if primary_action_button.disabled:
			status_label.text = LocalizationManager.tr_key("ui.weapon.warehouse.keep_one", "At least one weapon must remain equipped.")
		return
	primary_action_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.action", "Manage Weapon")

func refresh_module_action() -> void:
	if primary_action_button == null or secondary_action_button == null or status_label == null:
		return
	var selected_module := _get_selected_module()
	var selected_equipped_module := _get_selected_equipped_module()
	var selected_equipped_module_weapon := _get_selected_equipped_module_weapon()
	primary_action_button.text = LocalizationManager.tr_key("ui.module.action.unequip", "Unequip Module")
	primary_action_button.disabled = selected_equipped_module == null or selected_equipped_module_weapon == null
	secondary_action_button.text = LocalizationManager.tr_key("ui.module.action.sell_selected", "Sell Selected Module")
	secondary_action_button.disabled = not (
		(selected_module != null and is_instance_valid(selected_module))
		or (selected_equipped_module != null and is_instance_valid(selected_equipped_module))
	)
	if selected_module != null and is_instance_valid(selected_module):
		status_label.text = LocalizationManager.tr_key("ui.module.slot_click_hint", "Click a highlighted slot on the left to install or replace.")
	elif selected_equipped_module != null and is_instance_valid(selected_equipped_module):
		status_label.text = LocalizationManager.tr_key("ui.module.equipped_action_hint", "Sell this module or unequip it back to temporary storage.")
	else:
		status_label.text = LocalizationManager.tr_key("ui.module.select_prompt", "Select a temporary module to manage.")

func perform_primary_action() -> bool:
	if owner_view == null:
		return false
	if owner_view.get("active_tab") == &"weapon":
		return perform_weapon_action()
	if _get_selected_equipped_module() != null and _get_selected_equipped_module_weapon() != null:
		return perform_module_unequip()
	return false

func perform_secondary_action() -> bool:
	if owner_view == null or owner_view.get("active_tab") != &"module":
		return false
	if owner_view.has_method("trigger_sell"):
		return bool(owner_view.call("trigger_sell"))
	return false

func perform_weapon_action() -> bool:
	if owner_view == null:
		return false
	var selected_stored_weapon := _get_selected_stored_weapon()
	var selected_equipped_weapon := _get_selected_equipped_weapon()
	if selected_stored_weapon != null and is_instance_valid(selected_stored_weapon):
		var result: Dictionary
		if PlayerData.player_weapon_list.size() < PlayerData.max_weapon_num:
			result = InventoryData.equip_stored_weapon(selected_stored_weapon)
		elif selected_equipped_weapon != null and is_instance_valid(selected_equipped_weapon):
			result = InventoryData.exchange_stored_weapon(selected_stored_weapon, selected_equipped_weapon)
		else:
			return false
		if not result.get("ok", false):
			_show_message(str(result.get("reason", "")), 1.6)
			return false
		owner_view.set("selected_stored_weapon", null)
		owner_view.set("selected_equipped_weapon", null)
		_refresh_view()
		return true
	if selected_equipped_weapon != null and is_instance_valid(selected_equipped_weapon):
		var store_result := InventoryData.store_weapon(selected_equipped_weapon)
		if not store_result.get("ok", false):
			_show_message(str(store_result.get("reason", "")), 1.6)
			return false
		owner_view.set("selected_equipped_weapon", null)
		_refresh_view()
		return true
	return false

func perform_module_unequip() -> bool:
	if owner_view == null:
		return false
	var selected_equipped_module := _get_selected_equipped_module()
	var selected_equipped_module_weapon := _get_selected_equipped_module_weapon()
	var result := InventoryData.unequip_module_from_weapon(selected_equipped_module, selected_equipped_module_weapon)
	if not result.get("ok", false):
		_show_message(str(result.get("reason", "")), 1.6)
		return false
	owner_view.set("selected_equipped_module", null)
	owner_view.set("selected_equipped_module_weapon", null)
	_refresh_view()
	return true

func _get_selected_module() -> Module:
	return owner_view.get("selected_module") as Module if owner_view != null else null

func _get_selected_equipped_module() -> Module:
	return owner_view.get("selected_equipped_module") as Module if owner_view != null else null

func _get_selected_equipped_module_weapon() -> Weapon:
	return owner_view.get("selected_equipped_module_weapon") as Weapon if owner_view != null else null

func _get_selected_equipped_weapon() -> Weapon:
	return owner_view.get("selected_equipped_weapon") as Weapon if owner_view != null else null

func _get_selected_stored_weapon() -> Weapon:
	return owner_view.get("selected_stored_weapon") as Weapon if owner_view != null else null

func _show_message(message: String, duration: float) -> void:
	if owner_view != null and owner_view.has_method("_show_message"):
		owner_view.call("_show_message", message, duration)

func _refresh_view() -> void:
	if owner_view != null and owner_view.has_method("refresh_all"):
		owner_view.call("refresh_all")
