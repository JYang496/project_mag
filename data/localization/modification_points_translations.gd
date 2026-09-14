extends RefCounted

const MESSAGES := {
	"ui.modification.balance": ["Modification points: {value}", "改装点：{value}"],
	"ui.modification.cost": ["Cost: {value} modification points", "消耗：{value} 改装点"],
	"ui.modification.amount": ["{value} modification points", "{value} 改装点"],
	"ui.modification.action": ["Upgrade: {value} modification points", "强化：{value} 改装点"],
	"ui.modification.insufficient": ["Not enough modification points.", "改装点不足。"],
	"ui.modification.hint": ["Granted once per new rest area. Unspent points carry over within this run.", "每个新休息区发放一次，剩余改装点可在本局后续休息区使用。"],
}

static func register() -> void:
	var locales := ["en", "zh_CN"]
	for index in range(locales.size()):
		var translation := Translation.new()
		translation.set_locale(locales[index])
		for key in MESSAGES:
			translation.add_message(key, MESSAGES[key][index])
		TranslationServer.add_translation(translation)
