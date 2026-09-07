extends RefCounted
class_name WeaponSelectorReadabilityPresenter

const BADGE_SCENE := preload("res://UI/components/WeaponEffectBadge/WeaponEffectBadge.tscn")
const EMPTY_LABEL_SCENE := preload("res://UI/components/WeaponEmptyLabel/WeaponEmptyLabel.tscn")
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
		empty_label = EMPTY_LABEL_SCENE.instantiate() as Label
		slot.add_child(empty_label)
	_empty_labels[slot_index] = empty_label

	var passive_icon := BADGE_SCENE.instantiate() as Control
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
