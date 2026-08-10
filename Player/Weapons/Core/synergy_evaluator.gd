extends RefCounted
class_name SynergyEvaluator

enum Status { DIRECT_FIT, UNLOCKS_CHAIN, PARTIAL_FIT, NEUTRAL, BLOCKED, CONFLICT }

static func evaluate(current_tags: Variant, candidate: Object, downstream_candidates: Array = []) -> Dictionary:
	var current := BuildTag.normalize_array(current_tags)
	var produces := _read(candidate, &"produces_tags")
	var requires_any := _read(candidate, &"requires_any_tags")
	var requires_all := _read(candidate, &"requires_all_tags")
	var amplifies := _read(candidate, &"amplifies_tags")
	var conflicts := _read(candidate, &"conflicts_with_tags")
	var conflicting := _intersection(current, conflicts)
	if not conflicting.is_empty():
		return _result(Status.CONFLICT, conflicting, produces)
	var matched_all := _intersection(current, requires_all)
	var matched_any := _intersection(current, requires_any)
	var all_met := matched_all.size() == requires_all.size()
	var any_met := requires_any.is_empty() or not matched_any.is_empty()
	if not all_met or not any_met:
		var partial := not matched_all.is_empty() or not matched_any.is_empty()
		return _result(Status.PARTIAL_FIT if partial else Status.BLOCKED, matched_all + matched_any, produces)
	for downstream in downstream_candidates:
		if _would_unlock(current, produces, downstream):
			return _result(Status.UNLOCKS_CHAIN, produces, produces)
	var matched_amplifies := _intersection(current, amplifies)
	if not requires_all.is_empty() or not requires_any.is_empty() or not matched_amplifies.is_empty():
		return _result(Status.DIRECT_FIT, matched_all + matched_any + matched_amplifies, produces)
	return _result(Status.NEUTRAL, [], produces)

static func status_name(status: int) -> StringName:
	return [&"DIRECT_FIT", &"UNLOCKS_CHAIN", &"PARTIAL_FIT", &"NEUTRAL", &"BLOCKED", &"CONFLICT"][clampi(status, 0, 5)]

static func _read(source: Object, property_name: StringName) -> Array[StringName]:
	if source == null:
		return []
	for property_info in source.get_property_list():
		if StringName(property_info.get("name", "")) == property_name:
			return BuildTag.normalize_array(source.get(property_name))
	return []

static func _would_unlock(current: Array[StringName], produces: Array[StringName], candidate: Object) -> bool:
	var before := evaluate(current, candidate)
	if int(before.status) != Status.BLOCKED and int(before.status) != Status.PARTIAL_FIT:
		return false
	var combined := current.duplicate()
	for tag in produces:
		if not combined.has(tag):
			combined.append(tag)
	var after := evaluate(combined, candidate)
	return int(after.status) == Status.DIRECT_FIT or int(after.status) == Status.NEUTRAL

static func _intersection(left: Array[StringName], right: Array[StringName]) -> Array[StringName]:
	var output: Array[StringName] = []
	for value in right:
		if left.has(value) and not output.has(value):
			output.append(value)
	return output

static func _result(status: int, matched: Array, produces: Array[StringName]) -> Dictionary:
	return {"status": status, "status_name": status_name(status), "matched_tags": matched, "produces_tags": produces}

