extends Button

var drag_payload: Dictionary = {}
var drop_payload: Dictionary = {}
var build_drag_data := Callable()
var can_drop_data := Callable()
var drop_data := Callable()

@onready var icon_view: TextureRect = %Icon
@onready var name_label: Label = %Name
@onready var meta_label: Label = %Meta
@onready var detail_label: Label = %Detail
@onready var selected_label: Label = %Selected
@onready var chips: HBoxContainer = %Chips


func set_data(data: Dictionary) -> void:
	if icon_view == null:
		icon_view = get_node("Margin/Row/Icon") as TextureRect
		name_label = get_node("Margin/Row/Text/Name") as Label
		meta_label = get_node("Margin/Row/Text/Meta") as Label
		detail_label = get_node("Margin/Row/Text/Detail") as Label
		selected_label = get_node("Margin/Row/Text/Selected") as Label
		chips = get_node("Margin/Row/Text/Chips") as HBoxContainer
	icon_view.texture = data.get("icon") as Texture2D
	name_label.text = str(data.get("name", ""))
	name_label.add_theme_color_override("font_color", data.get("accent", Color.WHITE) as Color)
	meta_label.text = str(data.get("meta", ""))
	detail_label.text = str(data.get("detail", ""))
	detail_label.visible = not detail_label.text.is_empty()
	selected_label.text = str(data.get("selected_text", ""))
	selected_label.visible = bool(data.get("selected", false))
	custom_minimum_size.y = float(data.get("height", 86.0))


func set_drag_interface(drag: Dictionary, drop: Dictionary, build_callback: Callable, can_drop_callback: Callable, drop_callback: Callable) -> void:
	drag_payload = drag
	drop_payload = drop
	build_drag_data = build_callback
	can_drop_data = can_drop_callback
	drop_data = drop_callback


func add_chips(row: Control) -> void:
	if chips == null:
		chips = get_node("Margin/Row/Text/Chips") as HBoxContainer
	chips.add_child(row)


func _get_drag_data(_position: Vector2) -> Variant:
	return build_drag_data.call(drag_payload, self) if not drag_payload.is_empty() and build_drag_data.is_valid() else null


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return not drop_payload.is_empty() and can_drop_data.is_valid() and bool(can_drop_data.call(drop_payload, data))


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not drop_payload.is_empty() and drop_data.is_valid():
		drop_data.call(drop_payload, data)
