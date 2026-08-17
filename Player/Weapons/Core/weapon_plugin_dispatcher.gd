extends RefCounted
class_name WeaponPluginDispatcher

const RELOAD_DURATION_CHANNEL := &"reload_duration"

var weapon: Weapon
var _subscribers_by_event: Dictionary = {}
var _modifier_providers: Dictionary = {}

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon

func subscribe_module(module: Module) -> void:
	for event_type in module.get_subscribed_weapon_events():
		_subscribe(event_type, module)
	if module.provides_modifier_channel(RELOAD_DURATION_CHANNEL):
		_subscribe_modifier(RELOAD_DURATION_CHANNEL, module)

func unsubscribe_module(module: Module) -> void:
	for subscribers_variant in _subscribers_by_event.values():
		(subscribers_variant as Array).erase(module)
	for providers_variant in _modifier_providers.values():
		(providers_variant as Array).erase(module)

func dispatch_event(event: WeaponEvent) -> void:
	var subscribers: Array = _subscribers_by_event.get(event.type, [])
	for index in range(subscribers.size() - 1, -1, -1):
		var module := subscribers[index] as Module
		if module == null or not is_instance_valid(module):
			subscribers.remove_at(index)
			continue
		module.handle_weapon_event(event)

func get_effective_reload_duration(base_duration: float) -> float:
	var duration := maxf(base_duration, 0.0)
	var multiplier := 1.0
	var providers: Array = _modifier_providers.get(RELOAD_DURATION_CHANNEL, [])
	for index in range(providers.size() - 1, -1, -1):
		var provider := providers[index] as Node
		if provider == null or not is_instance_valid(provider):
			providers.remove_at(index)
			continue
		multiplier *= maxf(float(provider.call("get_reload_duration_multiplier", weapon, duration)), 0.05)
	return duration * multiplier

func clear_for_weapon_exit() -> void:
	_subscribers_by_event.clear()
	_modifier_providers.clear()

func _subscribe(event_type: StringName, subscriber: Node) -> void:
	var subscribers: Array = _subscribers_by_event.get(event_type, [])
	if not subscribers.has(subscriber):
		subscribers.append(subscriber)
	_subscribers_by_event[event_type] = subscribers

func _unsubscribe(event_type: StringName, subscriber: Node) -> void:
	var subscribers: Array = _subscribers_by_event.get(event_type, [])
	subscribers.erase(subscriber)

func _subscribe_modifier(channel: StringName, provider: Node) -> void:
	var providers: Array = _modifier_providers.get(channel, [])
	if not providers.has(provider):
		providers.append(provider)
	_modifier_providers[channel] = providers

func _unsubscribe_modifier(channel: StringName, provider: Node) -> void:
	var providers: Array = _modifier_providers.get(channel, [])
	providers.erase(provider)
