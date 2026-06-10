extends RefCounted
class_name NpcStatusRuntime

var npc
var status_effects: Array[StatusEffect] = []
var last_status_tick_msec: int = 0

func setup(source_npc) -> void:
	npc = source_npc

func has_active_effects() -> bool:
	return not status_effects.is_empty()

func start_timer_if_needed() -> void:
	if npc == null or npc.status_timer == null or not npc.status_timer.is_stopped():
		return
	npc.status_timer.start()
	last_status_tick_msec = Time.get_ticks_msec()

func stop_timer_tracking() -> void:
	last_status_tick_msec = 0

func get_elapsed_tick_sec(default_elapsed_sec: float) -> float:
	var now_msec := Time.get_ticks_msec()
	var elapsed_sec := default_elapsed_sec
	if last_status_tick_msec > 0:
		elapsed_sec = maxf(0.0, float(now_msec - last_status_tick_msec) / 1000.0)
	last_status_tick_msec = now_msec
	return elapsed_sec

func process_tick() -> void:
	for i in range(status_effects.size() - 1, -1, -1):
		var effect := status_effects[i]
		if effect == null:
			status_effects.remove_at(i)
			continue
		effect.apply_tick(npc)
		if effect.step():
			status_effects.remove_at(i)

func apply_status_effect(effect: StatusEffect) -> void:
	if effect == null:
		return
	for existing in status_effects:
		if existing.effect_id == effect.effect_id:
			existing.merge_from(effect)
			start_timer_if_needed()
			return
	status_effects.append(effect)
	start_timer_if_needed()

func apply_mark(mark_id: StringName, duration_sec: float, data: Dictionary = {}) -> void:
	if mark_id == StringName():
		return
	apply_status_effect(MarkStatusEffect.new().setup_mark(mark_id, duration_sec, data))

func has_mark(mark_id: StringName) -> bool:
	return _get_mark_effect(mark_id) != null

func has_any_mark() -> bool:
	return not get_active_mark_ids().is_empty()

func get_active_mark_ids() -> Array[StringName]:
	var output: Array[StringName] = []
	for i in range(status_effects.size() - 1, -1, -1):
		var effect := status_effects[i]
		if effect == null:
			status_effects.remove_at(i)
			continue
		if effect is MarkStatusEffect:
			var mark_effect := effect as MarkStatusEffect
			if not mark_effect.is_active():
				status_effects.remove_at(i)
				continue
			output.append(mark_effect.mark_id)
	return output

func get_mark_value(mark_id: StringName, key: StringName, default_value: Variant = null) -> Variant:
	var effect := _get_mark_effect(mark_id)
	if effect == null:
		return default_value
	return effect.get_value(key, default_value)

func apply_damage_taken_multiplier_status(status_id: StringName, multiplier: float, duration_sec: float) -> void:
	if status_id == StringName():
		return
	var effect: StatusEffect = DamageTakenMultiplierStatusEffect.new().setup_multiplier(status_id, multiplier, duration_sec)
	apply_status_effect(effect)

func has_damage_taken_multiplier_status(status_id: StringName) -> bool:
	return _get_damage_taken_multiplier_status(status_id) != null

func get_damage_taken_multiplier_status_value(status_id: StringName, default_value: float = 1.0) -> float:
	var effect := _get_damage_taken_multiplier_status(status_id)
	if effect == null:
		return default_value
	return float(effect.get("multiplier"))

func get_damage_taken_multiplier() -> float:
	var multiplier := 1.0
	for i in range(status_effects.size() - 1, -1, -1):
		var effect := status_effects[i]
		if effect == null:
			status_effects.remove_at(i)
			continue
		if _is_damage_taken_multiplier_status(effect):
			if not bool(effect.call("is_active")):
				status_effects.remove_at(i)
				continue
			multiplier *= maxf(float(effect.get("multiplier")), 0.0)
	return multiplier

func apply_status_payload(status_name: StringName, status_data: Variant) -> void:
	match status_name:
		&"dot":
			apply_status_effect(DotStatusEffect.from_dot_payload(status_data))
		&"mark":
			if status_data is Dictionary:
				var payload_mark := status_data as Dictionary
				var mark_data: Dictionary = {}
				var raw_mark_data: Variant = payload_mark.get("data", {})
				if raw_mark_data is Dictionary:
					mark_data = (raw_mark_data as Dictionary).duplicate(true)
				apply_mark(
					StringName(payload_mark.get("mark_id", StringName())),
					float(payload_mark.get("duration", 0.1)),
					mark_data
				)
		&"damage_taken_multiplier":
			if status_data is Dictionary:
				var payload_multiplier := status_data as Dictionary
				apply_damage_taken_multiplier_status(
					StringName(payload_multiplier.get("status_id", StringName())),
					float(payload_multiplier.get("multiplier", 1.0)),
					float(payload_multiplier.get("duration", 0.1))
				)

func _get_mark_effect(mark_id: StringName) -> MarkStatusEffect:
	if mark_id == StringName():
		return null
	for effect in status_effects:
		if effect is MarkStatusEffect:
			var mark_effect := effect as MarkStatusEffect
			if mark_effect.is_active() and mark_effect.mark_id == mark_id:
				return mark_effect
	get_active_mark_ids()
	return null

func _get_damage_taken_multiplier_status(status_id: StringName) -> StatusEffect:
	if status_id == StringName():
		return null
	for i in range(status_effects.size() - 1, -1, -1):
		var effect := status_effects[i]
		if effect == null:
			status_effects.remove_at(i)
			continue
		if _is_damage_taken_multiplier_status(effect):
			if not bool(effect.call("is_active")):
				status_effects.remove_at(i)
				continue
			if StringName(effect.get("status_id")) == status_id:
				return effect
	return null

func _is_damage_taken_multiplier_status(effect: StatusEffect) -> bool:
	return effect is DamageTakenMultiplierStatusEffect
