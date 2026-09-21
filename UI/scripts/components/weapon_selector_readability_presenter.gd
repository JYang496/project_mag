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

func update_slot(slot_index: int, weapon: Variant, _is_mainhand: bool) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	if weapon != null:
		_ensure_slot_decorations(slot_index)
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
	if slot_index < 0 or slot_index >= _slots.size():
		return
	var slot := _slots[slot_index]
	var empty_label := slot.get_node_or_null("EmptyLabel") as Label
	if empty_label == null:
		empty_label = EMPTY_LABEL_SCENE.instantiate() as Label
		slot.add_child(empty_label)
	_empty_labels[slot_index] = empty_label

	if _passive_icons[slot_index] == null or not is_instance_valid(_passive_icons[slot_index]):
		var passive_icon := BADGE_SCENE.instantiate() as Control
		passive_icon.name = "PassiveIcon"
		passive_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		passive_icon.position = Vector2(60, 4 + WEAPON_DISK_SWAP_OFFSET_Y)
		passive_icon.size = Vector2(30, 20)
		passive_icon.visible = false
		slot.add_child(passive_icon)
		_passive_icons[slot_index] = passive_icon

func update_passive(slot_index: int, status: Dictionary) -> void:
	_ensure_slot_decorations(slot_index)
	var badge := _passive_icons[slot_index]
	var id := str(status.get("id", ""))
	var supported_ids := [
		"machine_gun_heat_expansion",
		"cannon_idle_fire_triggered",
		"sniper_far_hit_triggered",
		"shotgun_close_hit_triggered",
		"glacier_cold_snap_triggered",
	]
	badge.visible = id in supported_ids
	if not badge.visible:
		return

	var ready := bool(status.get("ready", false))
	var symbol := "fire"
	var amount := 0
	var color := Color("f4bc53")
	if id == "machine_gun_heat_expansion":
		symbol = "reload"
		amount = int(status.get("charge_current", status.get("charges_current", 0)))
		badge.visible = amount > 0
	elif not ready:
		color = Color("83a9b8")
		if str(status.get("trigger_hint", "")) == "weapon_entered_main":
			symbol = "swap"
		else:
			var remaining_sec := _remaining_condition_seconds(status)
			symbol = "timer"
			amount = remaining_sec
	badge.call("configure", symbol, amount, color)


func _remaining_condition_seconds(status: Dictionary) -> int:
	var explicit_remaining := maxf(float(status.get("cooldown_remaining", 0.0)), 0.0)
	if explicit_remaining > 0.001:
		return maxi(int(ceil(explicit_remaining)), 1)
	var required := maxf(float(status.get("required", 0.0)), 0.0)
	var current := maxf(float(status.get("current", 0.0)), 0.0)
	if required <= current + 0.001:
		return 0
	return maxi(int(ceil(required - current)), 1)
