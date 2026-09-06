extends HBoxContainer

signal amount_changed(key: String, delta: int)

var core_key := ""

@onready var info: Label = %Info
@onready var minus: Button = %Minus
@onready var plus: Button = %Plus


func _ready() -> void:
	minus.pressed.connect(func() -> void: amount_changed.emit(core_key, -1))
	plus.pressed.connect(func() -> void: amount_changed.emit(core_key, 1))


func set_data(data: Dictionary) -> void:
	core_key = str(data.get("key", ""))
	info.text = str(data.get("text", ""))
	minus.disabled = not bool(data.get("can_remove", false))
	plus.disabled = not bool(data.get("can_add", false))
	plus.tooltip_text = str(data.get("tooltip", ""))
