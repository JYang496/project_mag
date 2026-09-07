extends Button

var view: Node
var drag_payload: Dictionary = {}
var drop_payload: Dictionary = {}


func set_drag_context(target_view: Node, drag_data: Dictionary = {}, drop_data: Dictionary = {}) -> void:
	view = target_view
	drag_payload = drag_data
	drop_payload = drop_data


func set_data(value: String, hint: String = "", minimum_size: Vector2 = Vector2.ZERO) -> void:
	text = value
	tooltip_text = hint
	if minimum_size != Vector2.ZERO:
		custom_minimum_size = minimum_size


func _get_drag_data(_at_position: Vector2) -> Variant:
	if view == null or drag_payload.is_empty() or not view.has_method("build_drag_data"):
		return null
	return view.call("build_drag_data", drag_payload, self)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if view == null or drop_payload.is_empty() or not view.has_method("can_drop_payload"):
		return false
	return bool(view.call("can_drop_payload", drop_payload, data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if view != null and not drop_payload.is_empty() and view.has_method("drop_payload"):
		view.call("drop_payload", drop_payload, data)
