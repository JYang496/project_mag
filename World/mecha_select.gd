extends MarginContainer
class_name MechaSelect

@export var mecha_id :int = 1
var on_select : bool = false
var on_hover : bool = false
@onready var mech_texture: TextureRect = $MechTexture

@onready var mecha_name: Label = $"../../ColorRect/mecha_name"
@onready var current_exp: Label = $"../../ColorRect/current_exp"
@onready var current_level: Label = $"../../ColorRect/current_level"
@onready var player_max_hp: Label = $"../../ColorRect/VBoxContainer/player_max_hp"
@onready var player_speed: Label = $"../../ColorRect/VBoxContainer/player_speed"
@onready var armor: Label = $"../../ColorRect/VBoxContainer/armor"
@onready var shield: Label = $"../../ColorRect/VBoxContainer/shield"
@onready var crit_rate: Label = $"../../ColorRect/VBoxContainer2/crit_rate"
@onready var crit_damage: Label = $"../../ColorRect/VBoxContainer2/crit_damage"
@onready var grab_radius: Label = $"../../ColorRect/VBoxContainer2/grab_radius"
@onready var player_gold: Label = $"../../ColorRect/VBoxContainer2/player_gold"

var mech_data: MechaDefinition
var mech_autosave: Dictionary = {}

signal update_on_select(id)

# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var select_color: Color = Color(0, 1, 0)
@export var border_width: float = 4.0

func _ready() -> void:
	_refresh_mecha_data()
	if mech_data and mech_data.scene:
		var ins : Player = mech_data.scene.instantiate()
		mech_texture.texture = ins.get_node("MechaSprite").texture
		ins.queue_free()
	else:
		push_warning("MechaSelect failed to load mecha data for id=%s" % str(mecha_id))
	PlayerData.select_mecha_id = DataHandler.save_data.last_mecha_selected
	call_deferred("emit_signal", "update_on_select", str(DataHandler.save_data.last_mecha_selected))

func _draw():
	var rect = Rect2(Vector2.ZERO, size)
	var color = border_color if on_select else select_color
	var width = border_width if on_hover or on_select else 0.0
	draw_rect(rect, color, false, width)

func update() -> void:
	queue_redraw()

func _on_texture_rect_mouse_entered() -> void:
	on_hover = true
	update()

func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		on_select = true
		PlayerData.select_mecha_id = mecha_id
		update_on_select.emit(mecha_id)

func _on_texture_rect_mouse_exited() -> void:
	on_hover = false
	update()

func _refresh_mecha_data() -> void:
	mech_data = DataHandler.read_mecha_data(str(mecha_id))
	mech_autosave = DataHandler.read_autosave_mecha_data(str(mecha_id))
