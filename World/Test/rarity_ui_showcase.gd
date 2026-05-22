extends Control

const RARITY_UTIL := preload("res://data/LootRarity.gd")

const CARD_BG := Color(0.07, 0.075, 0.085, 0.96)
const PANEL_BG := Color(0.025, 0.03, 0.04, 1.0)
const TEXT_MUTED := Color(0.72, 0.76, 0.82, 1.0)
const TEXT_MAIN := Color(0.94, 0.96, 0.98, 1.0)

func _ready() -> void:
	_build_showcase()

func _build_showcase() -> void:
	_add_background()

	var root := VBoxContainer.new()
	root.name = "RarityUiShowcaseRoot"
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 48.0
	root.offset_top = 36.0
	root.offset_right = -48.0
	root.offset_bottom = -36.0
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var title := Label.new()
	title.text = "Rarity Reward UI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = RARITY_UTIL.get_weight_summary()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", TEXT_MUTED)
	root.add_child(subtitle)

	root.add_child(_section_label("Rarity Legend"))
	root.add_child(_build_rarity_grid())
	root.add_child(_section_label("Battle Reward Selection"))
	root.add_child(_build_reward_preview_grid())
	root.add_child(_section_label("Inventory / Equipment Preview"))
	root.add_child(_build_inventory_preview_row())

func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = PANEL_BG
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

func _section_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", TEXT_MAIN)
	return label

func _build_rarity_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = RARITY_UTIL.get_count()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for rarity in RARITY_UTIL.get_all():
		grid.add_child(_build_rarity_card(rarity))
	return grid

func _build_reward_preview_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.add_child(_build_reward_card(RARITY_UTIL.COMMON, "Weapon", "Machine Gun", "Lv.1", "Fuse candidate"))
	grid.add_child(_build_reward_card(RARITY_UTIL.RARE, "Module", "Reload Damage Boost", "Lv.1", "Trigger / Buff"))
	grid.add_child(_build_reward_card(RARITY_UTIL.EPIC, "Weapon", "Plasma Lance", "Lv.1", "Heat weapon"))
	return grid

func _build_inventory_preview_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_build_compact_slot(RARITY_UTIL.COMMON, "Pistol", "Fuse 1  Lv.1/7"))
	row.add_child(_build_compact_slot(RARITY_UTIL.RARE, "Cryo Infuser", "Module Lv.2"))
	row.add_child(_build_compact_slot(RARITY_UTIL.EPIC, "Rocket Launcher", "Fuse 2  Lv.4/7"))
	return row

func _build_rarity_card(rarity: String) -> PanelContainer:
	var card := _base_card(rarity, Vector2(210, 112))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	card.add_child(body)

	var name_label := Label.new()
	name_label.text = RARITY_UTIL.get_display_name(rarity)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", RARITY_UTIL.get_color(rarity))
	body.add_child(name_label)

	var weight_label := Label.new()
	weight_label.text = "Weight %.0f" % RARITY_UTIL.get_default_weight(rarity)
	weight_label.add_theme_font_size_override("font_size", 15)
	weight_label.add_theme_color_override("font_color", TEXT_MUTED)
	body.add_child(weight_label)

	var swatch := ColorRect.new()
	swatch.color = RARITY_UTIL.get_color(rarity)
	swatch.custom_minimum_size = Vector2(0, 12)
	body.add_child(swatch)
	return card

func _build_reward_card(rarity: String, item_type: String, item_name: String, level_text: String, detail: String) -> PanelContainer:
	var card := _base_card(rarity, Vector2(438, 116))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)

	var eyebrow := Label.new()
	eyebrow.text = "%s  /  %s" % [RARITY_UTIL.get_display_name(rarity), item_type]
	eyebrow.add_theme_color_override("font_color", RARITY_UTIL.get_color(rarity))
	eyebrow.add_theme_font_size_override("font_size", 14)
	body.add_child(eyebrow)

	var name_label := Label.new()
	name_label.text = "%s  %s" % [item_name, level_text]
	name_label.add_theme_color_override("font_color", TEXT_MAIN)
	name_label.add_theme_font_size_override("font_size", 22)
	body.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.add_theme_color_override("font_color", TEXT_MUTED)
	detail_label.add_theme_font_size_override("font_size", 14)
	body.add_child(detail_label)
	return card

func _build_compact_slot(rarity: String, item_name: String, detail: String) -> PanelContainer:
	var card := _base_card(rarity, Vector2(210, 88))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	card.add_child(body)

	var name_label := Label.new()
	name_label.text = "[%s] %s" % [RARITY_UTIL.get_display_name(rarity), item_name]
	name_label.add_theme_color_override("font_color", RARITY_UTIL.get_color(rarity))
	name_label.add_theme_font_size_override("font_size", 15)
	body.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.add_theme_color_override("font_color", TEXT_MUTED)
	detail_label.add_theme_font_size_override("font_size", 13)
	body.add_child(detail_label)
	return card

func _base_card(rarity: String, min_size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = RARITY_UTIL.get_color(rarity)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", style)
	return card
