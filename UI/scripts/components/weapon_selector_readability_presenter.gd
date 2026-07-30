extends RefCounted
class_name WeaponSelectorReadabilityPresenter

const PASSIVE_ICON_SCRIPT := preload("res://UI/scripts/weapon_passive_icon.gd")

var _root: Control
var _slots: Array[Control] = []
var _empty_labels: Array[Label] = []
var _passive_icons: Array[Control] = []
var _control_hints: Array[Label] = []

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
			Vector2(4.0, 86.0),
			Vector2(158.0, 22.0),
			Color(0.22, 0.62, 0.72, 0.96)
		))
		_control_hints.append(_create_control_hint(
			"ReloadHint",
			Vector2(170.0, 86.0),
			Vector2(158.0, 22.0),
			Color(0.92, 0.62, 0.18, 0.96)
		))
	refresh_copy()

func refresh_copy() -> void:
	if _control_hints.size() >= 2:
		_control_hints[0].text = LocalizationManager.tr_key(
			"ui.weapon_hud.switch_hint",
			"[Q / E]  SWITCH"
		)
		_control_hints[1].text = LocalizationManager.tr_key(
			"ui.weapon_hud.reload_hint",
			"[R]  RELOAD"
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
		var weapon_name := LocalizationManager.get_weapon_instance_display_name(weapon)
		slot.tooltip_text = LocalizationManager.tr_format(
			"ui.weapon_hud.main_tooltip",
			{"weapon": weapon_name},
			"{weapon}\nMAIN WEAPON · R: RELOAD · Q/E: SWITCH"
		)
	else:
		slot.tooltip_text = LocalizationManager.tr_format(
			"ui.weapon_hud.reserve_tooltip",
			{"weapon": LocalizationManager.get_weapon_instance_display_name(weapon)},
			"{weapon}\nRESERVE WEAPON · Q/E: SWITCH"
		)

func set_passive_visible(slot_index: int, visible_value: bool) -> void:
	if slot_index < 0 or slot_index >= _passive_icons.size():
		return
	var passive_icon := _passive_icons[slot_index]
	if passive_icon != null:
		passive_icon.visible = visible_value

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
		empty_label.add_theme_font_size_override("font_size", 15)
		empty_label.add_theme_color_override(
			"font_color",
			Color(0.46, 0.58, 0.64, 0.72)
		)
		empty_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		slot.add_child(empty_label)
	_empty_labels[slot_index] = empty_label

	var passive_icon := slot.get_node_or_null("PassiveIcon") as Control
	if passive_icon == null:
		passive_icon = PASSIVE_ICON_SCRIPT.new() as Control
		passive_icon.name = "PassiveIcon"
		passive_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		passive_icon.position = Vector2(1.0, 73.0)
		passive_icon.size = Vector2(13.0, 13.0)
		passive_icon.z_index = 2
		slot.add_child(passive_icon)
	_passive_icons[slot_index] = passive_icon

func _create_control_hint(
	node_name: String,
	hint_position: Vector2,
	hint_size: Vector2,
	accent: Color
) -> Label:
	var existing := _root.get_node_or_null(node_name) as Label
	if existing != null:
		return existing
	var hint := Label.new()
	hint.name = node_name
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.position = hint_position
	hint.size = hint_size
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_constant_override("outline_size", 1)
	hint.add_theme_color_override("font_color", Color(0.88, 0.95, 0.96, 1.0))
	hint.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.075, 0.9)
	style.border_color = accent
	style.border_width_bottom = 2
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	hint.add_theme_stylebox_override("normal", style)
	hint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_root.add_child(hint)
	return hint
