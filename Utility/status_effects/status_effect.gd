extends RefCounted
class_name StatusEffect

var effect_id: StringName = StringName()
var ticks_left: int = 0
var source_player: Node
var source_node: Node


func setup(id_value: StringName, tick_value: int) -> StatusEffect:
	effect_id = id_value
	ticks_left = max(0, tick_value)
	return self


func set_source_context(player_ref: Node, node_ref: Node = null) -> StatusEffect:
	source_player = player_ref
	source_node = node_ref
	return self


func merge_from(_other: StatusEffect) -> void:
	pass


func apply_tick(_target: Node) -> void:
	pass


func step() -> bool:
	ticks_left -= 1
	return ticks_left <= 0
