extends VBoxContainer

const DETAIL_TEXT_SCENE := preload("res://UI/components/PurchaseDetailText/PurchaseDetailText.tscn")

@onready var toggle: Button = $Toggle
@onready var body: VBoxContainer = $Body

var _title := ""


func set_data(title: String, lines: PackedStringArray, expanded: bool = false) -> void:
	_title = title
	body.visible = expanded
	_refresh_toggle_text()
	for child in body.get_children():
		child.queue_free()
	for line in lines:
		var label := DETAIL_TEXT_SCENE.instantiate() as Label
		body.add_child(label)
		label.call("set_data", line)


func _on_toggle_pressed() -> void:
	body.visible = not body.visible
	_refresh_toggle_text()


func _refresh_toggle_text() -> void:
	toggle.text = ("▼ " if body.visible else "▶ ") + _title
