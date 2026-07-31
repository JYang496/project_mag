extends Control

const STATES := [
	{"title": "COLD / FIRE RATE UP", "ratio": 0.12, "state": &"extreme_cold", "value": "-76"},
	{"title": "NEUTRAL / BALANCED", "ratio": 0.50, "state": &"neutral", "value": "0"},
	{"title": "HOT / DAMAGE UP", "ratio": 0.88, "state": &"extreme_heat", "value": "+76"},
]

func _ready() -> void:
	for index in STATES.size():
		var entry: Dictionary = STATES[index]
		var panel := VBoxContainer.new()
		panel.position = Vector2(205.0 + index * 330.0, 190.0)
		panel.add_theme_constant_override("separation", 18)
		add_child(panel)

		var title := Label.new()
		title.text = entry.title
		title.custom_minimum_size = Vector2(250.0, 32.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 18)
		panel.add_child(title)

		var meter := CombatResourceMeter.new()
		meter.set_resource(CombatResourceMeter.MODE_HEAT, 0.5, &"neutral", "0")
		panel.add_child(meter)
		meter.set_resource(CombatResourceMeter.MODE_HEAT, entry.ratio, entry.state, entry.value)

