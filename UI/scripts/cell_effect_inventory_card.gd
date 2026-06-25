extends Button
class_name CellEffectInventoryCard

var effect_id: String = ""
var board_edit_panel: Control

func _get_drag_data(_at_position: Vector2) -> Variant:
	if effect_id.strip_edges() == "":
		return null
	if board_edit_panel == null or not board_edit_panel.has_method("can_drag_effect"):
		return null
	if not bool(board_edit_panel.call("can_drag_effect", effect_id)):
		return null
	var definition := CellEffectRuntime.get_definition(effect_id)
	var preview := board_edit_panel.call("build_effect_drag_preview", definition, effect_id) as Control \
			if board_edit_panel.has_method("build_effect_drag_preview") else Label.new()
	if preview is Label:
		(preview as Label).text = definition.get_display_name() if definition else effect_id
	set_drag_preview(preview)
	return {
		"type": "cell_effect",
		"effect_id": effect_id,
	}
