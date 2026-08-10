extends Node

const BUILDER := preload("res://UI/scripts/presentation/reward_card_model_builder.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

func _ready() -> void:
	var chips: Array = []
	for index in range(5):
		chips.append({"source_key": "tag_%d" % index, "label": "Tag %d" % index})
	var model: Variant = BUILDER.build({
		"title": "Thermal Relay",
		"type_label": "Module",
		"summary_text": "Overheating releases a pulse.",
		"feature_lines": PackedStringArray(["Consumes all heat", "Damages nearby enemies", "Hidden overflow"]),
		"chips": chips,
		"detail_text": "Full trigger rules and exact duration.",
		"detail_bullets": PackedStringArray(["Exact value: 20%", "Duration: 3s"]),
		"outcome_text": "Choose a target weapon next",
	}, {
		"status": &"blocked",
		"reason": "No equipped weapon can overheat.",
		"comparison_lines": PackedStringArray(["Current triggers: 0"]),
	})
	assert(model.behavior_summary == "Overheating releases a pulse.")
	assert(model.feature_lines == PackedStringArray(["Consumes all heat", "Damages nearby enemies"]))
	assert(model.primary_chips().size() == 3)
	assert(model.synergy_status == &"blocked")
	assert(model.synergy_label.contains("BLOCKED"))
	assert(model.synergy_reason == "No equipped weapon can overheat.")
	assert(model.followup_text == "Choose a target weapon next")
	assert(model.secondary_lines().size() == 3)
	assert(model.full_detail == "Full trigger rules and exact duration.")
	assert(not model.is_actionable())
	var core_evaluator_result: Variant = BUILDER.build({"title": "Chain"}, {"status": 1, "status_name": &"UNLOCKS_CHAIN"})
	assert(core_evaluator_result.synergy_status == &"unlocks_chain")

	var unknown: Variant = BUILDER.build({"title": "Supply"}, {"status": &"future_status"})
	assert(unknown.synergy_status == &"neutral")
	assert(unknown.synergy_label == "")
	var explicit_neutral: Variant = BUILDER.build({"title": "Supply"}, {"status": &"neutral", "label": "STANDALONE · No build requirement"})
	assert(explicit_neutral.synergy_label == "")
	print("PASS: reward card model preserves three information layers and accessible synergy states")
	await TEST_TEARDOWN.finish(self, 0)
