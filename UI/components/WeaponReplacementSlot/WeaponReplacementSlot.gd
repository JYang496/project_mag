extends Button

@onready var slot_label: Label = %SlotLabel
@onready var icon_host: Control = %IconHost
@onready var name_label: Label = %WeaponName
@onready var meta_label: Label = %WeaponMeta
@onready var action_label: Label = %Action
@onready var comparison: HFlowContainer = %Comparison
@onready var warning_label: Label = %Warning


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	var slot_index := int(data.get("slot_index", -1))
	name = "WeaponSlot%d" % (slot_index + 1)
	set_meta("slot_index", slot_index)
	set_meta("action_label", action_label)
	custom_minimum_size.y = float(data.get("height", 96.0))
	slot_label.text = str(data.get("slot_label", ""))
	name_label.text = str(data.get("name", ""))
	meta_label.text = str(data.get("meta", ""))
	action_label.text = str(data.get("action", ""))
	var warning := str(data.get("warning", ""))
	warning_label.text = warning
	warning_label.visible = not warning.is_empty()
	comparison.visible = bool(data.get("show_comparison", false))
	set_accent(data.get("accent", Color.WHITE) as Color)


func set_icon(icon: Control) -> void:
	_resolve_nodes()
	for child in icon_host.get_children():
		child.queue_free()
	icon_host.add_child(icon)


func get_comparison_root() -> HFlowContainer:
	_resolve_nodes()
	return comparison


func set_accent(accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := get_theme_stylebox(state).duplicate() as StyleBoxFlat
		var border := accent
		border.a = 0.9 if state == "focus" else 0.5
		style.border_color = border
		add_theme_stylebox_override(state, style)


func _resolve_nodes() -> void:
	if slot_label != null:
		return
	slot_label = get_node("Margin/Content/Row/SlotLabel") as Label
	icon_host = get_node("Margin/Content/Row/IconHost") as Control
	name_label = get_node("Margin/Content/Row/Text/WeaponName") as Label
	meta_label = get_node("Margin/Content/Row/Text/WeaponMeta") as Label
	action_label = get_node("Margin/Content/Row/Action") as Label
	comparison = get_node("Margin/Content/Comparison") as HFlowContainer
	warning_label = get_node("Margin/Content/Warning") as Label
