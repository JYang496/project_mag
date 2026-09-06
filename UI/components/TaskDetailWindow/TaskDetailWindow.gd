extends PanelContainer

signal close_requested

@onready var title_label: Label = %Title
@onready var task_badge: Label = %TaskBadge
@onready var rarity_swatch: ColorRect = %RaritySwatch
@onready var objective_heading: Label = %ObjectiveHeading
@onready var description_label: Label = %Description
@onready var reward_heading: Label = %RewardHeading
@onready var reward_label: Label = %Reward
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(func() -> void: close_requested.emit())


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	title_label.text = str(data.get("title", ""))
	var rarity_color := data.get("rarity_color", Color.WHITE) as Color
	title_label.add_theme_color_override("font_color", rarity_color)
	task_badge.text = "[%s]" % str(data.get("task_label", ""))
	rarity_swatch.color = rarity_color
	rarity_swatch.tooltip_text = str(data.get("rarity_name", ""))
	objective_heading.text = str(data.get("objective_heading", "Objective"))
	description_label.text = str(data.get("description", ""))
	reward_heading.text = str(data.get("reward_heading", "Reward"))
	reward_label.text = str(data.get("reward", ""))
	close_button.text = str(data.get("close_text", "Close"))


func _resolve_nodes() -> void:
	if title_label != null:
		return
	title_label = get_node("Margin/Content/Header/Title") as Label
	task_badge = get_node("Margin/Content/Badges/TaskBadge") as Label
	rarity_swatch = get_node("Margin/Content/Badges/RaritySwatch") as ColorRect
	objective_heading = get_node("Margin/Content/ObjectiveHeading") as Label
	description_label = get_node("Margin/Content/Description") as Label
	reward_heading = get_node("Margin/Content/RewardHeading") as Label
	reward_label = get_node("Margin/Content/Reward") as Label
	close_button = get_node("Margin/Content/Footer/CloseButton") as Button
