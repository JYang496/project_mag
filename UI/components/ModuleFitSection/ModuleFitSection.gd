extends VBoxContainer

@onready var heading: Label = %Heading
@onready var count_label: Label = %CompatibleWeaponCount
@onready var empty_label: Label = %NoCompatibleWeapons
@onready var grid: GridContainer = %CompatibleWeaponsGrid


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	heading.text = str(data.get("heading", ""))
	count_label.text = str(data.get("count", ""))
	var empty := bool(data.get("empty", false))
	empty_label.visible = empty
	empty_label.text = str(data.get("empty_text", ""))
	grid.visible = not empty


func get_grid() -> GridContainer:
	_resolve_nodes()
	return grid


func _resolve_nodes() -> void:
	if heading != null:
		return
	heading = get_node("HeadingRow/Heading") as Label
	count_label = get_node("HeadingRow/CompatibleWeaponCount") as Label
	empty_label = get_node("NoCompatibleWeapons") as Label
	grid = get_node("CompatibleWeaponsGrid") as GridContainer
