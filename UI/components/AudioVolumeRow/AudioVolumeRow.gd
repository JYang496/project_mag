extends HBoxContainer

signal value_changed(value: float, bus_name: StringName)

var bus_name: StringName

@onready var name_label: Label = %Name
@onready var slider: HSlider = %Slider
@onready var value_label: Label = %Value


func _ready() -> void:
	slider.value_changed.connect(_on_slider_value_changed)


func set_data(id: StringName, display_name: String, percent: float) -> void:
	bus_name = id
	name_label.text = display_name
	set_value(percent)


func set_label(display_name: String) -> void:
	name_label.text = display_name


func set_value(percent: float) -> void:
	slider.set_value_no_signal(percent)
	value_label.text = "%d%%" % int(round(percent))


func _on_slider_value_changed(percent: float) -> void:
	value_label.text = "%d%%" % int(round(percent))
	value_changed.emit(percent, bus_name)
