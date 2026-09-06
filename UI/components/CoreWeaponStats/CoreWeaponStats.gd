extends HBoxContainer

@onready var headings: Array[Label] = [%DamageHeading, %FireIntervalHeading, %AmmoHeading]
@onready var values: Array[Label] = [%DamageValue, %FireIntervalValue, %AmmoValue]


func set_data(items: Array) -> void:
	if headings.is_empty() or headings[0] == null:
		headings = [get_node("CoreStatDamage/Heading"), get_node("CoreStatFireInterval/Heading"), get_node("CoreStatAmmo/Heading")]
		values = [get_node("CoreStatDamage/Value"), get_node("CoreStatFireInterval/Value"), get_node("CoreStatAmmo/Value")]
	for index in range(mini(3, items.size())):
		var item := items[index] as Dictionary
		headings[index].text = str(item.get("heading", ""))
		values[index].text = str(item.get("value", "--"))
		values[index].tooltip_text = values[index].text
