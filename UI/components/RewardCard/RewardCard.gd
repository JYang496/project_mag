extends Button

const CARD_FRAME_TEXTURE := preload("res://asset/images/ui/reward_card_parts/source/card_frame_cyan.png")
const CONTENT_WELL_TEXTURE := preload("res://asset/images/ui/reward_card_parts/source/content_well.png")
const KEY_CYAN_TEXTURE := preload("res://asset/images/ui/reward_card_parts/source/key_badge_cyan.png")
const KEY_AMBER_TEXTURE := preload("res://asset/images/ui/reward_card_parts/source/key_badge_amber.png")
const TYPE_CYAN_TEXTURE := preload("res://asset/images/ui/reward_card_parts/source/type_plate_cyan.png")
const TYPE_AMBER_TEXTURE := preload("res://asset/images/ui/reward_card_parts/source/type_plate_amber.png")
const HOLD_TRACK_TEXTURE := preload("res://asset/images/ui/reward_card_parts/source/hold_progress_track.png")
const SELECTED_STRIP_TEXTURE := preload("res://asset/images/ui/reward_card_parts/source/selected_strip_amber.png")

const CARD_FRAME_REGION := Rect2(33, 37, 1071, 1280)
const CONTENT_WELL_REGION := Rect2(156, 78, 894, 1245)
const KEY_CYAN_REGION := Rect2(57, 21, 1302, 1035)
const KEY_AMBER_REGION := Rect2(218, 140, 960, 932)
const TYPE_CYAN_REGION := Rect2(0, 201, 1764, 613)
const TYPE_AMBER_REGION := Rect2(0, 165, 1765, 528)
const HOLD_TRACK_REGION := Rect2(16, 189, 1951, 388)
const SELECTED_STRIP_REGION := Rect2(63, 217, 1854, 382)

@onready var card_well_art: TextureRect = %CardWellArt
@onready var card_frame_art: TextureRect = %CardFrameArt
@onready var selected_strip_art: TextureRect = %SelectedStripArt
@onready var selection_indicator: ColorRect = %SelectionIndicatorBar
@onready var body: VBoxContainer = %Body
@onready var hold_progress: ProgressBar = %HoldProgress
@onready var key_badge: Label = %KeyBadge
@onready var type_badge: Label = %RewardTypeBadge
@onready var selected_badge: Label = %SelectedBadge

func _ready() -> void:
	_apply_static_art()


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	_apply_static_art()
	set_meta(&"reward_index", int(data.get("reward_index", -1)))
	set_meta(&"reward_type", StringName(data.get("reward_type", &"generic")))
	set_meta(&"is_weapon_reward", bool(data.get("is_weapon_reward", false)))
	set_meta(&"is_weapon_core_reward", bool(data.get("is_weapon_core_reward", false)))
	custom_minimum_size.y = float(data.get("minimum_height", 372.0))

	var key_text := str(data.get("key_text", ""))
	key_badge.text = key_text
	key_badge.visible = not key_text.is_empty()
	type_badge.text = str(data.get("type_label", "REWARD"))
	selected_badge.text = str(data.get("selected_text", "SELECTED"))
	var accent_color: Color = data.get("accent_color", Color.WHITE)
	var type_color: Color = data.get("type_color", accent_color)
	_set_badge_art(type_badge, _is_warm(type_color), false)
	_set_badge_art(key_badge, _is_warm(accent_color), true)
	_set_badge_art(selected_badge, true, false)


func set_selected(selected: bool) -> void:
	_resolve_nodes()
	selection_indicator.visible = selected
	selected_strip_art.visible = selected
	selected_badge.visible = selected
	button_pressed = selected


func get_content_root() -> VBoxContainer:
	_resolve_nodes()
	return body


func _resolve_nodes() -> void:
	if body != null:
		return
	selection_indicator = get_node("SelectionIndicatorBar") as ColorRect
	card_well_art = get_node("CardWellArt") as TextureRect
	card_frame_art = get_node("CardFrameArt") as TextureRect
	selected_strip_art = get_node("SelectedStripArt") as TextureRect
	body = get_node("CardContentMargin/Body") as VBoxContainer
	hold_progress = get_node("CardContentMargin/Body/HoldProgress") as ProgressBar
	key_badge = get_node("CardHeaderMargin/TopRow/KeyBadge") as Label
	type_badge = get_node("CardHeaderMargin/TopRow/RewardTypeBadge") as Label
	selected_badge = get_node("CardHeaderMargin/TopRow/SelectedBadge") as Label


func _apply_static_art() -> void:
	_resolve_nodes()
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.draw_center = false
	focus_style.border_color = Color(0.48, 0.9, 0.92, 0.9)
	focus_style.set_border_width_all(2)
	focus_style.set_expand_margin_all(2)
	add_theme_stylebox_override("focus", focus_style)
	card_well_art.texture = _crop(CONTENT_WELL_TEXTURE, CONTENT_WELL_REGION)
	card_frame_art.texture = _crop(CARD_FRAME_TEXTURE, CARD_FRAME_REGION)
	selected_strip_art.texture = _crop(SELECTED_STRIP_TEXTURE, SELECTED_STRIP_REGION)
	var track := hold_progress.get_node_or_null("TrackArt") as TextureRect
	if track == null:
		track = _background_art(hold_progress, "TrackArt")
	track.texture = _crop(HOLD_TRACK_TEXTURE, HOLD_TRACK_REGION)
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hold_progress.add_theme_stylebox_override("background", StyleBoxEmpty.new())

func _set_badge_art(label: Label, amber: bool, key: bool) -> void:
	var art := label.get_node_or_null("PlateArt") as TextureRect
	if art == null:
		art = _background_art(label, "PlateArt")
	art.texture = _crop(
		(KEY_AMBER_TEXTURE if amber else KEY_CYAN_TEXTURE) if key else (TYPE_AMBER_TEXTURE if amber else TYPE_CYAN_TEXTURE),
		(KEY_AMBER_REGION if amber else KEY_CYAN_REGION) if key else (TYPE_AMBER_REGION if amber else TYPE_CYAN_REGION)
	)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

func _background_art(parent: Control, node_name: String) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	art.show_behind_parent = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	parent.add_child(art)
	return art

func _crop(source: Texture2D, region: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = source
	result.region = region
	return result

func _is_warm(color: Color) -> bool:
	return color.r > color.b * 1.2 and color.g > color.b * 1.2 and color.r > color.g
