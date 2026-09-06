extends PanelContainer

const ACTION_SCENE := preload("res://UI/components/WarehouseActionButton/WarehouseActionButton.tscn")

@onready var name_label: Label = %Name
@onready var actions: VBoxContainer = %Actions


func set_data(label_text: String) -> void:
	name_label.text = label_text


func add_action(label_text: String, callback: Callable, unavailable: bool = false) -> void:
	var action := ACTION_SCENE.instantiate() as Button
	actions.add_child(action)
	action.call("set_data", label_text, unavailable)
	action.pressed.connect(callback)
