extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
var _failed := false

func _ready() -> void:
	_validate_catalog("res://data/weapon_branches", 30)
	_validate_catalog("res://data/weapon_passives", 18)
	_validate_catalog("res://data/battle_contracts", 8)
	_validate_aliases_and_display()
	_validate_evaluator()
	print("FAIL build synergy semantics" if _failed else "PASS build synergy semantics")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _validate_catalog(directory: String, expected_count: int) -> void:
	var count := 0
	for file_name in DirAccess.get_files_at(directory):
		if not file_name.ends_with(".tres"):
			continue
		count += 1
		var resource := load("%s/%s" % [directory, file_name])
		_expect(resource != null, "%s must load" % file_name)
		if resource == null:
			continue
		var combined: Array = []
		for property_name in [&"produces_tags", &"requires_any_tags", &"requires_all_tags", &"amplifies_tags", &"conflicts_with_tags"]:
			var values: Variant = resource.get(property_name)
			combined.append_array(values)
			_expect(BuildTag.unknown_values(values).is_empty(), "%s.%s contains unknown tags" % [file_name, property_name])
		_expect(not resource.produces_tags.is_empty(), "%s must declare at least one produced tag" % file_name)
	_expect(count == expected_count, "%s must contain %d definitions, found %d" % [directory, expected_count, count])

func _validate_aliases_and_display() -> void:
	_expect(BuildTag.normalize(&"reload") == &"on_reload", "legacy reload must normalize to on_reload")
	_expect(BuildTag.normalize(&"area_damage") == &"area", "legacy area_damage must normalize to area")
	var chip := BuildTagDisplay.build_tag_chip(&"reload")
	_expect(chip.get("source_key") == "on_reload", "UI chip must consume canonical BuildTag keys")
	_expect(chip.get("icon_key") == "reload", "canonical tag presentation must retain its configured icon")
	var fallback := BuildTagDisplay.build_tag_chip(&"not_a_real_tag")
	_expect(fallback.get("status") == BuildTagDisplay.STATUS_FALLBACK, "unknown UI tags must remain visible as fallback chips")

func _validate_evaluator() -> void:
	var candidate := WeaponBranchDefinition.new()
	candidate.produces_tags = [&"freeze"]
	candidate.requires_all_tags = [&"projectile"]
	candidate.requires_any_tags = [&"on_hit", &"on_reload"]
	candidate.amplifies_tags = [&"mark"]
	candidate.conflicts_with_tags = [&"fire"]
	_expect(_status([&"projectile", &"on_hit"], candidate) == SynergyEvaluator.Status.DIRECT_FIT, "matching all/any requirements must be direct fit")
	_expect(_status([&"projectile"], candidate) == SynergyEvaluator.Status.PARTIAL_FIT, "matching only part of the requirements must be partial fit")
	_expect(_status([&"defense"], candidate) == SynergyEvaluator.Status.BLOCKED, "matching no requirements must be blocked")
	_expect(_status([&"projectile", &"on_hit", &"fire"], candidate) == SynergyEvaluator.Status.CONFLICT, "conflicts must take precedence")
	var neutral := WeaponBranchDefinition.new()
	neutral.produces_tags = [&"area"]
	_expect(_status([], neutral) == SynergyEvaluator.Status.NEUTRAL, "independent content must be neutral")
	var downstream := WeaponPassiveBranchDefinition.new()
	downstream.produces_tags = [&"control"]
	downstream.requires_all_tags = [&"freeze"]
	var result := SynergyEvaluator.evaluate([&"projectile", &"on_hit"], candidate, [downstream])
	_expect(int(result.status) == SynergyEvaluator.Status.UNLOCKS_CHAIN, "a produced tag that satisfies downstream content must unlock a chain")

func _status(tags: Array, candidate: Object) -> int:
	return int(SynergyEvaluator.evaluate(tags, candidate).status)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
