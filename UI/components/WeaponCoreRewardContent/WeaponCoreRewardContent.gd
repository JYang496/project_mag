extends VBoxContainer

@onready var title_label: Label = %WeaponCoreTitle
@onready var source_image: TextureRect = %WeaponCoreSourceImage
@onready var source_label: Label = %WeaponCoreSource
@onready var gain_label: Label = %WeaponCoreGain
@onready var inventory_status: PanelContainer = %WeaponCoreInventoryStatus
@onready var inventory_label: Label = %WeaponCoreInventory
@onready var tag_heading: Label = %CoreTagHeading
@onready var chip_grid: GridContainer = %BuildChipRow
@onready var usage_panel: PanelContainer = $WeaponCoreUsagePanel
@onready var usage_heading: Label = %WeaponCoreUsageHeading
@onready var usage_summary: Label = %WeaponCoreUsageSummary
@onready var supported_weapon_grid: GridContainer = %WeaponCoreSupportedWeaponGrid
@onready var usage_line_one: Label = %WeaponCoreUsageLine1
@onready var usage_line_two: Label = %WeaponCoreUsageLine2
@onready var usage_more: Label = %WeaponCoreUsageMore
@onready var usage_empty: Label = %WeaponCoreUsageEmpty

var _default_usage_heading := ""
var _default_usage_summary := ""
var _default_usage_lines := PackedStringArray()
var _default_usage_entries: Array = []
var _default_usage_more := ""
var _default_usage_empty := ""


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	title_label.text = ""
	title_label.visible = false
	source_image.texture = data.get("source_icon") as Texture2D
	source_image.visible = source_image.texture != null
	source_label.text = str(data.get("source", ""))
	source_label.visible = bool(data.get("show_source", false))
	gain_label.text = ""
	gain_label.visible = false
	inventory_label.text = str(data.get("inventory", ""))
	inventory_status.set_meta(&"current_count", int(data.get("current_count", 0)))
	inventory_status.set_meta(&"resulting_count", int(data.get("resulting_count", 0)))
	tag_heading.text = str(data.get("tag_heading", ""))
	usage_heading.text = str(data.get("usage_heading", ""))
	var lines: PackedStringArray = data.get("usage_lines", PackedStringArray())
	var entries: Array = data.get("usage_entries", [])
	if entries.is_empty():
		entries = _entries_from_lines(lines)
	usage_summary.visible = false
	usage_summary.text = str(data.get("usage_summary", ""))
	_set_usage_lines(lines)
	_set_weapon_entries(entries)
	usage_more.visible = false
	usage_more.text = str(data.get("usage_more", ""))
	usage_empty.visible = lines.is_empty()
	usage_empty.text = str(data.get("usage_empty", ""))
	_default_usage_heading = usage_heading.text
	_default_usage_summary = usage_summary.text
	_default_usage_lines = lines.duplicate()
	_default_usage_entries = entries.duplicate(true)
	_default_usage_more = usage_more.text
	_default_usage_empty = usage_empty.text
	usage_panel.visible = false


func get_chip_grid() -> GridContainer:
	_resolve_nodes()
	return chip_grid


func emphasize_inherited_tags() -> void:
	_resolve_nodes()
	for chip in chip_grid.get_children():
		chip.custom_minimum_size.y = 38.0
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := chip.find_child("Label", true, false) as Label
		if label != null:
			label.add_theme_font_size_override("font_size", 16)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func configure_tag_weapon_interactions(chips: Array, tag_weapon_map: Dictionary) -> void:
	_resolve_nodes()
	for index in range(mini(chips.size(), chip_grid.get_child_count())):
		var chip_data := chips[index] as Dictionary
		var chip := chip_grid.get_child(index) as Control
		var tag_key := str(chip_data.get("source_key", ""))
		var tag_label := str(chip_data.get("label", tag_key))
		var weapon_entries: Array = tag_weapon_map.get(tag_key, [])
		chip.set_meta(&"core_tag_key", tag_key)
		chip.set_meta(&"core_tag_default_style", chip.get_theme_stylebox("panel").duplicate())
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.focus_mode = Control.FOCUS_ALL
		chip.tooltip_text = LocalizationManager.tr_format("ui.reward.core.tag_focus_hint", {"tag": tag_label}, "Show weapons supported by %s" % tag_label)
		chip.mouse_entered.connect(_show_tag_weapons.bind(tag_label, weapon_entries, chip))
		chip.mouse_exited.connect(_restore_default_usage)
		chip.focus_entered.connect(_show_tag_weapons.bind(tag_label, weapon_entries, chip))
		chip.focus_exited.connect(_restore_default_usage)


func _show_tag_weapons(tag_label: String, weapon_entries: Array, active_chip: Control) -> void:
	usage_panel.visible = true
	usage_heading.text = "%s → %s" % [tag_label, LocalizationManager.tr_key("ui.reward.core.usable_by_label", "Supported Weapons")]
	usage_summary.visible = false
	_set_usage_lines(PackedStringArray())
	_set_weapon_entries(weapon_entries)
	usage_more.visible = false
	usage_empty.visible = weapon_entries.is_empty()
	usage_empty.text = LocalizationManager.tr_key("ui.reward.core.tag_no_weapons", "No current fusion branch uses this Tag")
	_set_active_tag_chip(active_chip)


func _restore_default_usage() -> void:
	usage_panel.visible = false
	usage_heading.text = _default_usage_heading
	usage_summary.text = _default_usage_summary
	usage_summary.visible = false
	_set_usage_lines(_default_usage_lines)
	_set_weapon_entries(_default_usage_entries)
	usage_more.visible = false
	usage_more.text = _default_usage_more
	usage_empty.visible = _default_usage_lines.is_empty()
	usage_empty.text = _default_usage_empty
	_set_active_tag_chip(null)


func _set_weapon_entries(entries: Array) -> void:
	for child in supported_weapon_grid.get_children():
		supported_weapon_grid.remove_child(child)
		child.free()
	for index in range(entries.size()):
		supported_weapon_grid.add_child(_make_weapon_tile(entries[index] as Dictionary, index))
	supported_weapon_grid.visible = not entries.is_empty()


func _make_weapon_tile(entry: Dictionary, index: int) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.name = "WeaponCoreWeaponTile%d" % (index + 1)
	tile.custom_minimum_size = Vector2(0.0, 38.0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.13, 0.16, 0.86)
	style.border_color = Color(0.38, 0.50, 0.58, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	tile.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	tile.add_child(row)
	var icon := TextureRect.new()
	icon.name = "SupportedWeaponIcon"
	icon.custom_minimum_size = Vector2(22.0, 22.0)
	icon.texture = entry.get("icon") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", -2)
	row.add_child(copy)
	var name_label := Label.new()
	name_label.name = "SupportedWeaponName"
	name_label.text = str(entry.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.91, 0.94, 0.98, 1.0))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	copy.add_child(name_label)
	var branch_label := Label.new()
	branch_label.name = "SupportedWeaponBranches"
	branch_label.text = "  ".join(entry.get("branches", PackedStringArray()) as PackedStringArray)
	branch_label.add_theme_font_size_override("font_size", 10)
	branch_label.add_theme_color_override("font_color", Color(0.56, 0.65, 0.70, 1.0))
	branch_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	branch_label.clip_text = true
	copy.add_child(branch_label)
	return tile


func _entries_from_lines(lines: PackedStringArray) -> Array:
	var entries: Array = []
	for line in lines:
		var parts := str(line).split(" · ", false, 1)
		entries.append({"name": parts[0], "icon": null, "branches": PackedStringArray([parts[1]]) if parts.size() > 1 else PackedStringArray()})
	return entries


func _set_active_tag_chip(active_chip: Control) -> void:
	for child in chip_grid.get_children():
		var chip := child as Control
		chip.modulate.a = 1.0 if active_chip == null or chip == active_chip else 0.45
		var default_style := chip.get_meta(&"core_tag_default_style", null) as StyleBoxFlat
		if default_style == null:
			continue
		var style := default_style.duplicate() as StyleBoxFlat
		if chip == active_chip:
			style.set_border_width_all(2)
			style.border_color.a = 1.0
		chip.add_theme_stylebox_override("panel", style)


func _set_usage_line(label: Label, lines: PackedStringArray, index: int) -> void:
	label.visible = index < lines.size()
	label.text = str(lines[index]) if label.visible else ""


func _set_usage_lines(lines: PackedStringArray) -> void:
	var parent := usage_line_one.get_parent()
	for child in parent.get_children():
		if child.has_meta(&"generated_core_usage_line"):
			parent.remove_child(child)
			child.free()
	_set_usage_line(usage_line_one, PackedStringArray(), 0)
	_set_usage_line(usage_line_two, PackedStringArray(), 1)


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
	usage_panel = get_node("WeaponCoreUsagePanel") as PanelContainer
	usage_heading = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageHeadingRow/WeaponCoreUsageHeading") as Label
	usage_summary = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageSummary") as Label
	supported_weapon_grid = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreSupportedWeaponGrid") as GridContainer
	usage_line_one = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageLine1") as Label
	usage_line_two = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageLine2") as Label
	usage_more = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageMore") as Label
	usage_empty = get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection/WeaponCoreUsageEmpty") as Label
