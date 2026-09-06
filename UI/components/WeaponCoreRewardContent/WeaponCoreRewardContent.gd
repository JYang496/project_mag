extends VBoxContainer

@onready var title_label: Label = %WeaponCoreTitle
@onready var source_image: TextureRect = %WeaponCoreSourceImage
@onready var source_label: Label = %WeaponCoreSource
@onready var gain_label: Label = %WeaponCoreGain
@onready var inventory_status: PanelContainer = %WeaponCoreInventoryStatus
@onready var inventory_label: Label = %WeaponCoreInventory
@onready var tag_heading: Label = %CoreTagHeading
@onready var chip_grid: GridContainer = %BuildChipRow
@onready var usage_heading: Label = %WeaponCoreUsageHeading
@onready var usage_summary: Label = %WeaponCoreUsageSummary
@onready var usage_line_one: Label = %WeaponCoreUsageLine1
@onready var usage_line_two: Label = %WeaponCoreUsageLine2
@onready var usage_more: Label = %WeaponCoreUsageMore
@onready var usage_empty: Label = %WeaponCoreUsageEmpty


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	title_label.text = str(data.get("title", ""))
	source_image.texture = data.get("source_icon") as Texture2D
	source_image.visible = source_image.texture != null
	source_label.text = str(data.get("source", ""))
	source_label.visible = bool(data.get("show_source", false))
	gain_label.text = str(data.get("gain", ""))
	inventory_label.text = str(data.get("inventory", ""))
	inventory_status.set_meta(&"current_count", int(data.get("current_count", 0)))
	inventory_status.set_meta(&"resulting_count", int(data.get("resulting_count", 0)))
	tag_heading.text = str(data.get("tag_heading", ""))
	usage_heading.text = str(data.get("usage_heading", ""))
	var lines: PackedStringArray = data.get("usage_lines", PackedStringArray())
	usage_summary.visible = not lines.is_empty()
	usage_summary.text = str(data.get("usage_summary", ""))
	_set_usage_line(usage_line_one, lines, 0)
	_set_usage_line(usage_line_two, lines, 1)
	usage_more.visible = lines.size() > 2
	usage_more.text = str(data.get("usage_more", ""))
	usage_empty.visible = lines.is_empty()
	usage_empty.text = str(data.get("usage_empty", ""))


func get_chip_grid() -> GridContainer:
	_resolve_nodes()
	return chip_grid


func _set_usage_line(label: Label, lines: PackedStringArray, index: int) -> void:
	label.visible = index < lines.size()
	label.text = str(lines[index]) if label.visible else ""


func _resolve_nodes() -> void:
	if title_label != null:
		return
	title_label = get_node("WeaponCoreAcquisitionSection/WeaponCoreTitle") as Label
	source_image = get_node("WeaponCoreAcquisitionSection/WeaponCoreIconStage/WeaponCoreMaterialIcon/WeaponCoreSourceImage") as TextureRect
	source_label = get_node("WeaponCoreAcquisitionSection/WeaponCoreSource") as Label
	gain_label = get_node("WeaponCoreAcquisitionSection/WeaponCoreGain") as Label
	inventory_status = get_node("WeaponCoreAcquisitionSection/WeaponCoreInventoryStatus") as PanelContainer
	inventory_label = get_node("WeaponCoreAcquisitionSection/WeaponCoreInventoryStatus/WeaponCoreInventory") as Label
	tag_heading = get_node("WeaponCoreInheritanceSection/CoreTagHeading") as Label
	chip_grid = get_node("WeaponCoreInheritanceSection/BuildChipRow") as GridContainer
	usage_heading = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageHeadingRow/WeaponCoreUsageHeading") as Label
	usage_summary = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageSummary") as Label
	usage_line_one = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageLine1") as Label
	usage_line_two = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageLine2") as Label
	usage_more = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageMore") as Label
	usage_empty = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageEmpty") as Label
