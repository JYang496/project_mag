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
		_schedule()
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
	if owner_ui.weapon_replacement_panel and is_instance_valid(owner_ui.weapon_replacement_panel) and owner_ui.weapon_replacement_panel.visible:
		return true
	if owner_ui.module_equip_selection_panel and is_instance_valid(owner_ui.module_equip_selection_panel) and owner_ui.module_equip_selection_panel.visible:
		return true
	return false

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
			var module_instance := entry.get("module", null) as Module
			var on_complete := entry.get("on_complete", Callable()) as Callable
			if module_instance == null or not is_instance_valid(module_instance):
				complete_module_pickup(false, on_complete)
				return false
			processing = true
			var opened := owner_ui.request_module_equip_selection(
				module_instance,
				Callable(self, "complete_module_pickup").bind(on_complete)
			)
			if opened:
				return true
			complete_module_pickup(false, on_complete)
			return true
		_:
			return false

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui._equipment_pickup_queue = queue
	owner_ui._equipment_pickup_processing = processing
	owner_ui._equipment_pickup_dispatch_scheduled = dispatch_scheduled
