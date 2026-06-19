extends RefCounted
class_name ModuleTransactionDialogController

const MODULE_SETTINGS_PATH := "user://module_management_settings.cfg"

var owner_ui: Node
var gui_root: Control
var module_action_dialog: ConfirmationDialog
var temporary_module_settlement_dialog: ConfirmationDialog
var temporary_module_settlement_message: Label
var temporary_module_settlement_checkbox: CheckBox

var pending_module_action := Callable()
var pending_battle_start := Callable()
var pending_battle_start_cancel := Callable()

func bind(owner: Node, root: Control) -> void:
	owner_ui = owner
	gui_root = root

func ensure_dialogs() -> void:
	if gui_root == null:
		return
	if module_action_dialog == null or not is_instance_valid(module_action_dialog):
		module_action_dialog = ConfirmationDialog.new()
		module_action_dialog.name = "ModuleActionDialog"
		gui_root.add_child(module_action_dialog)
		module_action_dialog.confirmed.connect(_on_module_action_confirmed)
		_connect_right_cancel_window(module_action_dialog)
	if temporary_module_settlement_dialog == null or not is_instance_valid(temporary_module_settlement_dialog):
		temporary_module_settlement_dialog = ConfirmationDialog.new()
		temporary_module_settlement_dialog.name = "TemporaryModuleSettlementDialog"
		temporary_module_settlement_dialog.dialog_text = ""
		temporary_module_settlement_dialog.wrap_controls = false
		gui_root.add_child(temporary_module_settlement_dialog)
		_connect_right_cancel_window(temporary_module_settlement_dialog)
		var content := VBoxContainer.new()
		content.name = "SettlementContent"
		content.custom_minimum_size = Vector2(480.0, 0.0)
		temporary_module_settlement_message = Label.new()
		temporary_module_settlement_message.name = "Message"
		temporary_module_settlement_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(temporary_module_settlement_message)
		temporary_module_settlement_checkbox = CheckBox.new()
		temporary_module_settlement_checkbox.text = LocalizationManager.tr_key(
			"ui.module.settlement.dont_show",
			"Do not show this confirmation again"
		)
		content.add_child(temporary_module_settlement_checkbox)
		temporary_module_settlement_dialog.add_child(content)
		temporary_module_settlement_dialog.confirmed.connect(Callable(self, "_on_temporary_module_settlement_confirmed"))
		temporary_module_settlement_dialog.canceled.connect(Callable(self, "_on_temporary_module_settlement_cancelled"))

func _connect_right_cancel_window(dialog: Window) -> void:
	if dialog == null or not dialog.has_signal("window_input") or owner_ui == null:
		return
	var callback := Callable(owner_ui, "_on_cancel_window_input")
	if not dialog.is_connected("window_input", callback):
		dialog.connect("window_input", callback)

func request_module_unequip_confirmation(module_instance: Module, weapon: Weapon) -> bool:
	ensure_dialogs()
	if module_instance == null or weapon == null:
		return false
	module_action_dialog.title = LocalizationManager.tr_key("ui.module.unequip.title", "Unequip Module")
	module_action_dialog.dialog_text = LocalizationManager.tr_format(
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
	module_action_dialog.popup_centered()
	return true

func _confirm_module_unequip(module_instance: Module, weapon: Weapon) -> void:
	var result := InventoryData.unequip_module_from_weapon(module_instance, weapon)
	if not result.get("ok", false) and owner_ui and owner_ui.has_method("show_item_message"):
		owner_ui.call("show_item_message", LocalizationManager.localize_module_reason(str(result.get("reason", ""))), 1.8)

func request_temporary_module_sell_confirmation(module_instance: Module) -> bool:
	ensure_dialogs()
	if module_instance == null or not InventoryData.temporary_modules.has(module_instance):
		return false
	var gold := GlobalVariables.economy_data.get_duplicate_module_gold(
		int(module_instance.cost),
		int(module_instance.module_level)
	) if GlobalVariables.economy_data else 0
	module_action_dialog.title = LocalizationManager.tr_key("ui.module.sell.title", "Sell Module")
	module_action_dialog.dialog_text = LocalizationManager.tr_format(
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
	module_action_dialog.popup_centered()
	return true

func _confirm_temporary_module_sell(module_instance: Module) -> void:
	InventoryData.sell_temporary_module(module_instance)
	if owner_ui:
		if owner_ui.get("selected_temporary_module") == module_instance:
			owner_ui.set("selected_temporary_module", null)
		var warehouse_controller = owner_ui.get("module_warehouse_controller")
		if warehouse_controller:
			warehouse_controller.update_modules()

func _on_module_action_confirmed() -> void:
	if pending_module_action.is_valid():
		pending_module_action.call()
	pending_module_action = Callable()

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
	if temporary_module_settlement_message:
		temporary_module_settlement_message.text = LocalizationManager.tr_format(
			"ui.module.settlement.confirm",
			{"count": InventoryData.temporary_modules.size(), "gold": total_gold},
			"Sell %d temporary modules for %d Gold and start battle?" % [
				InventoryData.temporary_modules.size(),
				total_gold,
			]
		)
	temporary_module_settlement_checkbox.button_pressed = false
	temporary_module_settlement_dialog.title = LocalizationManager.tr_key(
		"ui.module.settlement.title",
		"Temporary Module Settlement"
	)
	temporary_module_settlement_dialog.popup_centered_clamped(Vector2i(560, 260), 0.8)
	return true

func confirm_temporary_module_settlement() -> void:
	if temporary_module_settlement_checkbox and temporary_module_settlement_checkbox.button_pressed:
		set_temporary_module_confirmation_enabled(false)
	InventoryData.sell_all_temporary_modules()
	if pending_battle_start.is_valid():
		pending_battle_start.call_deferred()
	pending_battle_start = Callable()
	pending_battle_start_cancel = Callable()

func cancel_temporary_module_settlement() -> void:
	if pending_battle_start_cancel.is_valid():
		pending_battle_start_cancel.call_deferred()
	pending_battle_start = Callable()
	pending_battle_start_cancel = Callable()

func _on_temporary_module_settlement_confirmed() -> void:
	confirm_temporary_module_settlement()

func _on_temporary_module_settlement_cancelled() -> void:
	cancel_temporary_module_settlement()

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
	if temporary_module_settlement_dialog and temporary_module_settlement_dialog.visible:
		temporary_module_settlement_dialog.hide()
		cancel_temporary_module_settlement()
		return true
	if module_action_dialog and module_action_dialog.visible:
		module_action_dialog.hide()
		pending_module_action = Callable()
		return true
	return false
