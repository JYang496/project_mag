extends RefCounted
class_name WeaponSelectorReadabilityPresenter

const BADGE := preload("res://UI/scripts/components/weapon_effect_badge.gd")
const WEAPON_DISK_SWAP_OFFSET_Y := 75.0

var _slots: Array[Control] = []
var _empty_labels: Array[Label] = []
var _passive_icons: Array[Control] = []

func setup(_root: Control, slots: Array[Control]) -> void:
	_slots = slots
	_empty_labels.resize(_slots.size())
	_passive_icons.resize(_slots.size())
	for slot_index in range(_slots.size()):
		_ensure_slot_decorations(slot_index)

func update_slot(slot_index: int, weapon: Variant, _is_mainhand: bool) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	var empty_label := _empty_labels[slot_index]
	if empty_label != null:
		empty_label.visible = false
	_slots[slot_index].tooltip_text = ""
	if weapon == null and _passive_icons[slot_index] != null:
		_passive_icons[slot_index].visible = false

func set_passive_visible(_slot_index: int, _visible_value: bool) -> void:
	# Only actionable, ready effects receive a weapon-specific badge.
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

	var passive_icon := BADGE.new() as Control
	passive_icon.name = "PassiveIcon"
	passive_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	passive_icon.position = Vector2(60, 4 + WEAPON_DISK_SWAP_OFFSET_Y)
	passive_icon.size = Vector2(30, 20)
	passive_icon.visible = false
	slot.add_child(passive_icon)
	_passive_icons[slot_index] = passive_icon

func update_passive(slot_index: int, status: Dictionary) -> void:
	var badge := _passive_icons[slot_index]
	var symbols := {
		"machine_gun_heat_expansion": "heat",
		"cannon_idle_fire_triggered": "blast",
		"sniper_far_hit_triggered": "range",
		"shotgun_close_hit_triggered": "blast",
		"glacier_cold_snap_triggered": "cold",
	}
	var id := str(status.get("id", ""))
	var symbol := str(symbols.get(id, ""))
	if str(status.get("trigger_hint", "")) == "reload_started" and symbol.is_empty():
		symbol = "pierce"
	badge.visible = not symbol.is_empty() and bool(status.get("ready", false))
	if badge.visible:
		badge.call("configure", symbol, int(status.get("charge_current", status.get("charges_current", 1))))
