extends Control

@onready var frame: PanelContainer = %RewardIconFrame
@onready var margin: MarginContainer = %Margin
@onready var texture_view: TextureRect = %RewardIconTexture
@onready var fallback_label: Label = %Fallback
@onready var badge: Label = %RewardIconBadge


func set_data(data: Dictionary) -> void:
	if frame == null:
		frame = get_node("RewardIconFrame") as PanelContainer
		margin = get_node("RewardIconFrame/Margin") as MarginContainer
		texture_view = get_node("RewardIconFrame/Margin/RewardIconTexture") as TextureRect
		fallback_label = get_node("RewardIconFrame/Margin/Fallback") as Label
		badge = get_node("RewardIconBadge") as Label
	custom_minimum_size = data.get("size", Vector2(56, 56)) as Vector2
	frame.custom_minimum_size = custom_minimum_size
	var inset := int(data.get("margin", 6))
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, inset)
	var texture := data.get("texture") as Texture2D
	texture_view.texture = texture
	texture_view.visible = texture != null
	fallback_label.text = str(data.get("fallback", "R"))
	fallback_label.visible = texture == null
	var badge_text := str(data.get("badge", ""))
	badge.text = badge_text
	badge.visible = not badge_text.is_empty()
	if badge.visible:
		var color := data.get("badge_color", Color.WHITE) as Color
		var style := badge.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		style.bg_color = Color(color.r, color.g, color.b, 0.92)
		badge.add_theme_stylebox_override("normal", style)
