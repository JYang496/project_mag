extends VBoxContainer

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %Name
@onready var elite_badge: Label = %EliteBadge


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	portrait.texture = data.get("texture") as Texture2D
	name_label.text = str(data.get("name", "Enemy"))
	name_label.tooltip_text = name_label.text
	var elite := bool(data.get("elite", false))
	elite_badge.visible = elite
	elite_badge.text = str(data.get("elite_text", "ELITE"))
	elite_badge.tooltip_text = elite_badge.text


func _resolve_nodes() -> void:
	if portrait != null:
		return
	portrait = get_node("Portrait") as TextureRect
	name_label = get_node("NameRow/Name") as Label
	elite_badge = get_node("NameRow/EliteBadge") as Label
