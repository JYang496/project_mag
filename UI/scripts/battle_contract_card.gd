extends Button

const BattleContractDefinition = preload("res://Combat/battle_contract/BattleContractDefinition.gd")

var definition: BattleContractDefinition

func setup(value: BattleContractDefinition) -> void:
	definition = value
	var id := str(definition.contract_id)
	$Margin/Content/Title.text = LocalizationManager.tr_key(definition.name_key, id.capitalize())
	$Margin/Content/Description.text = LocalizationManager.tr_key(definition.description_key, "Complete the contract objective.")
	$Margin/Content/Pace.text = LocalizationManager.tr_key("battle_contract.%s.pace" % id, "Standard combat pace")
	$Margin/Content/Tags.text = LocalizationManager.tr_key("battle_contract.ui.build_tags" , "Build tags: {tags}").format({"tags": ", ".join(definition.build_tags)})
	$Margin/Content/Reward.text = LocalizationManager.tr_key("battle_contract.%s.reward" % id, "Small performance reward")
	modulate = definition.accent_color.lightened(0.25)
