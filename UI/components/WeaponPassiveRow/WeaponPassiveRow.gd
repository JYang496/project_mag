extends VBoxContainer

@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %Name
@onready var state_label: Label = %State
@onready var progress_bar: ProgressBar = %Progress
@onready var detail_label: Label = %Detail


func set_data(data: Dictionary) -> void:
	var is_main := bool(data.get("is_main_weapon", false))
	var passive_name := str(data.get("passive_name", ""))
	var display_name := str(data.get("weapon_name", "Weapon"))
	if not passive_name.is_empty():
		display_name = "%s - %s" % [display_name, passive_name]
	name_label.text = ("* " if is_main else "  ") + display_name
	icon.texture = data.get("icon", null) as Texture2D
	icon.visible = icon.texture != null
	state_label.text = _format_state(str(data.get("state", "inactive")), bool(data.get("ready", false)))
	var progress := float(data.get("progress", -1.0))
	progress_bar.visible = progress >= 0.0
	if progress_bar.visible:
		progress_bar.call("set_target_value", clampf(progress, 0.0, 1.0))
	detail_label.text = _format_detail(data)
	if is_main:
		modulate = Color.WHITE
	elif str(data.get("inactive_reason", "")) == "not_main_weapon":
		modulate = Color(0.65, 0.65, 0.65, 0.82)
	else:
		modulate = Color(0.8, 0.8, 0.8, 0.9)


func _format_state(state: String, ready: bool) -> String:
	if ready: return "Ready"
	return {"charging": "Charging", "ready_pending_action": "Primed", "waiting_refresh": "Refresh", "cooldown": "Cooldown", "inactive": "Inactive"}.get(state, state.capitalize())


func _format_detail(data: Dictionary) -> String:
	var parts: Array[String] = []
	var current: Variant = data.get("current", null)
	var required: Variant = data.get("required", null)
	if current != null and required != null:
		parts.append("%s/%s" % [_format_number(current), _format_number(required)])
	var volley := int(data.get("radial_projectile_count", 0))
	if volley > 0:
		parts.append(LocalizationManager.tr_format("ui.passive.next_radial_volley", {"count": volley}, "Next volley: {count}"))
	var trigger_hint := str(data.get("trigger_hint", ""))
	if not trigger_hint.is_empty(): parts.append(_format_trigger_hint(trigger_hint))
	var refresh_hint := str(data.get("refresh_hint", ""))
	if not refresh_hint.is_empty(): parts.append("refresh: %s" % _format_trigger_hint(refresh_hint))
	var condition_type := str(data.get("condition_type", ""))
	if not condition_type.is_empty() and trigger_hint.is_empty(): parts.append(condition_type)
	var refresh_type := str(data.get("refresh_type", ""))
	if not refresh_type.is_empty() and refresh_hint.is_empty(): parts.append("refresh: %s" % refresh_type)
	var inactive_reason := str(data.get("inactive_reason", ""))
	if not inactive_reason.is_empty(): parts.append(inactive_reason)
	return " | ".join(parts)


func _format_trigger_hint(hint: String) -> String:
	var normalized := hint.strip_edges().to_lower()
	var labels := {"weapon_entered_main": "Weapon Entry", "weapon_entry": "Weapon Entry", "magazine_quarter_spent": "Magazine Quarters", "magazine_cycle": "Magazine Quarters", "reload_started": "Reload Start", "support_charge": "Support Charge", "support": "Support Charge", "cross_weapon_hit": "Crossfire", "crossfire": "Crossfire", "weapon_kill": "Kill Reward", "kill": "Kill Reward", "fire_at_full_global_energy": "Shared Resource Release", "automatic_after_full_energy_attack": "Shared Resource Release"}
	return str(labels.get(normalized, normalized.replace("_", " ").capitalize()))


func _format_number(value: Variant) -> String:
	var number := float(value)
	return str(int(roundf(number))) if is_equal_approx(number, roundf(number)) else "%.1f" % number
