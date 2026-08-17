extends RefCounted
class_name ModuleTriggerState

var _ready_at_msec: int = 0
var _action_ids: Dictionary = {}
var _target_ids_by_action: Dictionary = {}

func can_trigger(spec: ModuleTriggerSpec, event: WeaponEvent) -> bool:
	if Time.get_ticks_msec() < _ready_at_msec:
		return false
	var action_id := _get_action_id(event)
	if spec.once_per_action and _action_ids.has(action_id):
		return false
	if spec.once_per_target and event.target != null:
		var target_ids: Dictionary = _target_ids_by_action.get(action_id, {})
		if target_ids.has(event.target.get_instance_id()):
			return false
	return randf() <= spec.trigger_chance

func record_trigger(spec: ModuleTriggerSpec, event: WeaponEvent) -> void:
	var action_id := _get_action_id(event)
	if spec.once_per_action:
		_action_ids[action_id] = true
	if spec.once_per_target and event.target != null:
		var target_ids: Dictionary = _target_ids_by_action.get(action_id, {})
		target_ids[event.target.get_instance_id()] = true
		_target_ids_by_action[action_id] = target_ids
	if spec.internal_cooldown_sec > 0.0:
		_ready_at_msec = Time.get_ticks_msec() + int(spec.internal_cooldown_sec * 1000.0)
	_trim_history()

func clear() -> void:
	_ready_at_msec = 0
	_action_ids.clear()
	_target_ids_by_action.clear()

func _get_action_id(event: WeaponEvent) -> int:
	return event.action_context.root_action_id if event.action_context != null else event.get_instance_id()

func _trim_history() -> void:
	while _action_ids.size() > 64:
		_action_ids.erase(_action_ids.keys()[0])
	while _target_ids_by_action.size() > 64:
		_target_ids_by_action.erase(_target_ids_by_action.keys()[0])
