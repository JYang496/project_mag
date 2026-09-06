extends Button

signal selected(branch_id: String)

var branch_id := ""


func _ready() -> void:
	pressed.connect(func() -> void: selected.emit(branch_id))


func set_data(id: String, label_text: String, is_selected: bool) -> void:
	branch_id = id
	text = label_text
	button_pressed = is_selected
