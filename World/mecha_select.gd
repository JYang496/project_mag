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

@onready var mech_data = DataHandler.read_mecha_data(str(mecha_id))
@onready var mech_autosave = DataHandler.read_autosave_data(str(mecha_id))

signal update_on_select(id)

# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var select_color: Color = Color(0, 1, 0)
@export var border_width: float = 4.0

func _ready() -> void:
	#var mech_data = ImportData.read_mecha_data(str(mecha_id))
	var ins : Player = load(mech_data["res"]).instantiate()
	mech_texture.texture = ins.get_node("MechaSprite").texture
	ins.queue_free()
	
func update_labels() -> void:
	var lvl_index = int(mech_autosave["current_level"]) - 1
	mecha_name.text = mech_data["name"]
	current_exp.text = "Exp: %s / %s" %[mech_autosave["current_exp"], mech_data["next_level_exp"][lvl_index]]
	current_level.text = "Level: %s / %s" % [mech_autosave["current_level"], mech_data["max_level"]]
	player_max_hp.text = "Max HP: %s" % [mech_data["player_max_hp"][lvl_index]]
	player_speed.text = "Player speed: %s" % [mech_data["player_speed"][lvl_index]]
	armor.text = "Armor: %s" % [mech_data["armor"][lvl_index]]
	shield.text = "Shield: %s" % [mech_data["shield"][lvl_index]]
	crit_rate.text = "Crit Rate: %s" % [mech_data["crit_rate"][lvl_index]]
	crit_damage.text = "Crit Damage: %s" % [mech_data["crit_damage"][lvl_index]]
	grab_radius.text = "Grab Radius: %s" % [mech_data["grab_radius"][lvl_index]]
	player_gold.text = "Gold: %s" % [mech_data["player_gold"][lvl_index]]
	
func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var color = border_color if on_select else select_color
	var width = border_width if on_hover or on_select else 0.0
	draw_rect(rect, color, false, width)

func update() -> void:
	queue_redraw()
	if mecha_id == PlayerData.select_mecha_id:
		update_labels()

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
