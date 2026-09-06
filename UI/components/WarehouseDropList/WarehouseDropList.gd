extends VBoxContainer

var view: Node
var drop_payload: Dictionary = {}


func set_context(target_view: Node, payload: Dictionary = {}) -> void:
	view = target_view
	drop_payload = payload


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if view == null or drop_payload.is_empty() or not view.has_method("can_drop_payload"):
		return false
	return bool(view.call("can_drop_payload", drop_payload, data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if view != null and not drop_payload.is_empty() and view.has_method("drop_payload"):
		view.call("drop_payload", drop_payload, data)
