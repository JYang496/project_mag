extends RefCounted
class_name WeaponSelectorPassivePresenter

const FOOTER_TOP := 74.0
const FOOTER_HEIGHT := 11.0
const SKILL_ICON_GUTTER := 16.0
const FOOTER_RIGHT_INSET := 2.0

var _palette: Dictionary = {}

func setup(palette: Dictionary) -> void:
	_palette = palette.duplicate()

func resolve_state(weapon: Variant) -> Dictionary:
	var output := {
		"kind": "unavailable",
		"progress": 1.0,
		"visible": true,
		"ready": false,
		"charge_current": 0,
		"charge_max": 0,
		"charge_states": [],
		"cycle_progress": 0.0,
		"cycle_visible": false,
		"cycle_thresholds": [],
		"display_mode": &"hidden",
	}
	if weapon == null or not is_instance_valid(weapon) \
			or not weapon.has_method("get_passive_status"):
		output["visible"] = false
		return output
	var status_variant: Variant = weapon.call("get_passive_status")
	if not (status_variant is Dictionary):
		output["visible"] = false
		return output
	var status := status_variant as Dictionary
	var state := str(status.get("state", "inactive"))
	var passive_id := str(status.get("id", ""))
	if passive_id.is_empty() or state == "unavailable":
		output["visible"] = false
		return output
	var is_ready := bool(status.get("ready", false))
	var charge_max := int(status.get("charge_max", status.get("charges_max", 1)))
	var charge_current := int(status.get(
		"charge_current",
		status.get("charges_current", 1 if is_ready else 0)
	))
	output["charge_max"] = maxi(charge_max, 0)
	output["charge_current"] = clampi(charge_current, 0, maxi(charge_max, 0))
	output["charge_states"] = _resolve_charge_states(status, charge_max, charge_current)
	output["display_mode"] = &"segmented" if charge_max > 0 else &"hidden"
	output["ready"] = is_ready or state in ["ready_pending_action", "ready"]
	var progress := clampf(float(status.get("progress", 1.0)), 0.0, 1.0)
	output["progress"] = progress
	var has_explicit_condition := bool(status.get("condition_visible", false))
	output["cycle_visible"] = has_explicit_condition
	output["cycle_progress"] = clampf(
		float(status.get("condition_progress", progress)),
		0.0,
		1.0
	)
	output["cycle_thresholds"] = status.get("condition_thresholds", []).duplicate()
	if bool(output["ready"]):
		output["kind"] = "ready"
	elif state in ["cooldown", "waiting_refresh"]:
		output["kind"] = "cooldown"
		output["progress"] = maxf(progress, 0.08)
	elif state in ["charging", "active"] or (progress > 0.0 and progress < 1.0):
		output["kind"] = "progress"
	return output

func _resolve_charge_states(status: Dictionary, charge_max: int, charge_current: int) -> Array[String]:
	var output: Array[String] = []
	var explicit_states: Array = status.get("charge_states", [])
	for index in range(maxi(charge_max, 0)):
		var state := "ready" if index < charge_current else "spent"
		if index < explicit_states.size():
			var requested := str(explicit_states[index])
			if requested in ["ready", "active", "spent"]:
				state = requested
		output.append(state)
	return output

func layout_status(
	status_node: Control,
	charge_node: Control,
	slot_node: Control,
	visual_state: Dictionary,
	is_animating: bool
) -> void:
	if slot_node == null:
		return
	var footer_position := slot_node.position + Vector2(SKILL_ICON_GUTTER, FOOTER_TOP)
	var footer_size := Vector2(
		maxf(slot_node.size.x - SKILL_ICON_GUTTER - FOOTER_RIGHT_INSET, 1.0),
		FOOTER_HEIGHT
	)
	for node in [status_node, charge_node]:
		if node == null:
			continue
		node.position = footer_position
		node.size = footer_size
		node.pivot_offset = footer_size * 0.5
		node.scale = Vector2(0.96, 0.96) if is_animating else Vector2.ONE

func apply_charge(charge_node: Control, visual_state: Dictionary) -> void:
	if charge_node == null:
		return
	var charge_max := maxi(int(visual_state.get("charge_max", 0)), 0)
	var is_segmented := StringName(visual_state.get("display_mode", &"hidden")) == &"segmented"
	if not is_segmented or not bool(visual_state.get("visible", true)):
		charge_node.visible = false
		return
	charge_node.visible = true
	charge_node.set("max_charges", charge_max)
	charge_node.set("charge_states", visual_state.get("charge_states", []))
	charge_node.set(
		"current_charges",
		clampi(int(visual_state.get("charge_current", 0)), 0, charge_max)
	)
	charge_node.set("show_cycle_progress", bool(visual_state.get("cycle_visible", false)))
	charge_node.set(
		"cycle_progress",
		clampf(float(visual_state.get("cycle_progress", 0.0)), 0.0, 1.0)
	)
	charge_node.set("cycle_thresholds", visual_state.get("cycle_thresholds", []))

func apply_status(
	passive_node: Control,
	glow_node: Control,
	visual_state: Dictionary,
	is_animating: bool
) -> void:
	if passive_node == null:
		return
	var should_show := false
	passive_node.visible = should_show
	if glow_node != null and is_instance_valid(glow_node):
		glow_node.position = passive_node.position
		glow_node.size = passive_node.size
	if not should_show:
		return
	var kind := str(visual_state.get("kind", "unavailable"))
	var progress := clampf(float(visual_state.get("progress", 0.0)), 0.0, 1.0)
	passive_node.scale = Vector2(0.96, 0.96) if is_animating else Vector2.ONE
	match kind:
		"ready":
			_set_status(passive_node, 1.0, "ready", "progress_base", true, 1.0)
		"cooldown":
			_set_status(passive_node, progress, "cooldown", "cooldown_base", false, 0.82)
		"progress":
			_set_status(passive_node, progress, "progress", "progress_base", true, 0.94)
		_:
			_set_status(passive_node, 1.0, "unavailable", "unavailable_base", true, 0.56)

func _set_status(
	node: Control,
	progress: float,
	fill_key: String,
	base_key: String,
	clockwise: bool,
	alpha: float
) -> void:
	node.modulate = Color(1.0, 1.0, 1.0, alpha)
	node.set("progress", progress)
	node.set("fill_color", _palette[fill_key])
	node.set("base_color", _palette[base_key])
	node.set("clockwise", clockwise)
