extends Button

signal install_requested(effect_id: String, cell_id: int)
signal swap_requested(from_cell_id: int, to_cell_id: int)

var logical_id: int = 0
var can_install := Callable()
var can_swap := Callable()
var get_drag_data := Callable()
var make_drag_preview := Callable()


func set_data(cell_id: int, label_text: String, effect_icon: Texture2D, selected: bool, unavailable: bool) -> void:
	logical_id = cell_id
	text = label_text
	icon = effect_icon
	button_pressed = selected
	disabled = unavailable


func set_drag_interface(can_install_callback: Callable, can_swap_callback: Callable, get_drag_callback: Callable, preview_callback: Callable) -> void:
	can_install = can_install_callback
	can_swap = can_swap_callback
	get_drag_data = get_drag_callback
	make_drag_preview = preview_callback

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	var drag_type := str(data_dict.get("type", ""))
	if drag_type == "cell_effect":
		return can_install.is_valid() and bool(can_install.call(
			str(data_dict.get("effect_id", "")),
			logical_id
		))
	if drag_type == "installed_cell_effect":
		return can_swap.is_valid() and bool(can_swap.call(
			int(data_dict.get("source_cell_id", 0)),
			logical_id
		))
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var data_dict := data as Dictionary
	var drag_type := str(data_dict.get("type", ""))
	if drag_type == "cell_effect" and can_install.is_valid():
		if can_install.call(str(data_dict.get("effect_id", "")), logical_id):
			install_requested.emit(str(data_dict.get("effect_id", "")), logical_id)
	elif drag_type == "installed_cell_effect" and can_swap.is_valid():
		if can_swap.call(int(data_dict.get("source_cell_id", 0)), logical_id):
			swap_requested.emit(int(data_dict.get("source_cell_id", 0)), logical_id)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not get_drag_data.is_valid():
		return null
	var drag_data: Dictionary = get_drag_data.call(logical_id)
	if drag_data.is_empty():
		return null
	var definition := CellEffectRuntime.get_definition(str(drag_data.get("effect_id", "")))
	if make_drag_preview.is_valid():
		set_drag_preview(make_drag_preview.call(definition, str(drag_data.get("effect_id", ""))) as Control)
	return drag_data
