extends RefCounted
class_name WeaponPassivePanelView

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
	weapon_passive_panel = PanelContainer.new()
	weapon_passive_panel.name = "WeaponPassivePanel"
	weapon_passive_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_passive_panel.position = Vector2(224.0, 8.0)
	weapon_passive_panel.custom_minimum_size = Vector2(300.0, 0.0)
	weapon_passive_panel.visible = false
	parent_root.add_child(weapon_passive_panel)
	weapon_passive_list = VBoxContainer.new()
	weapon_passive_list.name = "WeaponPassiveList"
	weapon_passive_list.add_theme_constant_override("separation", 4)
	weapon_passive_panel.add_child(weapon_passive_list)
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
		apply_row(row, statuses[idx])

func ensure_row_count(count: int) -> void:
	if weapon_passive_list == null:
		return
	while weapon_passive_rows.size() < count:
		weapon_passive_rows.append(create_row())

func create_row() -> Dictionary:
	var row_root := VBoxContainer.new()
	row_root.name = "WeaponPassiveRow"
	row_root.custom_minimum_size = Vector2(288.0, 0.0)
	row_root.add_theme_constant_override("separation", 1)
	weapon_passive_list.add_child(row_root)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 6)
	row_root.add_child(header)

	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(18.0, 18.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon_rect)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	header.add_child(name_label)

	var state_label := Label.new()
	state_label.name = "State"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.custom_minimum_size = Vector2(98.0, 0.0)
	header.add_child(state_label)

	var progress_bar := ProgressBar.new()
	progress_bar.name = "Progress"
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.step = 0.001
	progress_bar.custom_minimum_size = Vector2(0.0, 8.0)
	progress_bar.show_percentage = false
	row_root.add_child(progress_bar)

	var detail_label := Label.new()
	detail_label.name = "Detail"
	detail_label.clip_text = true
	detail_label.add_theme_font_size_override("font_size", 11)
	row_root.add_child(detail_label)

	return {
		"root": row_root,
		"icon": icon_rect,
		"name": name_label,
		"state": state_label,
		"progress": progress_bar,
		"detail": detail_label,
	}

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
		progress_bar.value = clampf(progress, 0.0, 1.0)
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
		parts.append(trigger_hint)
	var refresh_hint := str(status.get("refresh_hint", ""))
	if refresh_hint != "":
		parts.append("refresh: %s" % refresh_hint)
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

func format_number(value: Variant) -> String:
	var number := float(value)
	if is_equal_approx(number, roundf(number)):
		return str(int(roundf(number)))
	return "%.1f" % number

func set_panel_visible(visible: bool) -> void:
	show_panel = visible
	if weapon_passive_panel != null and is_instance_valid(weapon_passive_panel):
		weapon_passive_panel.visible = visible and weapon_passive_rows.size() > 0
