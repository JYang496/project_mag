extends Button

var drag_payload: Dictionary = {}
var drop_payload: Dictionary = {}
var build_drag_data := Callable()
var can_drop_data := Callable()
var drop_data := Callable()

@onready var module_icon: TextureRect = %ModuleIcon
@onready var empty_mark: Label = %EmptyMark
@onready var badge: Label = %Badge


func set_data(data: Dictionary) -> void:
	if module_icon == null:
		module_icon = get_node("Margin/Center/Visual/ModuleIcon") as TextureRect
		empty_mark = get_node("Margin/Center/Visual/EmptyMark") as Label
		badge = get_node("Margin/Center/Visual/Badge") as Label
	var occupied := bool(data.get("occupied", false))
	module_icon.texture = data.get("icon") as Texture2D
	empty_mark.visible = not occupied
	badge.text = str(data.get("badge", ""))
	badge.add_theme_color_override("font_color", data.get("accent", Color.WHITE) as Color)
	tooltip_text = str(data.get("tooltip", ""))
	set_meta("slot_feedback_ok", bool(data.get("feedback_ok", true)))


func set_drag_interface(drag: Dictionary, drop: Dictionary, build_callback: Callable, can_drop_callback: Callable, drop_callback: Callable) -> void:
	drag_payload = drag
	drop_payload = drop
	build_drag_data = build_callback
	can_drop_data = can_drop_callback
	drop_data = drop_callback


func _get_drag_data(_position: Vector2) -> Variant:
	return build_drag_data.call(drag_payload, self) if not drag_payload.is_empty() and build_drag_data.is_valid() else null


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return not drop_payload.is_empty() and can_drop_data.is_valid() and bool(can_drop_data.call(drop_payload, data))


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not drop_payload.is_empty() and drop_data.is_valid():
		drop_data.call(drop_payload, data)
