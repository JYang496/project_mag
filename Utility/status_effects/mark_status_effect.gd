extends StatusEffect
class_name MarkStatusEffect

const EFFECT_ID_PREFIX := "mark:"

var mark_id: StringName = StringName()
var expires_at_msec: int = 0
var data: Dictionary = {}


func setup_mark(id_value: StringName, duration_sec: float, data_value: Dictionary = {}) -> MarkStatusEffect:
	mark_id = id_value
	effect_id = StringName("%s%s" % [EFFECT_ID_PREFIX, str(mark_id)])
	expires_at_msec = Time.get_ticks_msec() + int(maxf(duration_sec, 0.1) * 1000.0)
	data = data_value.duplicate(true)
	ticks_left = 1
	return self


func merge_from(other: StatusEffect) -> void:
	if other == null or not (other is MarkStatusEffect):
		return
	var typed_other := other as MarkStatusEffect
	expires_at_msec = maxi(expires_at_msec, typed_other.expires_at_msec)
	for key in typed_other.data.keys():
		data[key] = typed_other.data[key]
	if self.source_player == null and typed_other.source_player != null:
		self.source_player = typed_other.source_player
	if self.source_node == null and typed_other.source_node != null:
		self.source_node = typed_other.source_node


func is_active() -> bool:
	return expires_at_msec > Time.get_ticks_msec()


func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return data.get(key, default_value)


func step() -> bool:
	return not is_active()
