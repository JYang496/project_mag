extends RefCounted
class_name EquipmentPickupFlowController

var owner_ui: UI
var queue: Array[Dictionary] = []
var processing := false
var dispatch_scheduled := false

func bind(ui: UI) -> void:
	owner_ui = ui
	sync_state_from_owner()

func request_weapon_pickup_selection(weapon: Weapon) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	queue.append({
		"type": "weapon",
		"weapon": weapon,
	})
	_schedule()
	return true

func request_module_pickup_selection(module_instance: Module, on_complete: Callable = Callable()) -> bool:
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	queue.append({
		"type": "module",
		"module": module_instance,
		"on_complete": on_complete,
	})
	_schedule()
	return true

func request_next_queued_pickup() -> void:
	dispatch_scheduled = false
	if processing:
		_sync_public_fields_to_owner()
		return
	if _is_modal_open():
		_sync_public_fields_to_owner()
		return
	while not queue.is_empty():
		var next_index := _find_next_index()
		if next_index < 0:
			_sync_public_fields_to_owner()
			return
		var entry: Dictionary = queue.pop_at(next_index)
		if _open_entry(entry):
			_sync_public_fields_to_owner()
			return
	_sync_public_fields_to_owner()

func on_weapon_pickup_completed(_accepted: bool = false, _result: Dictionary = {}) -> void:
	processing = false
	_sync_public_fields_to_owner()
	if owner_ui != null:
		owner_ui.call_deferred("_request_next_queued_equipment_pickup")

func complete_module_pickup(assigned: bool, on_complete: Callable = Callable()) -> void:
	if on_complete.is_valid():
		on_complete.call_deferred(assigned)
	processing = false
	_sync_public_fields_to_owner()
	if owner_ui != null:
		owner_ui.call_deferred("_request_next_queued_equipment_pickup")

func complete_module_batch(_processed: bool = false) -> void:
	processing = false
	_sync_public_fields_to_owner()
	if owner_ui != null:
		owner_ui.call_deferred("_request_next_queued_equipment_pickup")
		owner_ui.call_deferred("resume_pending_weapon_branch_selection")

func sync_state_from_owner() -> void:
	if owner_ui == null:
		return
	queue = owner_ui._equipment_pickup_queue
	processing = owner_ui._equipment_pickup_processing
	dispatch_scheduled = owner_ui._equipment_pickup_dispatch_scheduled

func _schedule() -> void:
	if dispatch_scheduled:
		return
	dispatch_scheduled = true
	_sync_public_fields_to_owner()
	if owner_ui != null:
		owner_ui.call_deferred("_request_next_queued_equipment_pickup")

func _is_modal_open() -> bool:
	if owner_ui == null:
		return false
	owner_ui._init_modal_ui_controller()
	return owner_ui.modal_ui_controller != null and owner_ui.modal_ui_controller.is_modal_open()

func _find_next_index() -> int:
	for index in range(queue.size()):
		if str(queue[index].get("type", "")) == "weapon":
			return index
	return 0 if not queue.is_empty() else -1

func _open_entry(entry: Dictionary) -> bool:
	if owner_ui == null:
		return false
	match str(entry.get("type", "")):
		"weapon":
			var weapon := entry.get("weapon", null) as Weapon
			if weapon == null or not is_instance_valid(weapon):
				return false
			processing = true
			var result := InventoryData.obtain_weapon_reward(
				weapon,
				Callable(self, "on_weapon_pickup_completed")
			)
			if str(result.get("result", "")) == "selection_pending":
				return true
			processing = false
			owner_ui.call_deferred("_request_next_queued_equipment_pickup")
			return true
		"module":
			var entries: Array[Dictionary] = [entry]
			for index in range(queue.size() - 1, -1, -1):
				if str(queue[index].get("type", "")) == "module":
					entries.insert(1, queue.pop_at(index))
			return _open_module_batch(entries)
		_:
			return false

func _open_module_batch(entries: Array[Dictionary]) -> bool:
	var modules: Array[Module] = []
	var valid_entries: Array[Dictionary] = []
	for entry in entries:
		var module_instance := entry.get("module", null) as Module
		var on_complete := entry.get("on_complete", Callable()) as Callable
		if module_instance == null or not is_instance_valid(module_instance):
			if on_complete.is_valid():
				on_complete.call_deferred(false)
			continue
		modules.append(module_instance)
		valid_entries.append(entry)
	if modules.is_empty():
		return false
	processing = true
	var item_completed := func(index: int, _module: Module, assigned: bool) -> void:
		if index < 0 or index >= valid_entries.size():
			return
		var callback := valid_entries[index].get("on_complete", Callable()) as Callable
		if callback.is_valid():
			callback.call_deferred(assigned)
	var opened := owner_ui.request_module_equip_selections(
		modules,
		item_completed,
		Callable(self, "complete_module_batch")
	)
	if opened:
		return true
	for entry in valid_entries:
		var callback := entry.get("on_complete", Callable()) as Callable
		if callback.is_valid():
			callback.call_deferred(false)
	processing = false
	owner_ui.call_deferred("_request_next_queued_equipment_pickup")
	return true

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui._equipment_pickup_queue = queue
	owner_ui._equipment_pickup_processing = processing
	owner_ui._equipment_pickup_dispatch_scheduled = dispatch_scheduled
