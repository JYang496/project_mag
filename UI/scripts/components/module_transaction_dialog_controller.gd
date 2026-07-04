extends RefCounted
class_name ModuleTransactionDialogController

const MODULE_SETTINGS_PATH := "user://module_management_settings.cfg"

var owner_ui: Node
var gui_root: Control
var modal_dialog_controller
var module_action_dialog: ConfirmationDialog
var temporary_module_settlement_dialog: ConfirmationDialog
var temporary_module_settlement_message: Label
var temporary_module_settlement_checkbox: CheckBox

var pending_module_action := Callable()
var pending_battle_start := Callable()
var pending_battle_start_cancel := Callable()
var active_dialog_id: StringName = &""

func bind(owner: Node, root: Control, modal_controller = null) -> void:
	owner_ui = owner
	gui_root = root
	modal_dialog_controller = modal_controller

func set_modal_dialog_controller(modal_controller) -> void:
	modal_dialog_controller = modal_controller
	_sync_legacy_dialog_refs()

func ensure_dialogs() -> void:
	if gui_root == null:
		return
	if modal_dialog_controller == null and owner_ui != null and owner_ui.has_method("_init_modal_dialog_controller"):
		owner_ui.call("_init_modal_dialog_controller")
		modal_dialog_controller = owner_ui.get("modal_dialog_controller")
	if modal_dialog_controller == null:
		return
	modal_dialog_controller.ensure_dialog()
	_sync_legacy_dialog_refs()

func _sync_legacy_dialog_refs() -> void:
	if modal_dialog_controller == null:
		return
	module_action_dialog = modal_dialog_controller.dialog
	temporary_module_settlement_dialog = modal_dialog_controller.dialog
	temporary_module_settlement_message = modal_dialog_controller.message_label
	temporary_module_settlement_checkbox = modal_dialog_controller.checkbox

func request_module_unequip_confirmation(module_instance: Module, weapon: Weapon) -> bool:
	ensure_dialogs()
	if module_instance == null or weapon == null:
		return false
	var body := LocalizationManager.tr_format(
		"ui.module.unequip.confirm",
		{
			"module": LocalizationManager.get_module_name(module_instance),
			"weapon": LocalizationManager.get_weapon_name_from_node(weapon),
		},
		"Move %s from %s to the temporary area? Unsold modules are sold when battle starts." % [
			LocalizationManager.get_module_name(module_instance),
			LocalizationManager.get_weapon_name_from_node(weapon),
		]
	)
	pending_module_action = Callable(self, "_confirm_module_unequip").bind(module_instance, weapon)
	active_dialog_id = &"module_action"
	var result: bool = modal_dialog_controller.request_confirmation(
		&"module_action",
		LocalizationManager.tr_key("ui.module.unequip.title", "Unequip Module"),
		body,
		"OK",
		"Cancel",
		Callable(self, "_on_module_action_confirmed"),
		Callable(self, "_on_module_action_cancelled"),
		false,
		&"medium"
	)
	_sync_legacy_dialog_refs()
	if not result:
		_on_module_action_cancelled()
	return result

func _confirm_module_unequip(module_instance: Module, weapon: Weapon) -> void:
	var result := InventoryData.unequip_module_from_weapon(module_instance, weapon)
	if not result.get("ok", false) and owner_ui and owner_ui.has_method("show_item_message"):
		owner_ui.call("show_item_message", LocalizationManager.localize_module_reason(str(result.get("reason", ""))), 1.8)

func request_temporary_module_sell_confirmation(module_instance: Module) -> bool:
	ensure_dialogs()
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	var gold := GlobalVariables.economy_data.get_duplicate_module_gold(
		int(module_instance.cost),
		int(module_instance.module_level)
	) if GlobalVariables.economy_data else 0
	var body := LocalizationManager.tr_format(
		"ui.module.sell.confirm",
		{
			"module": LocalizationManager.get_module_name(module_instance),
			"level": module_instance.module_level,
			"gold": gold,
		},
		"Sell %s Lv.%d for %d Gold? This cannot be undone." % [
			LocalizationManager.get_module_name(module_instance),
			module_instance.module_level,
			gold,
		]
	)
	pending_module_action = Callable(self, "_confirm_temporary_module_sell").bind(module_instance)
	active_dialog_id = &"module_action"
	var result: bool = modal_dialog_controller.request_confirmation(
		&"module_action",
		LocalizationManager.tr_key("ui.module.sell.title", "Sell Module"),
		body,
		"Sell",
		"Cancel",
		Callable(self, "_on_module_action_confirmed"),
		Callable(self, "_on_module_action_cancelled"),
		true,
		&"medium"
	)
	_sync_legacy_dialog_refs()
	if not result:
		_on_module_action_cancelled()
	return result

func _confirm_temporary_module_sell(module_instance: Module) -> void:
	_clear_sold_module_selection(module_instance)
	var result := InventoryData.sell_module(module_instance)
	if not result.get("ok", false) and owner_ui and owner_ui.has_method("show_item_message"):
		owner_ui.call("show_item_message", str(result.get("reason", "")), 1.8)
	if owner_ui:
		var warehouse_controller = owner_ui.get("module_warehouse_controller")
		if warehouse_controller:
			warehouse_controller.update_modules()

func _on_module_action_confirmed(_id: StringName = &"") -> void:
	if pending_module_action.is_valid():
		pending_module_action.call()
	pending_module_action = Callable()
	active_dialog_id = &""
	_sync_owner_legacy_refs()

func _on_module_action_cancelled(_id: StringName = &"") -> void:
	pending_module_action = Callable()
	active_dialog_id = &""
	_sync_owner_legacy_refs()

func request_temporary_module_settlement(on_complete: Callable, on_cancel: Callable = Callable()) -> bool:
	ensure_dialogs()
	if owner_ui and owner_ui.has_method("has_pending_blocking_transaction") and bool(owner_ui.call("has_pending_blocking_transaction")):
		if owner_ui.has_method("show_item_message"):
			owner_ui.call("show_item_message", LocalizationManager.tr_key(
				"ui.transaction.pending",
				"Finish or cancel the current equipment transaction first."
			), 1.8)
		if on_cancel.is_valid():
			on_cancel.call_deferred()
		return false
	if InventoryData.temporary_modules.is_empty():
		on_complete.call_deferred()
		return true
	pending_battle_start = on_complete
	pending_battle_start_cancel = on_cancel
	if not is_temporary_module_confirmation_enabled():
		InventoryData.sell_all_temporary_modules()
		on_complete.call_deferred()
		pending_battle_start = Callable()
		pending_battle_start_cancel = Callable()
		return true
	var total_gold := 0
	for module_instance in InventoryData.temporary_modules:
		total_gold += GlobalVariables.economy_data.get_duplicate_module_gold(
			int(module_instance.cost),
			int(module_instance.module_level)
		) if GlobalVariables.economy_data else 0
	var body := LocalizationManager.tr_format(
		"ui.module.settlement.confirm",
		{"count": InventoryData.temporary_modules.size(), "gold": total_gold},
		"Sell %d temporary modules for %d Gold and start battle?" % [
			InventoryData.temporary_modules.size(),
			total_gold,
		]
	)
	active_dialog_id = &"temporary_module_settlement"
	var result: bool = modal_dialog_controller.request_confirmation(
		&"temporary_module_settlement",
		LocalizationManager.tr_key("ui.module.settlement.title", "Temporary Module Settlement"),
		body,
		"Sell",
		"Cancel",
		Callable(self, "_on_temporary_module_settlement_confirmed"),
		Callable(self, "_on_temporary_module_settlement_cancelled"),
		false,
		Vector2i(560, 260),
		LocalizationManager.tr_key(
			"ui.module.settlement.dont_show",
			"Do not show this confirmation again"
		)
	)
	_sync_legacy_dialog_refs()
	if not result:
		cancel_temporary_module_settlement()
	return result

func confirm_temporary_module_settlement() -> void:
	if temporary_module_settlement_checkbox and temporary_module_settlement_checkbox.button_pressed:
		set_temporary_module_confirmation_enabled(false)
	var callback := pending_battle_start
	pending_battle_start = Callable()
	pending_battle_start_cancel = Callable()
	active_dialog_id = &""
	_sync_owner_legacy_refs()
	InventoryData.sell_all_temporary_modules()
	if callback.is_valid():
		callback.call_deferred()

func cancel_temporary_module_settlement() -> void:
	var callback := pending_battle_start_cancel
	pending_battle_start = Callable()
	pending_battle_start_cancel = Callable()
	active_dialog_id = &""
	_sync_owner_legacy_refs()
	if callback.is_valid():
		callback.call_deferred()

func _on_temporary_module_settlement_confirmed(_id: StringName = &"") -> void:
	confirm_temporary_module_settlement()

func _on_temporary_module_settlement_cancelled(_id: StringName = &"") -> void:
	var callback := pending_battle_start_cancel
	pending_battle_start = Callable()
	pending_battle_start_cancel = Callable()
	active_dialog_id = &""
	_sync_owner_legacy_refs()
	if callback.is_valid():
		callback.call()

func is_temporary_module_confirmation_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(MODULE_SETTINGS_PATH) != OK:
		return true
	return bool(cfg.get_value("module_management", "confirm_temporary_sale", true))

func set_temporary_module_confirmation_enabled(enabled: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(MODULE_SETTINGS_PATH)
	cfg.set_value("module_management", "confirm_temporary_sale", enabled)
	cfg.save(MODULE_SETTINGS_PATH)

func cancel_visible_dialog() -> bool:
	if modal_dialog_controller == null or not modal_dialog_controller.is_dialog_visible():
		return false
	if active_dialog_id == &"":
		return false
	return modal_dialog_controller.cancel_visible_dialog()

func _sync_owner_legacy_refs() -> void:
	if owner_ui != null and owner_ui.has_method("_sync_module_transaction_dialog_refs"):
		owner_ui.call("_sync_module_transaction_dialog_refs")

func _clear_sold_module_selection(module_instance: Module) -> void:
	if owner_ui == null or module_instance == null:
		return
	if owner_ui.get("selected_temporary_module") == module_instance:
		owner_ui.set("selected_temporary_module", null)
	var view = owner_ui.get("module_management_view")
	if view == null:
		var warehouse_controller = owner_ui.get("module_warehouse_controller")
		if warehouse_controller != null:
			view = warehouse_controller.get("module_management_view")
	if view == null:
		return
	if view.has_method("clear_module_selection"):
		view.call("clear_module_selection", module_instance)
		return
	if view.get("selected_module") == module_instance:
		view.set("selected_module", null)
	if view.get("selected_equipped_module") == module_instance:
		view.set("selected_equipped_module", null)
		view.set("selected_equipped_module_weapon", null)
