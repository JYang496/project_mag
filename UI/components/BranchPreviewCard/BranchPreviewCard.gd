extends PanelContainer

@onready var icon_row: HBoxContainer = %BranchDamageTypeIcons
@onready var name_label: Label = %BranchPreviewName
@onready var recipe: HBoxContainer = %BranchPreviewFusionRecipe
@onready var status_label: Label = %BranchPreviewUnlockState
@onready var accent_strip: Control = %BranchAccentStripOverlay


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	var primary := data.get("primary_color", Color.WHITE) as Color
	name_label.text = str(data.get("name", "Branch"))
	name_label.tooltip_text = name_label.text
	name_label.add_theme_color_override("font_color", primary)
	status_label.text = str(data.get("status", ""))
	icon_row.call("set_data", data.get("icon_items", []) as Array, float(data.get("icon_size", 20.0)), "BranchDamageTypeIcons")
	recipe.call("set_data", str(data.get("recipe_prefix", "")), data.get("recipe_tags", []) as Array)
	accent_strip.call("set_data", data.get("accent_colors", []) as Array)
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = data.get("background", style.bg_color) as Color
	add_theme_stylebox_override("panel", style)


func _resolve_nodes() -> void:
	if name_label != null:
		return
	icon_row = get_node("Content/BranchPreviewTitleRow/BranchDamageTypeIcons") as HBoxContainer
	name_label = get_node("Content/BranchPreviewTitleRow/BranchPreviewName") as Label
	recipe = get_node("Content/BranchPreviewFusionRecipe") as HBoxContainer
	status_label = get_node("Content/BranchPreviewUnlockState") as Label
	accent_strip = get_node("BranchAccentStripOverlay") as Control
