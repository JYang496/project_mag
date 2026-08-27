extends RefCounted
class_name RewardCardModel

const MAX_PRIMARY_CHIPS := 3

const TYPE_NEW_WEAPON := &"new_weapon"
const TYPE_WEAPON_UPGRADE := &"weapon_upgrade"
const TYPE_WEAPON_CORE := &"weapon_core"
const TYPE_MODULE := &"module"
const TYPE_GENERIC := &"generic"

var reward_type: StringName = TYPE_GENERIC
var title := ""
var type_label := ""
var behavior_summary := ""
var role_summary := ""
var feature_lines := PackedStringArray()
var chips: Array = []
var synergy_status: StringName = &"neutral"
var synergy_label := ""
var synergy_reason := ""
var comparison_lines := PackedStringArray()
var followup_text := ""
var full_detail := ""
var detail_bullets := PackedStringArray()
var visual_data: Dictionary = {}

func primary_chips() -> Array:
	return chips.slice(0, mini(MAX_PRIMARY_CHIPS, chips.size()))

func secondary_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if synergy_reason.strip_edges() != "": lines.append(synergy_reason.strip_edges())
	for line in comparison_lines:
		var normalized := str(line).strip_edges()
		if normalized != "": lines.append(normalized)
	if followup_text.strip_edges() != "": lines.append(followup_text.strip_edges())
	return lines

func is_actionable() -> bool:
	return synergy_status != &"blocked" and synergy_status != &"conflict"

func to_display_data() -> Dictionary:
	var data := visual_data.duplicate(true)
	reward_type = StringName(visual_data.get("reward_type", TYPE_GENERIC))
	var show_all_chips := visual_data.has("compatible_weapons") or reward_type == TYPE_WEAPON_CORE
	var display_chips := chips if show_all_chips else primary_chips()
	var display_summary := "" if reward_type == TYPE_WEAPON_CORE else behavior_summary
	var display_role := "" if reward_type == TYPE_WEAPON_CORE else role_summary
	var display_features := PackedStringArray() if reward_type == TYPE_WEAPON_CORE else feature_lines
	var display_comparisons := PackedStringArray() if reward_type == TYPE_WEAPON_CORE else comparison_lines
	data.merge({"reward_type": reward_type, "title": title, "type_label": type_label, "summary_text": display_summary,
		"role_summary": display_role,
		"feature_lines": display_features,
		"chips": display_chips, "synergy_status": synergy_status, "synergy_label": synergy_label,
		"synergy_reason": synergy_reason, "comparison_lines": display_comparisons,
		"followup_text": followup_text, "detail_text": full_detail,
		"detail_bullets": detail_bullets}, true)
	if reward_type == TYPE_WEAPON_CORE:
		data["core_stat_lines"] = PackedStringArray()
	return data
