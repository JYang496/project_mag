extends Control

const METER_SCENE := preload("res://UI/components/CombatResourceMeter/CombatResourceMeter.tscn")
const STATES: Array[Dictionary] = [
	{"title": "COLD MAX", "ratio": 0.00, "state": &"extreme_cold", "value": "-100"},
	{"title": "COLD PARTIAL", "ratio": 0.38, "state": &"cold", "value": "-24"},
	{"title": "NEUTRAL", "ratio": 0.50, "state": &"neutral", "value": "0"},
	{"title": "HOT PARTIAL", "ratio": 0.62, "state": &"hot", "value": "+24"},
	{"title": "HOT MAX", "ratio": 1.00, "state": &"extreme_heat", "value": "+100"},
]

func _ready() -> void:
	for index in STATES.size():
		var entry: Dictionary = STATES[index]
		var panel := VBoxContainer.new()
		panel.position = Vector2(25.0 + index * 245.0, 190.0)
		panel.add_theme_constant_override("separation", 18)
		add_child(panel)
		var title := Label.new()
		title.text = str(entry.title)
		title.custom_minimum_size = Vector2(218.0, 32.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 18)
		panel.add_child(title)
		var meter = METER_SCENE.instantiate()
		panel.add_child(meter)
		meter.set_resource(&"heat", float(entry.ratio), StringName(entry.state), str(entry.value))
