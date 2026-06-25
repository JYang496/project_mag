extends Button
class_name CellEffectBoardCellButton

var logical_id: int = 0
var board_edit_panel: Control

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if board_edit_panel == null:
		return false
	var data_dict := data as Dictionary
	var drag_type := str(data_dict.get("type", ""))
	if drag_type == "cell_effect":
		if not board_edit_panel.has_method("can_install_effect_on_cell"):
			return false
		return bool(board_edit_panel.call(
			"can_install_effect_on_cell",
			str(data_dict.get("effect_id", "")),
			logical_id
		))
	if drag_type == "installed_cell_effect":
		if not board_edit_panel.has_method("can_swap_installed_effect_between_cells"):
			return false
		return bool(board_edit_panel.call(
			"can_swap_installed_effect_between_cells",
			int(data_dict.get("source_cell_id", 0)),
			logical_id
		))
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	if board_edit_panel == null:
		return
	var data_dict := data as Dictionary
	var drag_type := str(data_dict.get("type", ""))
	if drag_type == "cell_effect" and board_edit_panel.has_method("install_effect_on_cell"):
		board_edit_panel.call("install_effect_on_cell", str(data_dict.get("effect_id", "")), logical_id)
	elif drag_type == "installed_cell_effect" and board_edit_panel.has_method("swap_installed_effect_between_cells"):
		board_edit_panel.call("swap_installed_effect_between_cells", int(data_dict.get("source_cell_id", 0)), logical_id)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if board_edit_panel == null or not board_edit_panel.has_method("get_installed_drag_data_for_cell"):
		return null
	var drag_data: Dictionary = board_edit_panel.call("get_installed_drag_data_for_cell", logical_id)
	if drag_data.is_empty():
		return null
	var definition := CellEffectRuntime.get_definition(str(drag_data.get("effect_id", "")))
	if board_edit_panel.has_method("build_effect_drag_preview"):
		set_drag_preview(board_edit_panel.call("build_effect_drag_preview", definition, str(drag_data.get("effect_id", ""))) as Control)
	return drag_data
