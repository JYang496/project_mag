extends RefCounted
class_name RewardCardModel

const MAX_PRIMARY_CHIPS := 3

var title := ""
var type_label := ""
var behavior_summary := ""
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
	data.merge({"title": title, "type_label": type_label, "summary_text": behavior_summary,
		"feature_lines": feature_lines,
		"chips": primary_chips(), "synergy_status": synergy_status, "synergy_label": synergy_label,
		"synergy_reason": synergy_reason, "comparison_lines": comparison_lines,
		"followup_text": followup_text, "detail_text": full_detail,
		"detail_bullets": detail_bullets}, true)
	return data
