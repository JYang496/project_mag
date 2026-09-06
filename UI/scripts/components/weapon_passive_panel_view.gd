extends RefCounted
class_name WeaponPassivePanelView

const PANEL_SCENE := preload("res://UI/components/WeaponPassivePanel/WeaponPassivePanel.tscn")
const ROW_SCENE := preload("res://UI/components/WeaponPassiveRow/WeaponPassiveRow.tscn")

var parent_root: Control
var weapon_passive_panel: PanelContainer
var weapon_passive_list: VBoxContainer
var weapon_passive_rows: Array[Dictionary] = []
var show_panel: bool = false

func bind(root: Control) -> void:
	parent_root = root

func ensure_panel() -> PanelContainer:
	if weapon_passive_panel != null and is_instance_valid(weapon_passive_panel):
		return weapon_passive_panel
	if parent_root == null or not is_instance_valid(parent_root):
		return null
	weapon_passive_panel = PANEL_SCENE.instantiate() as PanelContainer
	parent_root.add_child(weapon_passive_panel)
	weapon_passive_list = weapon_passive_panel.get_node("RowList") as VBoxContainer
	return weapon_passive_panel

func refresh(statuses: Array) -> void:
	ensure_panel()
	if weapon_passive_panel == null or weapon_passive_list == null:
		return
	weapon_passive_panel.visible = show_panel and not statuses.is_empty()
	ensure_row_count(statuses.size())
	for idx in range(weapon_passive_rows.size()):
		var row := weapon_passive_rows[idx]
		var root := row.get("root", null) as Control
		if root == null:
			continue
		if idx >= statuses.size():
			root.visible = false
			continue
		root.visible = true
		root.call("set_data", statuses[idx])

func ensure_row_count(count: int) -> void:
	if weapon_passive_list == null:
		return
	while weapon_passive_rows.size() < count:
		weapon_passive_rows.append(create_row())

func create_row() -> Dictionary:
	var row_root := ROW_SCENE.instantiate() as VBoxContainer
	weapon_passive_list.add_child(row_root)
	return {"root": row_root}

func apply_row(row: Dictionary, status: Dictionary) -> void:
	var root := row.get("root", null) as Control
	var icon_rect := row.get("icon", null) as TextureRect
	var name_label := row.get("name", null) as Label
	var state_label := row.get("state", null) as Label
	var progress_bar := row.get("progress", null) as ProgressBar
	var detail_label := row.get("detail", null) as Label
	if root == null or name_label == null or state_label == null or progress_bar == null or detail_label == null:
		return
	var is_main := bool(status.get("is_main_weapon", false))
	var state := str(status.get("state", "inactive"))
	var ready := bool(status.get("ready", false))
	var weapon_prefix := "* " if is_main else "  "
	var passive_name := str(status.get("passive_name", ""))
	var name_text := str(status.get("weapon_name", "Weapon"))
	if passive_name != "":
		name_text = "%s - %s" % [name_text, passive_name]
	name_label.text = weapon_prefix + name_text
	if icon_rect != null:
		var icon_variant: Variant = status.get("icon", null)
		icon_rect.texture = icon_variant as Texture2D
		icon_rect.visible = icon_rect.texture != null
	state_label.text = format_state(state, ready)
	var progress := float(status.get("progress", -1.0))
	progress_bar.visible = progress >= 0.0
	if progress_bar.visible:
		progress_bar.call("set_target_value", clampf(progress, 0.0, 1.0))
	detail_label.text = format_detail(status)
	if is_main:
		root.modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif str(status.get("inactive_reason", "")) == "not_main_weapon":
		root.modulate = Color(0.65, 0.65, 0.65, 0.82)
	else:
		root.modulate = Color(0.8, 0.8, 0.8, 0.9)

func format_state(state: String, ready: bool) -> String:
	if ready:
		return "Ready"
	match state:
		"charging":
			return "Charging"
		"ready_pending_action":
			return "Primed"
		"waiting_refresh":
			return "Refresh"
		"cooldown":
			return "Cooldown"
		"inactive":
			return "Inactive"
		_:
			return state.capitalize()

func format_detail(status: Dictionary) -> String:
	var parts: Array[String] = []
	var current: Variant = status.get("current", null)
	var required: Variant = status.get("required", null)
	if current != null and required != null:
		parts.append("%s/%s" % [format_number(current), format_number(required)])
	var radial_projectile_count := int(status.get("radial_projectile_count", 0))
	if radial_projectile_count > 0:
		parts.append(LocalizationManager.tr_format(
			"ui.passive.next_radial_volley",
			{"count": radial_projectile_count},
			"Next volley: {count}"
		))
	var trigger_hint := str(status.get("trigger_hint", ""))
	if trigger_hint != "":
		parts.append(format_trigger_hint(trigger_hint))
	var refresh_hint := str(status.get("refresh_hint", ""))
	if refresh_hint != "":
		parts.append("refresh: %s" % format_trigger_hint(refresh_hint))
	var condition_type := str(status.get("condition_type", ""))
	if condition_type != "" and trigger_hint == "":
		parts.append(condition_type)
	var refresh_type := str(status.get("refresh_type", ""))
	if refresh_type != "" and refresh_hint == "":
		parts.append("refresh: %s" % refresh_type)
	var inactive_reason := str(status.get("inactive_reason", ""))
	if inactive_reason != "":
		parts.append(inactive_reason)
	return " | ".join(parts)

func format_trigger_hint(hint: String) -> String:
	var normalized := hint.strip_edges().to_lower()
	var labels := {
		"weapon_entered_main": "Weapon Entry",
		"weapon_entry": "Weapon Entry",
		"magazine_quarter_spent": "Magazine Quarters",
		"magazine_cycle": "Magazine Quarters",
		"reload_started": "Reload Start",
		"support_charge": "Support Charge",
		"support": "Support Charge",
		"cross_weapon_hit": "Crossfire",
		"crossfire": "Crossfire",
		"weapon_kill": "Kill Reward",
		"kill": "Kill Reward",
		"fire_at_full_global_energy": "Shared Resource Release",
		"automatic_after_full_energy_attack": "Shared Resource Release",
	}
	return str(labels.get(normalized, normalized.replace("_", " ").capitalize()))

func format_number(value: Variant) -> String:
	var number := float(value)
	if is_equal_approx(number, roundf(number)):
		return str(int(roundf(number)))
	return "%.1f" % number

func set_panel_visible(visible: bool) -> void:
	show_panel = visible
	if weapon_passive_panel != null and is_instance_valid(weapon_passive_panel):
		weapon_passive_panel.visible = visible and weapon_passive_rows.size() > 0
