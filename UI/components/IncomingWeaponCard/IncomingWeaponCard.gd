extends PanelContainer

@onready var icon_host: Control = %IconHost
@onready var name_label: Label = %Name
@onready var meta_label: Label = %Meta
@onready var stats_label: Label = %Stats


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	name_label.text = str(data.get("name", ""))
	meta_label.text = str(data.get("meta", ""))
	stats_label.text = str(data.get("stats", ""))
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = data.get("accent", Color.WHITE) as Color
	add_theme_stylebox_override("panel", style)


func set_icon(icon: Control) -> void:
	_resolve_nodes()
	for child in icon_host.get_children():
		child.queue_free()
	icon_host.add_child(icon)


func _resolve_nodes() -> void:
	if name_label != null:
		return
	icon_host = get_node("Margin/Row/IconHost") as Control
	name_label = get_node("Margin/Row/Text/Name") as Label
	meta_label = get_node("Margin/Row/Text/Meta") as Label
	stats_label = get_node("Margin/Row/Text/Stats") as Label
