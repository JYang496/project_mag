extends RefCounted
class_name TaskModuleDialogController

var modal_dialog_controller
var pending_unassigned_confirm := Callable()
var pending_unassigned_cancel := Callable()
var pending_replacement_callback := Callable()
var pending_replacement_new_module_id := ""
var pending_replacement_confirm_index := -1
var replacement_custom_buttons: Array[Button] = []

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
	var opened: bool = bool(modal_dialog_controller.request_confirmation(
		&"task_module_inventory_replacement",
		LocalizationManager.tr_key("ui.task_module.replace_title", "Replace Task Module"),
		"\n".join(body_lines),
		_format_discard_slot_button(0, str(inventory[0])),
		LocalizationManager.tr_key("ui.common.cancel", "Cancel"),
		Callable(self, "_on_replacement_primary_confirmed"),
		Callable(self, "_on_replacement_cancelled"),
		true,
		Vector2i(620, 320)
	))
	if not opened:
		_clear_pending_state()
		return false
	_attach_replacement_slot_buttons(inventory)
	return true

func _attach_replacement_slot_buttons(inventory: PackedStringArray) -> void:
	_clear_replacement_custom_buttons()
	if modal_dialog_controller == null or modal_dialog_controller.dialog == null:
		return
	var dialog: ConfirmationDialog = modal_dialog_controller.dialog
	for index in range(1, inventory.size()):
		var action := "discard_slot_%d" % index
		var button := dialog.add_button(
			_format_discard_slot_button(index, str(inventory[index])),
			false,
			action
		)
		replacement_custom_buttons.append(button)
	var custom_callback := Callable(self, "_on_replacement_custom_action")
	if not dialog.custom_action.is_connected(custom_callback):
		dialog.custom_action.connect(custom_callback)

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
	if modal_dialog_controller != null:
		modal_dialog_controller.cancel_visible_dialog()
	if callback.is_valid():
		callback.call_deferred(index)

func _on_replacement_cancelled() -> void:
	_clear_pending_state()

func _clear_pending_state() -> void:
	_clear_replacement_custom_buttons()
	pending_unassigned_confirm = Callable()
	pending_unassigned_cancel = Callable()
	pending_replacement_callback = Callable()
	pending_replacement_new_module_id = ""
	pending_replacement_confirm_index = -1

func _clear_replacement_custom_buttons() -> void:
	for button in replacement_custom_buttons:
		if button == null or not is_instance_valid(button):
			continue
		var parent := button.get_parent()
		if parent != null:
			parent.remove_child(button)
		button.queue_free()
	replacement_custom_buttons.clear()
	if modal_dialog_controller == null or modal_dialog_controller.dialog == null:
		return
	var custom_callback := Callable(self, "_on_replacement_custom_action")
	if modal_dialog_controller.dialog.custom_action.is_connected(custom_callback):
		modal_dialog_controller.dialog.custom_action.disconnect(custom_callback)
