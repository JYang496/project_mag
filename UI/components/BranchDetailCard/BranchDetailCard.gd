extends PanelContainer

@onready var name_label: Label = %BranchName
@onready var type_label: Label = %DamageType
@onready var icon_row: HBoxContainer = %BranchDetailDamageTypeIcons
@onready var description_label: Label = %Description
@onready var recipe: HBoxContainer = %BranchFusionRecipe
@onready var accent_strip: Control = %BranchAccentStripOverlay


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	var primary := data.get("primary_color", Color.WHITE) as Color
	name_label.text = str(data.get("name", "Branch"))
	name_label.add_theme_color_override("font_color", primary)
	type_label.text = str(data.get("type_text", ""))
	type_label.add_theme_color_override("font_color", primary)
	icon_row.call("set_data", data.get("icon_items", []) as Array, 14.0, "BranchDetailDamageTypeIcons")
	description_label.text = str(data.get("description", ""))
	recipe.call("set_data", str(data.get("recipe_prefix", "")), data.get("recipe_tags", []) as Array)
	accent_strip.call("set_data", data.get("accent_colors", []) as Array)
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = data.get("background", style.bg_color) as Color
	add_theme_stylebox_override("panel", style)


func _resolve_nodes() -> void:
	if name_label != null:
		return
	name_label = get_node("Content/BranchName") as Label
	type_label = get_node("Content/DamageType") as Label
	icon_row = get_node("Content/DamageType/BranchDetailDamageTypeIcons") as HBoxContainer
	description_label = get_node("Content/Description") as Label
	recipe = get_node("Content/BranchFusionRecipe") as HBoxContainer
	accent_strip = get_node("BranchAccentStripOverlay") as Control
