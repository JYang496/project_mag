extends Button

@onready var selection_indicator: ColorRect = %SelectionIndicatorBar
@onready var body: VBoxContainer = %Body
@onready var hold_progress: ProgressBar = %HoldProgress
@onready var key_badge: Label = %KeyBadge
@onready var type_badge: Label = %RewardTypeBadge
@onready var selected_badge: Label = %SelectedBadge


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	set_meta(&"reward_index", int(data.get("reward_index", -1)))
	set_meta(&"reward_type", StringName(data.get("reward_type", &"generic")))
	set_meta(&"is_weapon_reward", bool(data.get("is_weapon_reward", false)))
	set_meta(&"is_weapon_core_reward", bool(data.get("is_weapon_core_reward", false)))
	custom_minimum_size.y = float(data.get("minimum_height", 372.0))

	var key_text := str(data.get("key_text", ""))
	key_badge.text = key_text
	key_badge.visible = not key_text.is_empty()
	type_badge.text = str(data.get("type_label", "REWARD"))
	selected_badge.text = str(data.get("selected_text", "SELECTED"))
	_apply_badge_color(type_badge, data.get("type_color", Color.WHITE) as Color)
	_apply_badge_color(key_badge, data.get("accent_color", Color.WHITE) as Color)
	_apply_badge_color(selected_badge, data.get("accent_color", Color.WHITE) as Color)


func set_selected(selected: bool) -> void:
	_resolve_nodes()
	selection_indicator.visible = selected
	selected_badge.visible = selected
	button_pressed = selected


func get_content_root() -> VBoxContainer:
	_resolve_nodes()
	return body


func _resolve_nodes() -> void:
	if body != null:
		return
	selection_indicator = get_node("SelectionIndicatorBar") as ColorRect
	body = get_node("CardContentMargin/Body") as VBoxContainer
	hold_progress = get_node("CardContentMargin/Body/HoldProgress") as ProgressBar
	key_badge = get_node("CardContentMargin/Body/TopRow/KeyBadge") as Label
	type_badge = get_node("CardContentMargin/Body/TopRow/RewardTypeBadge") as Label
	selected_badge = get_node("CardContentMargin/Body/TopRow/SelectedBadge") as Label


func _apply_badge_color(label: Label, color: Color) -> void:
	var style := label.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	style.bg_color = Color(color.r, color.g, color.b, 0.22)
	style.border_color = Color(color.r, color.g, color.b, 0.72)
	label.add_theme_stylebox_override("normal", style)
