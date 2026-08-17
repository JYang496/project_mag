extends RefCounted
class_name RewardCardModelBuilder

const MODEL := preload("res://UI/scripts/presentation/reward_card_model.gd")
const STATUS_FALLBACKS := {
	&"direct_fit": "MATCH · Ready now", &"unlocks_chain": "UNLOCKS · Activates a synergy",
	&"partial_fit": "PARTIAL · Needs another trigger", &"neutral": "",
	&"blocked": "BLOCKED · Cannot trigger now", &"conflict": "CONFLICT · Replaces or disables an effect",
}

static func build(legacy_data: Dictionary, synergy_result: Dictionary = {}):
	var model = MODEL.new()
	model.visual_data = legacy_data.duplicate(true)
	model.title = str(legacy_data.get("title", "Reward"))
	model.type_label = str(legacy_data.get("type_label", "Reward"))
	model.behavior_summary = _first_non_empty([legacy_data.get("summary_text", ""), legacy_data.get("detail_text", ""), model.title])
	model.role_summary = str(legacy_data.get("role_summary", "")).strip_edges()
	model.feature_lines = _packed_lines(legacy_data.get("feature_lines", PackedStringArray())).slice(0, 2)
	model.chips = _normalized_chips(legacy_data.get("chips", []))
	model.full_detail = str(legacy_data.get("detail_text", "")).strip_edges()
	model.detail_bullets = _packed_lines(legacy_data.get("detail_bullets", PackedStringArray()))
	model.comparison_lines = _packed_lines(synergy_result.get("comparison_lines", legacy_data.get("comparison_lines", PackedStringArray())))
	model.followup_text = str(synergy_result.get("followup_text", legacy_data.get("followup_text", legacy_data.get("outcome_text", "")))).strip_edges()
	var status_value: Variant = synergy_result.get("status_name", synergy_result.get("status", legacy_data.get("synergy_status", &"neutral")))
	model.synergy_status = _normalize_status(status_value)
	model.synergy_reason = str(synergy_result.get("reason", legacy_data.get("synergy_reason", ""))).strip_edges()
	model.synergy_label = str(synergy_result.get("label", legacy_data.get("synergy_label", ""))).strip_edges()
	if model.synergy_status == &"neutral":
		model.synergy_label = ""
	elif model.synergy_label == "":
		model.synergy_label = str(STATUS_FALLBACKS.get(model.synergy_status, ""))
	return model

static func _normalize_status(value: Variant) -> StringName:
	var normalized := StringName(str(value).strip_edges().to_lower())
	return normalized if STATUS_FALLBACKS.has(normalized) else &"neutral"

static func _normalized_chips(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for chip in value:
			if chip is Dictionary and not (chip as Dictionary).is_empty(): result.append((chip as Dictionary).duplicate(true))
	return result

static func _packed_lines(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if value is PackedStringArray or value is Array:
		for line in value:
			var normalized := str(line).strip_edges()
			if normalized != "": result.append(normalized)
	return result

static func _first_non_empty(values: Array) -> String:
	for value in values:
		var normalized := str(value).strip_edges()
		if normalized != "": return normalized.split("\n", false, 1)[0]
	return ""
