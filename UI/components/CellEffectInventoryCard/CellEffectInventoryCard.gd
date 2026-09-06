extends Button

var effect_id: String = ""
var can_drag := Callable()
var make_drag_preview := Callable()


func set_data(id: String, label_text: String, effect_icon: Texture2D, selected: bool, unavailable: bool) -> void:
	effect_id = id
	text = label_text
	icon = effect_icon
	button_pressed = selected
	disabled = unavailable


func set_drag_interface(can_drag_callback: Callable, preview_callback: Callable) -> void:
	can_drag = can_drag_callback
	make_drag_preview = preview_callback

func _get_drag_data(_at_position: Vector2) -> Variant:
	if effect_id.strip_edges() == "":
		return null
	if not can_drag.is_valid():
		return null
	if not bool(can_drag.call(effect_id)):
		return null
	var definition := CellEffectRuntime.get_definition(effect_id)
	if make_drag_preview.is_valid():
		set_drag_preview(make_drag_preview.call(definition, effect_id) as Control)
	return {
		"type": "cell_effect",
		"effect_id": effect_id,
	}
