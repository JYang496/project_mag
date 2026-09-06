extends Button

@onready var standard: HBoxContainer = %Standard
@onready var standard_icon: TextureRect = %StandardIcon
@onready var standard_title: Label = %StandardTitle
@onready var standard_level: Label = %StandardLevel
@onready var standard_params: Label = %StandardParams
@onready var standard_location: Label = %StandardLocation
@onready var compact: VBoxContainer = %Compact
@onready var compact_icon: TextureRect = %CompactIcon
@onready var compact_title: Label = %CompactTitle
@onready var compact_level: Label = %CompactLevel
@onready var compact_location: Label = %CompactLocation
@onready var compact_params: Label = %CompactParams


func set_data(data: Dictionary, compact_mode: bool) -> void:
	standard.visible = not compact_mode
	compact.visible = compact_mode
	custom_minimum_size = Vector2(246, 92) if compact_mode else Vector2(500, 92)
	var level := int(data.get("level", 0))
	var maximum := int(data.get("max_level", 0))
	var price := int(data.get("price", 0))
	var price_text := "-" if level >= maximum else str(price)
	var accent := data.get("rarity_color", Color(0.86, 0.94, 1.0)) as Color
	if compact_mode:
		compact_icon.texture = data.get("icon") as Texture2D
		compact_title.text = str(data.get("name", ""))
		compact_title.add_theme_color_override("font_color", accent)
		compact_level.text = "Lv.%d/%d  %s" % [level, maximum, price_text]
		compact_location.text = str(data.get("location", ""))
		compact_params.text = str(data.get("params", ""))
	else:
		standard_icon.texture = data.get("icon") as Texture2D
		standard_title.text = str(data.get("name", ""))
		standard_title.add_theme_color_override("font_color", accent)
		standard_level.text = "Lv.%d/%d    %s" % [level, maximum, str(data.get("cost_text", price_text))]
		standard_params.text = str(data.get("params", ""))
		standard_location.text = str(data.get("location", ""))
