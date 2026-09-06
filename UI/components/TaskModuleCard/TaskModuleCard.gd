extends Button

var drag_payload: Dictionary = {}
var build_drag_data := Callable()

@onready var name_label: Label = %Name
@onready var task_badge: Label = %TaskBadge
@onready var rarity_badge: Label = %RarityBadge


func set_data(data: Dictionary) -> void:
	name_label.text = str(data.get("name", ""))
	name_label.add_theme_color_override("font_color", data.get("accent", Color.WHITE) as Color)
	task_badge.text = "[%s]" % str(data.get("task", ""))
	var rarity_color := data.get("rarity_color", Color.WHITE) as Color
	rarity_badge.tooltip_text = str(data.get("rarity_name", ""))
	var rarity_style := rarity_badge.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	rarity_style.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.28)
	rarity_style.border_color = rarity_color
	rarity_badge.add_theme_stylebox_override("normal", rarity_style)
	button_pressed = bool(data.get("selected", false))
	toggle_mode = button_pressed
	task_badge.visible = not str(data.get("task", "")).is_empty()
	rarity_badge.visible = bool(data.get("show_rarity", false))


func set_drag_interface(payload: Dictionary, callback: Callable) -> void:
	drag_payload = payload
	build_drag_data = callback


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty() or not build_drag_data.is_valid():
		return null
	return build_drag_data.call(drag_payload, self)
