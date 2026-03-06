extends RefCounted
class_name StatusEffect

var effect_id: StringName = StringName()
var ticks_left: int = 0


func setup(id_value: StringName, tick_value: int) -> StatusEffect:
	effect_id = id_value
	ticks_left = max(0, tick_value)
	return self


func merge_from(_other: StatusEffect) -> void:
	pass


func apply_tick(_target: Node) -> void:
	pass


func step() -> bool:
	ticks_left -= 1
	return ticks_left <= 0
