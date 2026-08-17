extends RefCounted
class_name WeaponSelectorReadabilityPresenter

const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")
const INPUT_PROMPT_ATLAS := preload("res://asset/images/ui/input_prompts/kenney_pixel/input_prompts_tilemap.png")
const CONTROL_HINT_Y := 86.0
const CONTROL_HINT_HEIGHT := 22.0
const CONTROL_HINT_HALF_WIDTH := 168.0
const INPUT_PROMPT_TILE_SIZE := 16
const INPUT_PROMPT_TILE_STRIDE := 17

var _root: Control
var _slots: Array[Control] = []
var _empty_labels: Array[Label] = []
var _passive_icons: Array[Control] = []
var _control_hints: Array[PanelContainer] = []

func setup(root: Control, slots: Array[Control]) -> void:
	_root = root
	_slots = slots
	_empty_labels.resize(_slots.size())
	_passive_icons.resize(_slots.size())
	for slot_index in range(_slots.size()):
		_ensure_slot_decorations(slot_index)
	if _control_hints.is_empty():
		_control_hints.append(_create_control_hint(
			"SwitchHint",
			Vector2(0.0, CONTROL_HINT_Y),
			Vector2(CONTROL_HINT_HALF_WIDTH, CONTROL_HINT_HEIGHT),
			Color(0.22, 0.62, 0.72, 0.96),
			false
		))
		_control_hints.append(_create_control_hint(
			"ReloadHint",
			Vector2(CONTROL_HINT_HALF_WIDTH, CONTROL_HINT_Y),
			Vector2(CONTROL_HINT_HALF_WIDTH, CONTROL_HINT_HEIGHT),
			Color(0.92, 0.62, 0.18, 0.96),
			true
		))
	refresh_copy()

func refresh_copy() -> void:
	if _control_hints.size() >= 2:
		_set_control_hint(
			_control_hints[0],
			[Vector2i(17, 2), Vector2i(19, 2)],
			LocalizationManager.tr_key("ui.controls.switch_weapon", "Switch Weapon"),
			true
		)
		_set_control_hint(
			_control_hints[1],
			[Vector2i(20, 2)],
			LocalizationManager.tr_key("ui.controls.reload", "Reload"),
			false
		)

func update_slot(slot_index: int, weapon: Variant, is_mainhand: bool) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	var empty_label := _empty_labels[slot_index]
	if empty_label != null:
		empty_label.visible = weapon == null
	var slot := _slots[slot_index]
	if weapon == null:
		slot.tooltip_text = LocalizationManager.tr_key(
			"ui.weapon_hud.empty",
			"EMPTY WEAPON SLOT"
		)
	elif is_mainhand:
		var model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon)
		slot.tooltip_text = LocalizationManager.tr_format(
			"ui.weapon_hud.main_tooltip_detail",
			{
				"weapon": model.display_name,
				"types": model.taxonomy_text(),
				"mechanic": model.first_description_sentence(),
			},
			"%s\n%s\n%s\nMAIN WEAPON" % [model.display_name, model.taxonomy_text(), model.first_description_sentence()]
		)
	else:
		var model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon)
		slot.tooltip_text = LocalizationManager.tr_format(
			"ui.weapon_hud.reserve_tooltip_detail",
			{
				"weapon": model.display_name,
				"types": model.taxonomy_text(),
				"mechanic": model.first_description_sentence(),
			},
			"%s\n%s\n%s\nRESERVE WEAPON" % [model.display_name, model.taxonomy_text(), model.first_description_sentence()]
		)

func set_passive_visible(_slot_index: int, _visible_value: bool) -> void:
	# Passive state is communicated by charge beans and cycle progress. A generic
	# diamond icon duplicated that information without identifying the passive.
	pass

func get_passive_icon(slot_index: int) -> Control:
	if slot_index < 0 or slot_index >= _passive_icons.size():
		return null
	var passive_icon := _passive_icons[slot_index]
	if passive_icon != null and is_instance_valid(passive_icon):
		return passive_icon
	return null

func _ensure_slot_decorations(slot_index: int) -> void:
	var slot := _slots[slot_index]
	var empty_label := slot.get_node_or_null("EmptyLabel") as Label
	if empty_label == null:
		empty_label = Label.new()
		empty_label.name = "EmptyLabel"
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_label.set_anchors_preset(Control.PRESET_CENTER)
		empty_label.position = Vector2(-14.0, -13.0)
		empty_label.size = Vector2(28.0, 26.0)
		empty_label.text = "—"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override(
			"font_color",
			Color(0.46, 0.58, 0.64, 0.72)
		)
		empty_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.add_child(empty_label)
	_empty_labels[slot_index] = empty_label

	var passive_icon := slot.get_node_or_null("PassiveIcon") as Control
	if passive_icon != null:
		passive_icon.queue_free()
	_passive_icons[slot_index] = null

func _create_control_hint(
	node_name: String,
	hint_position: Vector2,
	hint_size: Vector2,
	accent: Color,
	leading_divider: bool
) -> PanelContainer:
	var existing := _root.get_node_or_null(node_name) as PanelContainer
	if existing != null:
		return existing
	var hint := PanelContainer.new()
	hint.name = node_name
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.position = hint_position
	hint.size = hint_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.075, 0.9)
	style.border_color = accent
	style.border_width_left = 1 if leading_divider else 0
	style.border_width_bottom = 2
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	hint.add_theme_stylebox_override("normal", style)
	hint.add_theme_stylebox_override("panel", style)
	hint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var content := HBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	hint.add_child(content)
	_root.add_child(hint)
	return hint

func _set_control_hint(
	hint: PanelContainer,
	icon_coords: Array[Vector2i],
	action_text: String,
	show_separator: bool
) -> void:
	var content := hint.get_node_or_null("Content") as HBoxContainer
	if content == null:
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for index in range(icon_coords.size()):
		if index > 0 and show_separator:
			content.add_child(_make_hint_label("/", Color(0.68, 0.79, 0.82, 1.0)))
		content.add_child(_make_prompt_icon(icon_coords[index]))
	content.add_child(_make_hint_label(action_text, Color(0.88, 0.95, 0.96, 1.0)))

func _make_prompt_icon(coord: Vector2i) -> TextureRect:
	var texture := AtlasTexture.new()
	texture.atlas = INPUT_PROMPT_ATLAS
	texture.region = Rect2(
		coord.x * INPUT_PROMPT_TILE_STRIDE,
		coord.y * INPUT_PROMPT_TILE_STRIDE,
		INPUT_PROMPT_TILE_SIZE,
		INPUT_PROMPT_TILE_SIZE
	)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(INPUT_PROMPT_TILE_SIZE, INPUT_PROMPT_TILE_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _make_hint_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03, 1.0))
	return label
