extends RefCounted
class_name WeaponSelectorReadabilityPresenter

const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")

var _slots: Array[Control] = []
var _empty_labels: Array[Label] = []
var _passive_icons: Array[Control] = []

func setup(_root: Control, slots: Array[Control]) -> void:
	_slots = slots
	_empty_labels.resize(_slots.size())
	_passive_icons.resize(_slots.size())
	for slot_index in range(_slots.size()):
		_ensure_slot_decorations(slot_index)

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
