extends RefCounted
class_name TaskModuleDialogController

var modal_dialog_controller
var pending_unassigned_confirm := Callable()
var pending_unassigned_cancel := Callable()
var pending_replacement_callback := Callable()
var pending_replacement_new_module_id := ""
var pending_replacement_confirm_index := -1

func bind(controller) -> void:
	modal_dialog_controller = controller

func dispose() -> void:
	_clear_pending_state()
	modal_dialog_controller = null

func request_unassigned_confirmation(
	unassigned_count: int,
	on_confirm: Callable,
	on_cancel: Callable = Callable()
) -> bool:
	if modal_dialog_controller == null:
		return false
	_clear_pending_state()
	pending_unassigned_confirm = on_confirm
	pending_unassigned_cancel = on_cancel
	var opened: bool = bool(modal_dialog_controller.request_confirmation(
		&"task_module_unassigned_start_battle",
		LocalizationManager.tr_key("ui.task_module.unassigned_title", "Unassigned Task Modules"),
		LocalizationManager.tr_format(
			"ui.task_module.unassigned_warning",
			{"count": unassigned_count},
			"You have %d unassigned task module(s). Starting battle will discard them. Deployed tasks will be consumed for the next battle." % unassigned_count
		),
		LocalizationManager.tr_key("ui.common.continue", "Continue"),
		LocalizationManager.tr_key("ui.common.cancel", "Cancel"),
		Callable(self, "_on_unassigned_confirmed"),
		Callable(self, "_on_unassigned_cancelled"),
		true,
		Vector2i(520, 260)
	))
	if not opened:
		_clear_pending_state()
	return opened

func request_replacement(new_module_id: String, on_replace: Callable) -> bool:
	if modal_dialog_controller == null:
		return false
	_clear_pending_state()
	pending_replacement_callback = on_replace
	pending_replacement_new_module_id = new_module_id
	var new_definition := CellTaskModuleRuntime.get_definition(pending_replacement_new_module_id)
	var inventory := CellTaskModuleRuntime.get_inventory_snapshot()
	if inventory.is_empty():
		_clear_pending_state()
		return false
	pending_replacement_confirm_index = 0
	var formatted_new_module := _format_module(
		new_definition,
		pending_replacement_new_module_id
	)
	var body_lines := [
		LocalizationManager.tr_format(
			"ui.task_module.inventory_full_choose_discard",
			{"module": formatted_new_module},
			"Inventory full. Choose one existing task module to discard.\nIncoming: %s"
				% formatted_new_module
		),
		"",
		LocalizationManager.tr_key(
			"ui.task_module.old_module_discarded",
			"The old module will be discarded."
		)
	]
	var custom_actions: Array[Dictionary] = []
	var details: Array[Dictionary] = [
		{
			"label": LocalizationManager.tr_key("ui.dialog.detail.incoming", "Incoming"),
			"value": formatted_new_module,
			"tone": &"secondary",
		},
	]
	details.append({
		"label": LocalizationManager.tr_format(
			"ui.dialog.detail.discard_slot",
			{"slot": 1},
			"Slot 1"
		),
		"value": _format_module(CellTaskModuleRuntime.get_definition(str(inventory[0])), str(inventory[0])),
		"tone": &"destructive",
	})
	for index in range(1, inventory.size()):
		details.append({
			"label": LocalizationManager.tr_format(
				"ui.dialog.detail.discard_slot",
				{"slot": index + 1},
				"Slot %d" % (index + 1)
			),
			"value": _format_module(CellTaskModuleRuntime.get_definition(str(inventory[index])), str(inventory[index])),
			"tone": &"destructive",
		})
		custom_actions.append({
			"id": StringName("discard_slot_%d" % index),
			"text": _format_discard_slot_button(index, str(inventory[index])),
		})
	var opened: bool = bool(modal_dialog_controller.confirm({
		"id": &"task_module_inventory_replacement",
		"title": LocalizationManager.tr_key("ui.task_module.replace_title", "Replace Task Module"),
		"message": "\n".join(body_lines),
		"confirm_text": _format_discard_slot_button(0, str(inventory[0])),
		"cancel_text": LocalizationManager.tr_key("ui.common.cancel", "Cancel"),
		"on_confirm": Callable(self, "_on_replacement_primary_confirmed"),
		"on_cancel": Callable(self, "_on_replacement_cancelled"),
		"on_custom_action": Callable(self, "_on_replacement_custom_action"),
		"custom_actions": custom_actions,
		"destructive": true,
		"size": Vector2i(660, 420),
		"details": details,
	}))
	if not opened:
		_clear_pending_state()
		return false
	return true

func _format_discard_slot_button(index: int, module_id: String) -> String:
	var formatted_module := _format_module(
		CellTaskModuleRuntime.get_definition(module_id),
		module_id
	)
	return LocalizationManager.tr_format(
		"ui.task_module.discard_slot",
		{
			"slot": index + 1,
			"module": formatted_module
		},
		"Discard slot %d: %s" % [index + 1, formatted_module]
	)

func _format_module(definition: TaskModuleDefinition, fallback_id: String) -> String:
	if definition == null:
		return fallback_id
	return definition.get_display_name()

func _on_unassigned_confirmed() -> void:
	var callback := pending_unassigned_confirm
	_clear_pending_state()
	if callback.is_valid():
		callback.call_deferred()

func _on_unassigned_cancelled() -> void:
	var callback := pending_unassigned_cancel
	_clear_pending_state()
	if callback.is_valid():
		callback.call_deferred()

func _on_replacement_primary_confirmed() -> void:
	_select_replacement_index(pending_replacement_confirm_index)

func _on_replacement_custom_action(action: StringName) -> void:
	var action_text := str(action)
	if not action_text.begins_with("discard_slot_"):
		return
	_select_replacement_index(int(action_text.trim_prefix("discard_slot_")))

func _select_replacement_index(index: int) -> void:
	var callback := pending_replacement_callback
	_clear_pending_state()
	if callback.is_valid():
		callback.call_deferred(index)

func _on_replacement_cancelled() -> void:
	_clear_pending_state()

func _clear_pending_state() -> void:
	pending_unassigned_confirm = Callable()
	pending_unassigned_cancel = Callable()
	pending_replacement_callback = Callable()
	pending_replacement_new_module_id = ""
	pending_replacement_confirm_index = -1
