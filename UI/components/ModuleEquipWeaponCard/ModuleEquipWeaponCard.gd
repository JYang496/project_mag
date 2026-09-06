extends PanelContainer

signal equip_pressed

const SOCKET_SCENE := preload("res://UI/components/ModuleSocket/ModuleSocket.tscn")

@onready var weapon_icon: TextureRect = %WeaponIcon
@onready var name_label: Label = %Name
@onready var fit_label: Label = %Fit
@onready var reason_label: Label = %Reason
@onready var pulse_bar: ColorRect = %PulseBar
@onready var stat_label: RichTextLabel = %Stats
@onready var modules_label: Label = %ModulesLabel
@onready var sockets: HBoxContainer = %Sockets
@onready var equip_button: Button = %EquipButton


func _ready() -> void:
	equip_button.pressed.connect(func() -> void: equip_pressed.emit())


func set_data(data: Dictionary) -> void:
	weapon_icon.texture = data.get("icon") as Texture2D
	weapon_icon.modulate = Color.WHITE if bool(data.get("available", false)) else Color(0.46, 0.49, 0.50, 0.62)
	name_label.text = str(data.get("name", ""))
	fit_label.text = str(data.get("fit", ""))
	fit_label.add_theme_color_override("font_color", data.get("fit_color", Color.WHITE) as Color)
	reason_label.text = str(data.get("reason", ""))
	reason_label.visible = not reason_label.text.is_empty()
	stat_label.text = str(data.get("stats", ""))
	modules_label.text = str(data.get("modules_label", ""))
	equip_button.text = str(data.get("action", ""))
	equip_button.disabled = not bool(data.get("available", false))
	var panel_style := data.get("panel_style") as StyleBox
	if panel_style != null:
		add_theme_stylebox_override("panel", panel_style)


func set_sockets(items: Array, occupied_color: Color, empty_color: Color) -> void:
	for child in sockets.get_children():
		child.queue_free()
	for index in range(items.size()):
		var item := items[index] as Dictionary
		var socket := SOCKET_SCENE.instantiate() as Control
		sockets.add_child(socket)
		socket.call("set_data", index, item.get("icon") as Texture2D, str(item.get("tooltip", "")), bool(item.get("occupied", false)), occupied_color, empty_color)


func start_pulse(duration: float) -> void:
	var tween := pulse_bar.create_tween().set_loops()
	tween.tween_property(pulse_bar, "modulate:a", 0.42, duration)
	tween.tween_property(pulse_bar, "modulate:a", 1.0, duration)
